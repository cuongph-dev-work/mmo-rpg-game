class_name MapServer
extends Node

## Simplified Map Server for MVP
## Client connects directly to this server
## No Master Server, no routing - just pure game logic

var network = ENetMultiplayerPeer.new()
var map_id: int
var port: int = 3001 # Default port
var max_players: int = 100
var map_instance: Map
var player_manager: PlayerManager
var entity_container: Node # Reference to the entity container
var player_scene = preload("res://scenes/player/Player.tscn")
var mob_scene = preload("res://scenes/mob/Mob.tscn")
var world_scene = preload("res://scenes/world/World.tscn")

# ID Counter
var next_mob_id: int = 20000

func _ready():
	# Lấy map_id và port từ command line
	map_id = get_map_id_from_args()
	port = get_port_from_args()
	
	# Load World Scene for Client Compatibility
	_load_world_scene()
	
	player_manager = PlayerManager.new()
	add_child(player_manager)
	
	map_instance = Map.new()
	map_instance.initialize(map_id)
	add_child(map_instance)
	
	start_server()
	
	# Spawn Mobs from Config
	_spawn_mobs_from_config()

func _spawn_mobs_from_config():
	if not map_instance or not map_instance.config:
		return
		
	print("🧟 Spawning mobs from config for ALL channels...")
	var spawns = map_instance.config.mob_spawns
	
	# Iterate all channels
	for channel_id in map_instance.channels.keys():
		print("   👉 Spawning for Channel %d" % channel_id)
		for spawn_group in spawns:
			var mob_id = spawn_group.get("mob_id")
			var count = spawn_group.get("spawn_count", 1)
			var area = spawn_group.get("spawn_area", {}).get("rect", [0, 0, 0, 0])
			var elite_chance = spawn_group.get("elite_chance", 0.0)
			
			var rect = Rect2(area[0], area[1], area[2], area[3])
			
			for i in range(count):
				var random_pos = Vector2(
					randf_range(rect.position.x, rect.position.x + rect.size.x),
					randf_range(rect.position.y, rect.position.y + rect.size.y)
				)
				
				var unique_id = next_mob_id
				next_mob_id += 1
				
				var is_elite = randf() < elite_chance
				var group_index = spawns.find(spawn_group)
				
				_spawn_mob_node(unique_id, random_pos, mob_id, is_elite, group_index, channel_id)
		
		# CPU Optimization: Sleep by default at startup (no players)
		_update_channel_processing(channel_id)
	pass


func _load_world_scene():
	"""
	Instantiate the World scene to match Client path: /root/World/EntityContainer
	This ensures the server hierarchy matches the client for MultiplayerSynchronizer.
	"""
	var root = get_tree().root
	
	# Check if exists (unlikely but safety first)
	# BUT: If it exists, we still need to set the reference if it's missing!
	if root.has_node("World"):
		var world = root.get_node("World")
		
		# DEPENDENCY INJECTION
		if "map_server" in world:
			world.map_server = self
			
		if world.has_node("EntityContainer"):
			entity_container = world.get_node("EntityContainer")
			return
	
	# Instantiate World scene
	var world = world_scene.instantiate()
	
	# DEPENDENCY INJECTION
	if "map_server" in world:
		world.map_server = self
		
	root.call_deferred("add_child", world)
	
	# Get reference to container
	# Note: immediately after add_child deferred, get_node might fail if we don't wait?
	# But EntityContainer is part of instantiated packed scene, so it should be accessible via reference `world`.
	if world.has_node("EntityContainer"):
		entity_container = world.get_node("EntityContainer")
		print("✅ Server World instantiated at /root/World/EntityContainer")
	else:
		push_error("❌ World scene missing EntityContainer!")

func get_map_id_from_args() -> int:
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--map-id="):
			return int(arg.split("=")[1])
	return 1 # Default

func get_port_from_args() -> int:
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--port="):
			return int(arg.split("=")[1])
	return 3001 # Default

func start_server():
	var error = network.create_server(port, max_players)
	if error != OK:
		print("❌ Failed to start Map Server on port ", port, ": ", error)
		return
	
	multiplayer.multiplayer_peer = network
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	var map_name = map_instance.config.map_name if map_instance.config else "Map %d" % map_id
	print("✅ Map Server started: %s (ID: %d)" % [map_name, map_id])
	print("   Port: %d" % port)
	print("   Tickrate: %d Hz" % Engine.physics_ticks_per_second)
	print("   Channels: %d" % map_instance.get_channel_count())
	print("   Max players/channel: %d" % (map_instance.config.max_players_per_channel if map_instance.config else 50))
	print("   Waiting for players...")

func _on_peer_connected(player_id):
	print("🎮 Player %d connected" % player_id)
	
	# Spawn Player Node for Synchronization
	_spawn_player_node(player_id)
	
	# Sync existing mobs to new player
	var existing_mobs_count = 0
	
	# Determine player channel (Assumed assigned already or default to 1 for initial sync? 
	# Actually assignment happens LATER in this function. We should assign channel FIRST!)
	
	# Wait, we need to assign channel BEFORE syncing mobs so we know which ones to sync.
	# Moving Channel Assignment UP.
	
	var assigned_channel_id = 1
	var channel = map_instance.get_available_channel()
	if channel:
		assigned_channel_id = channel.channel_id
		channel.add_player(player_id) # Assign strictly
		player_manager.add_player(player_id, {"channel_id": assigned_channel_id})
		print("✅ Player %d assigned to Channel %d" % [player_id, assigned_channel_id])
		
		# CPU Optimization: Ensure channel is active
		_update_channel_processing(assigned_channel_id)
		
		# Update Player Node
		var p_node = entity_container.get_node(str(player_id))
		if p_node:
			p_node.channel_id = assigned_channel_id
	
	print("DEBUG: Checking entities for sync to player %d (Channel %d)..." % [player_id, assigned_channel_id])
	
	for child in entity_container.get_children():
		# Sync only Mobs (Filter by Group AND Channel)
		if child.is_in_group("enemies"):
			var mob_channel = child.get("channel_id") if "channel_id" in child else 0
			if mob_channel != assigned_channel_id: continue
				
			existing_mobs_count += 1
			var type_id = child.get("mob_type_id") if "mob_type_id" in child else "slime"
			var is_elite = child.get("is_elite") if "is_elite" in child else false
			
			# Network Optimization: Open Visibility for this player
			if child.has_node("MultiplayerSynchronizer"):
				child.get_node("MultiplayerSynchronizer").set_visibility_for(player_id, true)
			
			# Call RPC via World node
			var world_node = entity_container.get_parent()
			if world_node:
				world_node.rpc_id(player_id, "spawn_mob", int(child.name), child.position, type_id, is_elite)
			
	print("DEBUG: Synced %d mobs to player %d" % [existing_mobs_count, player_id])
	
	# Channel Assignment done above
	
	# TODO: Send welcome message to player
	# TODO: Send channel info to player
	pass

func change_player_channel(player_id: int, target_channel_id: int):
	print("🔄 Player %d requested switch to Channel %d" % [player_id, target_channel_id])
	
	# 1. Validation
	var player_info = player_manager.get_player(player_id)
	if not player_info: return
	
	var old_channel_id = player_info["data"].get("channel_id", 1)
	if old_channel_id == target_channel_id:
		print("   ⚠️ Already in channel %d" % target_channel_id)
		return
		
	var target_channel = map_instance.get_channel(target_channel_id)
	if not target_channel:
		print("   ❌ Target channel %d does not exist" % target_channel_id)
		return
		
	if target_channel.is_full():
		print("   ❌ Target channel %d is full" % target_channel_id)
		return
		
	# 2. Switch Logic
	print("   ✅ Switching %d -> %d" % [old_channel_id, target_channel_id])
	
	# A. Remove from Old Channel
	var old_channel = map_instance.get_channel(old_channel_id)
	if old_channel:
		old_channel.remove_player(player_id)
		
		# Despawn Old Mobs for Client
		for child in entity_container.get_children():
			if child.is_in_group("enemies"):
				var mob_channel = child.get("channel_id") if "channel_id" in child else 0
				if mob_channel == old_channel_id:
					# Network Optimization: Hide
					if child.has_node("MultiplayerSynchronizer"):
						child.get_node("MultiplayerSynchronizer").set_visibility_for(player_id, false)
					
					# Client Despawn
					var world_node = entity_container.get_parent()
					if world_node:
						world_node.rpc_id(player_id, "despawn_mob", int(child.name))
		
		# CPU Optimization Check
		_update_channel_processing(old_channel_id)

	# B. Add to New Channel
	target_channel.add_player(player_id)
	player_manager.players[player_id]["data"]["channel_id"] = target_channel_id
	
	# Update Player Node
	var p_node = entity_container.get_node(str(player_id))
	if p_node:
		p_node.channel_id = target_channel_id

	# C. Spawn New Mobs for Client
	var new_mobs_count = 0
	for child in entity_container.get_children():
		if child.is_in_group("enemies"):
			var mob_channel = child.get("channel_id") if "channel_id" in child else 0
			if mob_channel == target_channel_id:
				new_mobs_count += 1
				var type_id = child.get("mob_type_id") if "mob_type_id" in child else "slime"
				var is_elite = child.get("is_elite") if "is_elite" in child else false
				
				# Network Optimization: Show
				if child.has_node("MultiplayerSynchronizer"):
					child.get_node("MultiplayerSynchronizer").set_visibility_for(player_id, true)
				
				# Client Spawn
				var world_node = entity_container.get_parent()
				if world_node:
					world_node.rpc_id(player_id, "spawn_mob", int(child.name), child.position, type_id, is_elite)

	# CPU Optimization Check
	_update_channel_processing(target_channel_id)
	
	print("   ✅ Switched and synced %d new mobs" % new_mobs_count)

func _spawn_player_node(player_id: int):
	"""Spawn a player node to handle MultiplayerSynchronizer"""
	if not entity_container:
		return
		
	if entity_container.has_node(str(player_id)):
		return # Already spawned
		
	var player = player_scene.instantiate()
	player.name = str(player_id)
	
	player.set_multiplayer_authority(player_id)
	
	# Explicitly set Synchronizer authority to Server (1)
	# The Player node is Authority(player_id) for RPC targeting (Inputs)
	# The Synchronizer is Authority(1) for Position broadcasting
	if player.has_node("MultiplayerSynchronizer"):
		player.get_node("MultiplayerSynchronizer").set_multiplayer_authority(1)
	
	entity_container.add_child(player)
	print("✨ Spawned player node for %d at: %s" % [player_id, player.get_path()])

func _spawn_mob_node(mob_id: int, pos: Vector2, type_id: String, is_elite: bool, group_index: int = -1, channel_id: int = 1):
	if not entity_container: return
	if entity_container.has_node(str(mob_id)): return

	var mob = mob_scene.instantiate()
	mob.name = str(mob_id)
	mob.position = pos
	
	# Sync Authority: Server (1)
	mob.set_multiplayer_authority(1)
	if mob.has_node("MultiplayerSynchronizer"):
		mob.get_node("MultiplayerSynchronizer").set_multiplayer_authority(1)
	
	# Init Stats
	if mob.has_method("init"):
		mob.init(pos, type_id, is_elite, group_index, channel_id)
		# Connect death signal
		mob.died.connect(_on_mob_died)
	
	entity_container.add_child(mob)
	print("🧟 Spawned Mob %d (%s) at %s Group: %d Channel: %d" % [mob_id, type_id, pos, group_index, channel_id])

func _on_mob_died(mob_node):
	var mob_id = int(str(mob_node.name))
	var group_index = mob_node.spawn_group_index
	print("💀 Mob %d died (Group: %d). Scheduling respawn..." % [mob_id, group_index])
	
	# 1. Notify Clients to remove visual via World node
	if entity_container:
		var world_node = entity_container.get_parent()
		if world_node:
			var mob_channel_id = mob_node.channel_id
			var channel_obj = map_instance.get_channel(mob_channel_id)
			if channel_obj:
				for pid in channel_obj.players.keys():
					world_node.rpc_id(pid, "despawn_mob", mob_id)
	
	# 2. Schedule Respawn if valid group
	if group_index >= 0 and map_instance.config.mob_spawns.size() > group_index:
		var spawn_config = map_instance.config.mob_spawns[group_index]
		var respawn_time = spawn_config.get("respawn_time", 5.0)
		
		# Mob Channel
		var mob_channel = mob_node.channel_id
		
		# Wait for respawn time
		await get_tree().create_timer(respawn_time).timeout
		
		# Respawn ONE mob for this group AND this channel
		_spawn_single_mob_from_group(group_index, mob_channel)

func _spawn_single_mob_from_group(group_index: int, channel_id: int):
	if not map_instance or not map_instance.config: return
	var spawns = map_instance.config.mob_spawns
	if group_index < 0 or group_index >= spawns.size(): return
	
	var spawn_group = spawns[group_index]
	var mob_id = spawn_group.get("mob_id")
	var area = spawn_group.get("spawn_area", {}).get("rect", [0, 0, 0, 0])
	var elite_chance = spawn_group.get("elite_chance", 0.0)
	var rect = Rect2(area[0], area[1], area[2], area[3])
	
	var random_pos = Vector2(
		randf_range(rect.position.x, rect.position.x + rect.size.x),
		randf_range(rect.position.y, rect.position.y + rect.size.y)
	)
	
	var unique_id = next_mob_id
	next_mob_id += 1
	var is_elite = randf() < elite_chance
	
	_spawn_mob_node(unique_id, random_pos, mob_id, is_elite, group_index, channel_id)
	
	# RPC via World Node - BUT ONLY TO PLAYERS IN THIS CHANNEL
	if entity_container:
		var mob_node = entity_container.get_node(str(unique_id))
		
		var world_node = entity_container.get_parent()
		if world_node:
			# Iterate players in this channel
			var channel_obj = map_instance.get_channel(channel_id)
			if channel_obj:
				for pid in channel_obj.players.keys():
					# Network Optimization: Open Visibility
					if mob_node and mob_node.has_node("MultiplayerSynchronizer"):
						mob_node.get_node("MultiplayerSynchronizer").set_visibility_for(pid, true)
						
					world_node.rpc_id(pid, "spawn_mob", unique_id, random_pos, mob_id, is_elite)

func _on_peer_disconnected(player_id):
	print("👋 Player %d disconnected" % player_id)
	
	# Despawn Player Node
	if entity_container and entity_container.has_node(str(player_id)):
		entity_container.get_node(str(player_id)).queue_free()
		print("� Despawned player node for %d" % player_id)
	
	# Remove from channel
	for channel in map_instance.channels.values():
		if channel.players.has(player_id):
			channel.remove_player(player_id)
			print("   Removed from Channel %d" % channel.channel_id)
			
			# CPU Optimization: Check if channel should sleep
			_update_channel_processing(channel.channel_id)
			break
	
	# Remove from player manager
	player_manager.remove_player(player_id)

func _process(_delta):
	# Log stats periodically
	if Engine.get_process_frames() % 600 == 0: # Every 10 seconds
		var total_players = map_instance.get_total_player_count()
		if total_players > 0:
			print("📊 Stats: %d players online" % total_players)

func _update_channel_processing(channel_id: int):
	# CPU Optimization: Disable mob processing if channel is empty
	var channel = map_instance.get_channel(channel_id)
	if not channel: return
	
	var is_active = channel.get_player_count() > 0
	# print("⚙️ Channel %d active: %s" % [channel_id, is_active])
	
	for child in entity_container.get_children():
		if child.is_in_group("enemies"):
			var mob_channel = child.get("channel_id") if "channel_id" in child else 0
			if mob_channel == channel_id:
				child.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
