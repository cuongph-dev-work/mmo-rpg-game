class_name GameServer
extends Node

## GameServer - Main Orchestrator
## Refactored to use modular architecture with Core Systems (Network, Entity) and Game Systems

# Core Systems
var network_manager: NetworkManager
var entity_manager: EntityManager

# Game Managers & Systems
var channel_manager: ChannelManager
var player_manager: PlayerManager
var mob_spawner: MobSpawnerSystem
var replication_system: ReplicationSystem
var combat_system: CombatSystem
var loot_system: LootSystem
var gate_system: GateSystem

# Systems
var persistence_system: PersistenceSystem
var map_instance: Map

# Scenes
var player_scene = preload("res://scenes/player/Player.tscn")
var mob_scene = preload("res://scenes/mob/Mob.tscn")
var world_scene = preload("res://scenes/world/World.tscn")

func _ready():
	# Use async setup to handle deferred initialization of World
	_async_setup.call_deferred()

func _async_setup():
	# 1. Parse Args
	map_id = _get_arg_int("--map-id", 1)
	var port = _get_arg_int("--port", 3001)
	
	# 2. Setup Core Layers
	_setup_network_manager(port)
	_setup_world_scene() # Uses call_deferred inside
	
	# Wait for World to be added to Tree due to "Parent busy" lock
	await get_tree().process_frame
	
	_setup_entity_manager()
	
	# 3. Setup Game Data
	player_manager = PlayerManager.new()
	add_child(player_manager)
	
	map_instance = Map.new()
	map_instance.initialize(map_id)
	add_child(map_instance)
	
	# 4. Setup Game Systems
	_setup_replication_system()
	_setup_channel_manager()
	_setup_mob_spawner()
	_setup_combat_system()
	_setup_loot_system()
	_setup_gate_system()
	_setup_loot_system()
	_setup_gate_system()
	_setup_persistence_system()
	
	# 5. Start Server
	if network_manager.start_server() == OK:
		_print_server_info()
		mob_spawner.spawn_initial_mobs()
		
		# 6. Register with World Directory
		_setup_registration()

# ============================================================
# REGISTRATION & HEARTBEAT
# ============================================================

var registration_request: HTTPRequest
var heartbeat_request: HTTPRequest
var heartbeat_timer: Timer
var is_registered: bool = false
var registration_retry_count: int = 0
const MAX_REGISTRATION_RETRIES = 10

# Configuration - can be overridden by environment or args
var world_directory_url: String = "http://localhost:3001"
var heartbeat_interval: float = 15.0

func _setup_registration():
	# Load config from environment if available
	var env_url = OS.get_environment("WORLD_DIRECTORY_URL")
	if not env_url.is_empty():
		world_directory_url = env_url
	
	# Setup dedicated HTTP requests
	registration_request = HTTPRequest.new()
	add_child(registration_request)
	registration_request.request_completed.connect(_on_registration_completed)
	
	heartbeat_request = HTTPRequest.new()
	add_child(heartbeat_request)
	heartbeat_request.request_completed.connect(_on_heartbeat_completed)
	
	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = heartbeat_interval
	heartbeat_timer.timeout.connect(_send_heartbeat)
	add_child(heartbeat_timer)
	
	_register_with_directory()

func _register_with_directory():
	if registration_retry_count >= MAX_REGISTRATION_RETRIES:
		push_error("❌ Max registration retries exceeded. Server will run unregistered.")
		return
	
	print("🌐 Registering with World Directory (attempt %d/%d)..." % [registration_retry_count + 1, MAX_REGISTRATION_RETRIES])
	var url = world_directory_url + "/map-registry/register"
	var headers = ["Content-Type: application/json"]
	
	# Get server IP from environment or use default
	var server_ip = OS.get_environment("SERVER_IP")
	if server_ip.is_empty():
		server_ip = "127.0.0.1"
	
	var body = JSON.stringify({
		"id": "map-server-%d" % map_id,
		"name": "Map Server %d" % map_id,
		"ip": server_ip,
		"port": network_manager.port,
		"supported_maps": [map_id],
		"max_players": network_manager.max_players
	})
	
	var error = registration_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("❌ Failed to send registration request: %s" % error)
		registration_retry_count += 1
		_schedule_registration_retry()

func _on_registration_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if response_code == 201:
		print("✅ Registered with World Directory successfully!")
		is_registered = true
		registration_retry_count = 0 # Reset counter on success
		heartbeat_timer.start()
	elif response_code == 0:
		# Network error - connection failed
		push_error("❌ Registration failed: Could not connect to World Directory")
		registration_retry_count += 1
		_schedule_registration_retry()
	else:
		# HTTP error
		var error_msg = body.get_string_from_utf8() if body.size() > 0 else "Unknown error"
		push_error("❌ Registration failed with code %d: %s" % [response_code, error_msg])
		registration_retry_count += 1
		_schedule_registration_retry()

func _schedule_registration_retry():
	if registration_retry_count >= MAX_REGISTRATION_RETRIES:
		push_error("❌ Max registration retries exceeded. Giving up.")
		return
	
	var retry_delay = min(5.0 * registration_retry_count, 30.0) # Exponential backoff, max 30s
	print("⏳ Retrying registration in %.1f seconds..." % retry_delay)
	await get_tree().create_timer(retry_delay).timeout
	_register_with_directory()

func _send_heartbeat():
	if not is_registered:
		return
	
	# Check if heartbeat request is already in progress
	if heartbeat_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("⚠️ Skipping heartbeat - previous request still in progress")
		return
		
	var url = world_directory_url + "/map-registry/heartbeat"
	var headers = ["Content-Type: application/json"]
	
	# Note: HeartbeatDto expects 'current_players' or 'load', not 'status'
	var body = JSON.stringify({
		"id": "map-server-%d" % map_id,
		"current_players": map_instance.get_total_player_count(),
		"load": map_instance.get_total_player_count()
	})
	
	var error = heartbeat_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("❌ Failed to send heartbeat: %s" % error)

func _on_heartbeat_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	if response_code == 200:
		# Heartbeat successful - no need to log every time
		pass
	elif response_code == 404:
		# Server not found - might have been unregistered
		push_error("❌ Heartbeat failed: Server not found. Re-registering...")
		is_registered = false
		_register_with_directory()
	elif response_code != 0:
		print("⚠️ Heartbeat returned unexpected code: %d" % response_code)

# ============================================================
# CORE SETUP
# ============================================================

func _setup_network_manager(port: int):
	network_manager = NetworkManager.new()
	network_manager.setup(port, 100) # Default max_players
	network_manager.player_connected.connect(_on_player_connected)
	network_manager.player_disconnected.connect(_on_player_disconnected)
	add_child(network_manager)

func _setup_world_scene():
	var root = get_tree().root
	var world
	
	if root.has_node("World"):
		world = root.get_node("World")
	else:
		world = world_scene.instantiate()
		root.call_deferred("add_child", world)
		
	# DEPENDENCY INJECTION
	if "game_server" in world:
		world.game_server = self

func _setup_entity_manager():
	entity_manager = EntityManager.new()
	add_child(entity_manager)
	
	# Synchronous Setup
	var root = get_tree().root
	if root.has_node("World"):
		entity_manager.setup(root.get_node("World"))
	else:
		push_error("❌ World node not found during sync setup! EntityManager disabled.")

# ============================================================
# SYSTEM SETUP
# ============================================================

func _setup_replication_system():
	replication_system = ReplicationSystem.new()
	replication_system.setup(entity_manager, 30) # 30Hz Network Rate (Balanced)
	add_child(replication_system)

func _setup_channel_manager():
	channel_manager = ChannelManager.new()
	channel_manager.setup(self, map_instance, entity_manager.entity_container, player_manager)
	add_child(channel_manager)

func _setup_mob_spawner():
	mob_spawner = MobSpawnerSystem.new()
	mob_spawner.setup(map_instance, entity_manager.entity_container, channel_manager, mob_scene)
	mob_spawner.mob_spawned.connect(_on_mob_spawned)
	add_child(mob_spawner)

func _setup_combat_system():
	combat_system = CombatSystem.new()
	combat_system.setup(entity_manager)
	add_child(combat_system)

func _setup_loot_system():
	loot_system = LootSystem.new()
	loot_system.setup()
	add_child(loot_system)

func _setup_gate_system():
	gate_system = GateSystem.new()
	gate_system.setup(map_instance, entity_manager.entity_container, self)
	add_child(gate_system)

func _setup_persistence_system():
	persistence_system = PersistenceSystem.new()
	add_child(persistence_system)
	persistence_system.setup()

func handle_authentication(player_id: int, ticket: String, char_id: String):
	print("🔐 Authenticating Player %d as Character %s" % [player_id, char_id])
	
	var player_entry = player_manager.get_player(player_id)
	if player_entry.is_empty():
		push_error("❌ Authentication failed: Player %d not found in manager" % player_id)
		return
		
	player_manager.players[player_id]["data"]["character_id"] = char_id
	
	# Use Persistence System
	persistence_system.load_player_state(char_id, func(data):
		if not data.is_empty():
			print("📥 Loaded character data for %s" % char_id)
			if player_manager.players.has(player_id):
				player_manager.players[player_id]["data"]["persisted_state"] = data
	)

func save_player_state(player_id: int):
	var player_info = player_manager.get_player(player_id)
	if player_info.is_empty(): return
	
	var char_id = player_info.get("data", {}).get("character_id")
	if not char_id: return
		
	var player_node = entity_manager.get_entity_node(player_id)
	if not player_node: return
		
	# Gather Data
	var pos = player_node.position
	var stats = {}
	if player_node.has_node("StatsComponent"):
		var stats_comp = player_node.get_node("StatsComponent")
		stats = {
			"hp": stats_comp.current_hp,
			"mp": stats_comp.current_mp
		}
		
	var payload = {
		"map_id": map_id,
		"position": {"x": pos.x, "y": pos.y},
		"stats": stats
	}
	
	persistence_system.save_player_state(char_id, payload)

# ============================================================
# EVENT HANDLERS
# ============================================================

func _on_player_connected(player_id: int):
	print("🎮 Player %d connected" % player_id)
	
	print("🎮 Player %d connected (waiting for spawn request)" % player_id)
	
	# Fallback: Force spawn if no request received in 2 seconds
	await get_tree().create_timer(2.0).timeout
	
	if not multiplayer.get_peers().has(player_id):
		return # Player disconnected
		
	if not entity_manager.has_entity(player_id):
		print("⚠️ Spawn Timeout for %d - Forcing Default Spawn" % player_id)
		# Default spawn pos (400, 300)
		handle_player_spawn_request(player_id, Vector2(400, 300))


func _on_player_disconnected(player_id: int):
	print("👋 Player %d disconnected" % player_id)
	
	# 1. Save Player State
	save_player_state(player_id)
	
	# 2. Logic Cleanup
	_handle_player_leave_channel(player_id)
	
	# 3. Node Cleanup
	entity_manager.remove_entity(player_id)
	player_manager.remove_player(player_id)

func _on_mob_spawned(mob_node: Node, _channel_id: int):
	replication_system.apply_replication_settings_to_new_entity(mob_node)

func handle_player_spawn_request(player_id: int, pos: Vector2):
	print("🚀 Player %d requested spawn at %s" % [player_id, pos])
	
	# Check for persisted state
	var player_data = player_manager.get_player(player_id).get("data", {})
	var spawn_pos = pos
	var persisted_state = player_data.get("persisted_state", {})
	
	# Use persisted position if available (server authoritative option)
	# For now, we trust client for position unless it's way off, 
	# but technically we should use persisted_state.position if valid.
	# Let's trust client 'pos' for initial spawn (as it comes from AuthState), 
	# but we MUST apply stats from persisted_state.
	
	if persisted_state.has("position") and persisted_state.position != null:
		# Optional: Verify distance or force position
		pass

	# 1. Spawn Node at specific position
	_spawn_player_node(player_id, spawn_pos)
	
	# 2. Apply Persisted Stats
	if persisted_state.has("stats"):
		var p_node = entity_manager.get_entity_node(player_id)
		if p_node and p_node.has_node("StatsComponent"):
			var stats = p_node.get_node("StatsComponent")
			var saved_stats = persisted_state.stats
			var hp = saved_stats.get("hp", stats.max_hp)
			var mp = saved_stats.get("mp", stats.max_mp)
			stats.set_dynamic_stats(hp, mp)
			print("❤️ Restored stats for %d: HP %d, MP %d" % [player_id, hp, mp])
	
	# 3. Channel & Sync
	_handle_player_join_channel(player_id)

func _spawn_player_node(player_id: int, start_pos: Vector2 = Vector2.ZERO):
	if entity_manager.has_entity(player_id):
		return
		
	var player = player_scene.instantiate()
	player.name = str(player_id)
	player.position = start_pos # Set Initial Position
	player.set_multiplayer_authority(player_id)
	
	if player.has_node("MultiplayerSynchronizer"):
		player.get_node("MultiplayerSynchronizer").set_multiplayer_authority(1)
		
	entity_manager.add_entity(player)
	replication_system.apply_replication_settings_to_new_entity(player)
	print("✨ Spawned player node for %d" % player_id)

# ============================================================
# CHANNEL LOGIC WRAPPERS
# ============================================================

func _handle_player_join_channel(player_id: int):
	# Default Channel Logic
	var assigned_channel_id = 1
	var channel = map_instance.get_available_channel()
	if channel:
		assigned_channel_id = channel.channel_id
		channel.add_player(player_id)
		player_manager.add_player(player_id, {"channel_id": assigned_channel_id})
		
		# Set node channel_id
		var p_node = entity_manager.get_entity_node(player_id)
		if p_node:
			p_node.channel_id = assigned_channel_id
			
		print("✅ Player %d assigned to Channel %d" % [player_id, assigned_channel_id])
		
		# Optimizations & Sync
		channel_manager.update_channel_processing(assigned_channel_id)
		channel_manager.sync_channel_entities_to_player(assigned_channel_id, player_id, true)
		
		# RPC Broadcasts (Legacy support for World.gd)
		_broadcast_spawn_to_player(player_id, assigned_channel_id)
		_broadcast_player_to_channel(player_id, assigned_channel_id)
		
		# Sync gates to player
		gate_system.sync_gates_to_player(player_id)

func _handle_player_leave_channel(player_id: int):
	# Find channel
	var player_data = player_manager.get_player(player_id)
	if not player_data: return
	
	var channel_id = player_data.get("data", {}).get("channel_id", 1)
	var channel = map_instance.get_channel(channel_id)
	
	if channel:
		# Broadcast Despawn
		var world_node = _get_world_node()
		if world_node:
			for other_pid in channel.players.keys():
				if other_pid != player_id:
					world_node.rpc_id(other_pid, "despawn_player", player_id)
		
		channel.remove_player(player_id)
		channel_manager.update_channel_processing(channel_id)

# ============================================================
# BROADCAST HELPERS
# ============================================================

func _broadcast_spawn_to_player(target_pid: int, channel_id: int):
	var world_node = _get_world_node()
	if not world_node: return
	
	# Send Mobs
	var mobs = entity_manager.get_all_entities().filter(func(x): return x.is_in_group("enemies"))
	for mob in mobs:
		if mob.get("channel_id") == channel_id:
			var type_id = mob.get("mob_type_id") if "mob_type_id" in mob else "slime"
			var is_elite = mob.get("is_elite") if "is_elite" in mob else false
			world_node.rpc_id(target_pid, "spawn_mob", int(str(mob.name)), mob.position, type_id, is_elite)

	# Send Other Players
	var channel = map_instance.get_channel(channel_id)
	if channel:
		for pid in channel.players.keys():
			if pid != target_pid:
				var node = entity_manager.get_entity_node(pid)
				if node:
					world_node.rpc_id(target_pid, "spawn_player", pid, node.position)

func _broadcast_player_to_channel(player_id: int, channel_id: int):
	var world_node = _get_world_node()
	var p_node = entity_manager.get_entity_node(player_id)
	if not world_node or not p_node: return
	
	var channel = map_instance.get_channel(channel_id)
	if channel:
		for pid in channel.players.keys():
			if pid != player_id:
				channel_manager.set_entity_visibility(p_node, pid, true)
				world_node.rpc_id(pid, "spawn_player", player_id, p_node.position)

# ============================================================
# UTILS
# ============================================================

func _get_arg_int(key: String, default: int) -> int:
	for arg in OS.get_cmdline_args():
		if arg.begins_with(key + "="):
			return int(arg.split("=")[1])
	return default

func _print_server_info():
	var map_name = map_instance.config.map_name if map_instance.config else "Map %d" % map_id
	print("✅ Map %s running on port %d" % [map_name, network_manager.port])

func _process(_delta):
	if Engine.get_process_frames() % 600 == 0:
		var count = map_instance.get_total_player_count()
		if count > 0: print("📊 Players: %d" % count)

func change_player_channel(player_id: int, target_channel_id: int) -> bool:
	return channel_manager.change_player_channel(player_id, target_channel_id)

func _get_world_node() -> Node:
	if entity_manager.entity_container:
		return entity_manager.entity_container.get_parent()
	return null
