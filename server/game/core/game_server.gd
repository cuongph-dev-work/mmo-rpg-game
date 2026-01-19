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

# Data
var map_id: int
var map_instance: Map

# Scenes
var player_scene = preload("res://scenes/player/Player.tscn")
var mob_scene = preload("res://scenes/mob/Mob.tscn")
var world_scene = preload("res://scenes/world/World.tscn")

func _ready():
	# 1. Parse Args
	map_id = _get_arg_int("--map-id", 1)
	var port = _get_arg_int("--port", 3001)
	
	# 2. Setup Core Layers
	_setup_network_manager(port)
	_setup_world_scene() # Ensure Godot Scene Tree logic
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
	
	# 5. Start Server
	if network_manager.start_server() == OK:
		_print_server_info()
		mob_spawner.spawn_initial_mobs()

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
	
	if not entity_manager.entity_container:
		call_deferred("_late_setup")
		
func _late_setup():
	var root = get_tree().root
	if root.has_node("World"):
		entity_manager.setup(root.get_node("World"))
		channel_manager.entity_container = entity_manager.entity_container
		mob_spawner.entity_container = entity_manager.entity_container
		print("✅ World Container linked via Late Setup")

# ============================================================
# SYSTEM SETUP
# ============================================================

func _setup_replication_system():
	replication_system = ReplicationSystem.new()
	replication_system.setup(entity_manager, 20) # 20Hz Network Rate
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

# ============================================================
# EVENT HANDLERS
# ============================================================

func _on_player_connected(player_id: int):
	print("🎮 Player %d connected" % player_id)
	
	# 1. Spawn Node
	_spawn_player_node(player_id)
	
	# 2. Channel & Sync
	_handle_player_join_channel(player_id)

func _on_player_disconnected(player_id: int):
	print("👋 Player %d disconnected" % player_id)
	
	# 1. Logic Cleanup
	_handle_player_leave_channel(player_id)
	
	# 2. Node Cleanup
	entity_manager.remove_entity(player_id)
	player_manager.remove_player(player_id)

func _on_mob_spawned(mob_node: Node, _channel_id: int):
	replication_system.apply_replication_settings_to_new_entity(mob_node)

func _spawn_player_node(player_id: int):
	if entity_manager.has_entity(player_id):
		return
		
	var player = player_scene.instantiate()
	player.name = str(player_id)
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
