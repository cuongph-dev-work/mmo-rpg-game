class_name ChannelManager
extends Node

## ChannelManager - Quản lý visibility, channel isolation và switch channel logic
## Extracted from GameServer để giảm complexity và cải thiện maintainability

# Dependencies (Injected)
var game_server: Node # Reference back to GameServer for RPC calls
var map_instance: Map
var entity_container: Node
var player_manager: PlayerManager

# Signals
signal channel_switch_completed(player_id: int, old_channel: int, new_channel: int)
signal player_visibility_changed(player_id: int, channel_id: int)

func setup(server: Node, map: Map, container: Node, p_manager: PlayerManager) -> void:
	game_server = server
	map_instance = map
	entity_container = container
	player_manager = p_manager
	print("✅ ChannelManager initialized")

# ============================================================
# VISIBILITY HELPERS
# ============================================================

## Set visibility of a single entity for a specific player
func set_entity_visibility(entity: Node, player_id: int, visible: bool) -> void:
	if entity.has_node("MultiplayerSynchronizer"):
		entity.get_node("MultiplayerSynchronizer").set_visibility_for(player_id, visible)

## Sync all entities in a channel to a player (show/hide)
func sync_channel_entities_to_player(channel_id: int, player_id: int, visible: bool, entity_group: String = "") -> void:
	if not entity_container:
		return
		
	for child in entity_container.get_children():
		# Filter by group if specified
		if entity_group != "" and not child.is_in_group(entity_group):
			continue
		
		# Skip self
		if child.name == str(player_id):
			continue
			
		var entity_channel = child.get("channel_id") if "channel_id" in child else -1
		if entity_channel == channel_id:
			set_entity_visibility(child, player_id, visible)

## Sync a single entity to all players in a channel (show/hide)
func sync_entity_to_channel_players(entity: Node, channel_id: int, visible: bool) -> void:
	var channel = map_instance.get_channel(channel_id)
	if not channel:
		return
	
	var entity_id_str = entity.name
	for pid in channel.players.keys():
		# Skip self
		if str(pid) == entity_id_str:
			continue
		set_entity_visibility(entity, pid, visible)

# ============================================================
# CPU OPTIMIZATION
# ============================================================

## Enable/disable mob processing based on channel activity
func update_channel_processing(channel_id: int) -> void:
	var channel = map_instance.get_channel(channel_id)
	if not channel:
		return
	
	var is_active = channel.get_player_count() > 0
	
	if not entity_container:
		return
		
	for child in entity_container.get_children():
		if child.is_in_group("enemies"):
			var mob_channel = child.get("channel_id") if "channel_id" in child else 0
			if mob_channel == channel_id:
				child.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED

# ============================================================
# CHANNEL SWITCH LOGIC
# ============================================================

## Switch a player from one channel to another
## Returns true if successful, false otherwise
func change_player_channel(player_id: int, target_channel_id: int) -> bool:
	print("🔄 Player %d requested switch to Channel %d" % [player_id, target_channel_id])
	
	# 1. Validation
	var player_info = player_manager.get_player(player_id)
	if not player_info:
		print("   ❌ Player not found")
		return false
	
	var old_channel_id = player_info["data"].get("channel_id", 1)
	if old_channel_id == target_channel_id:
		print("   ⚠️ Already in channel %d" % target_channel_id)
		return false
		
	var target_channel = map_instance.get_channel(target_channel_id)
	if not target_channel:
		print("   ❌ Target channel %d does not exist" % target_channel_id)
		return false
		
	if target_channel.is_full():
		print("   ❌ Target channel %d is full" % target_channel_id)
		return false
		
	# 2. Switch Logic
	print("   ✅ Switching %d -> %d" % [old_channel_id, target_channel_id])
	var world_node = _get_world_node()
	
	# A. OLD CHANNEL CLEANUP
	var old_channel = map_instance.get_channel(old_channel_id)
	if old_channel:
		# a. Hide ALL entities of old channel from Player A (Mobs & Players)
		sync_channel_entities_to_player(old_channel_id, player_id, false)
		
		if world_node:
			# Despawn Mobs of Old Channel for Player A
			for child in entity_container.get_children():
				if child.is_in_group("enemies") and child.get("channel_id") == old_channel_id:
					world_node.rpc_id(player_id, "despawn_mob", int(child.name))
			
			# Despawn Players of Old Channel for Player A
			for other_pid in old_channel.players.keys():
				if other_pid != player_id:
					world_node.rpc_id(player_id, "despawn_player", other_pid)
					
					# b. Hide Player A from OTHER players in old channel
					var p_node = entity_container.get_node(str(player_id))
					if p_node:
						set_entity_visibility(p_node, other_pid, false)
						# Despawn A for Other
						world_node.rpc_id(other_pid, "despawn_player", player_id)

		# Remove from logic
		old_channel.remove_player(player_id)
		update_channel_processing(old_channel_id)

	# B. NEW CHANNEL SETUP
	target_channel.add_player(player_id)
	player_info["data"]["channel_id"] = target_channel_id
	
	# Update Player Node
	var p_node = entity_container.get_node(str(player_id))
	var player_pos = p_node.position if p_node else Vector2.ZERO
	if p_node:
		p_node.channel_id = target_channel_id
		
	# c. Show ALL entities of new channel to Player A (Mobs & Players)
	sync_channel_entities_to_player(target_channel_id, player_id, true)
	
	if world_node:
		# Spawn Mobs of New Channel for Player A
		for child in entity_container.get_children():
			if child.is_in_group("enemies") and child.get("channel_id") == target_channel_id:
				var type_id = child.get("mob_type_id") if "mob_type_id" in child else "slime"
				var is_elite = child.get("is_elite") if "is_elite" in child else false
				world_node.rpc_id(player_id, "spawn_mob", int(child.name), child.position, type_id, is_elite)

		# Spawn Players of New Channel for Player A AND A for Them
		for other_pid in target_channel.players.keys():
			if other_pid != player_id:
				# Spawn Other for A
				var other_node = entity_container.get_node(str(other_pid))
				if other_node:
					world_node.rpc_id(player_id, "spawn_player", other_pid, other_node.position)
				
				# d. Show Player A to OTHER players in new channel
				if p_node:
					set_entity_visibility(p_node, other_pid, true)
					# Spawn A for Other
					world_node.rpc_id(other_pid, "spawn_player", player_id, player_pos)

	# CPU Optimization Check
	update_channel_processing(target_channel_id)
	
	print("   ✅ Sync complete for channel switch")
	channel_switch_completed.emit(player_id, old_channel_id, target_channel_id)
	return true

# ============================================================
# HELPERS
# ============================================================

func _get_world_node() -> Node:
	if entity_container:
		return entity_container.get_parent()
	return null
