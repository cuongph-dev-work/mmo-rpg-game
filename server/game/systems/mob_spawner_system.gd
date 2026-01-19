class_name MobSpawnerSystem
extends Node

## MobSpawnerSystem - Quản lý mob spawning, respawn và ID counter
## Extracted from GameServer để giảm complexity và cải thiện maintainability

# Dependencies (Injected)
var map_instance: Map
var entity_container: Node
var channel_manager: ChannelManager # For visibility sync
var mob_scene: PackedScene

# State
var next_mob_id: int = 20000

# Signals
signal mob_spawned(mob_node: Node, channel_id: int)
signal mob_died_signal(mob_node: Node)

func setup(map: Map, container: Node, ch_manager: ChannelManager, scene: PackedScene) -> void:
	map_instance = map
	entity_container = container
	channel_manager = ch_manager
	mob_scene = scene
	print("✅ MobSpawnerSystem initialized")

# ============================================================
# INITIAL SPAWN
# ============================================================

## Spawn all mobs from map config for all channels
func spawn_initial_mobs() -> void:
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
				
				spawn_mob_node(unique_id, random_pos, mob_id, is_elite, group_index, channel_id)
		
		# CPU Optimization: Sleep by default at startup (no players)
		channel_manager.update_channel_processing(channel_id)

# ============================================================
# MOB SPAWNING
# ============================================================

## Spawn a single mob node
func spawn_mob_node(mob_id: int, pos: Vector2, type_id: String, is_elite: bool, group_index: int = -1, channel_id: int = 1) -> Node:
	if not entity_container:
		return null
	if entity_container.has_node(str(mob_id)):
		return null

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
	
	mob_spawned.emit(mob, channel_id)
	return mob

## Spawn a single mob from a specific spawn group (for respawn)
func spawn_single_mob_from_group(group_index: int, channel_id: int) -> void:
	if not map_instance or not map_instance.config:
		return
	var spawns = map_instance.config.mob_spawns
	if group_index < 0 or group_index >= spawns.size():
		return
	
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
	
	var mob_node = spawn_mob_node(unique_id, random_pos, mob_id, is_elite, group_index, channel_id)
	
	# RPC via World Node - BUT ONLY TO PLAYERS IN THIS CHANNEL
	if entity_container and mob_node:
		var world_node = entity_container.get_parent()
		if world_node:
			# Iterate players in this channel
			var channel_obj = map_instance.get_channel(channel_id)
			if channel_obj:
				for pid in channel_obj.players.keys():
					# Network Optimization: Open Visibility
					if mob_node.has_node("MultiplayerSynchronizer"):
						mob_node.get_node("MultiplayerSynchronizer").set_visibility_for(pid, true)
						
					world_node.rpc_id(pid, "spawn_mob", unique_id, random_pos, mob_id, is_elite)

# ============================================================
# DEATH & RESPAWN
# ============================================================

## Handle mob death - notify clients and schedule respawn
func _on_mob_died(mob_node: Node) -> void:
	var mob_id = int(str(mob_node.name))
	var group_index = mob_node.spawn_group_index
	print("💀 Mob %d died (Group: %d). Scheduling respawn..." % [mob_id, group_index])
	
	mob_died_signal.emit(mob_node)
	
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
		var base_respawn_time = spawn_config.get("respawn_time", 5.0)
		# Add 20% variance to avoid synchronous spawns
		var respawn_time = base_respawn_time * randf_range(0.8, 1.2)
		
		# Mob Channel
		var mob_channel = mob_node.channel_id
		
		# Wait for respawn time
		await get_tree().create_timer(respawn_time).timeout
		
		# Respawn ONE mob for this group AND this channel
		spawn_single_mob_from_group(group_index, mob_channel)

# ============================================================
# UTILITY
# ============================================================

## Get the next mob ID (for external use if needed)
func get_next_mob_id() -> int:
	var id = next_mob_id
	next_mob_id += 1
	return id
