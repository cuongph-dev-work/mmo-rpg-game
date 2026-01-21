class_name GateSystem
extends Node

## GateSystem - Manages gates for map transfers
## Uses Gate.tscn scene for collision zones

# Scene
const GateScene = preload("res://scenes/gate/Gate.tscn")

# Dependencies (Injected)
var map_instance: Map
var entity_container: Node
var game_server # Reference to GameServer

# State
var gates: Array = [] # Array of GateEntity nodes
var player_cooldowns: Dictionary = {} # Map<player_id, timestamp_ms>

# Signals
signal player_entered_gate(player_id: int, gate_data: Dictionary)

func setup(map: Map, container: Node, gs) -> void:
	map_instance = map
	entity_container = container
	game_server = gs
	print("✅ GateSystem initialized")
	
	_setup_gates()

# ============================================================
# GATE SETUP
# ============================================================

func _setup_gates() -> void:
	if not map_instance or not map_instance.config:
		return
	
	var gate_refs = map_instance.config.gates
	if gate_refs.is_empty():
		print("🚪 No gates configured for this map")
		return
	
	print("🚪 Setting up %d gates..." % gate_refs.size())
	
	for gate_ref in gate_refs:
		var gate_id = gate_ref.get("gate_id")
		var gate_data = GateData.get_merged_gate_data(gate_id, gate_ref)
		if gate_data.is_empty():
			print("⚠️ Gate %d not found in registry, skipping" % gate_id)
			continue
		
		_spawn_gate(gate_data)
	
	print("✅ Gates setup complete")

func _spawn_gate(gate_data: Dictionary) -> void:
	var gate = GateScene.instantiate()
	gate.name = "Gate_%d" % gate_data.get("id", 0)
	
	# Connect signal before adding to tree
	gate.player_entered.connect(_on_player_entered_gate)
	
	# Add to scene tree first
	entity_container.add_child(gate)
	
	# Initialize with data
	gate.init(gate_data)
	
	gates.append(gate)
	
	print("🚪 Spawned gate '%s' (ID: %d) at %s (size: %s)" % [gate_data.get("name", "Gate"), gate_data.get("id", 0), gate_data.get("position", Vector2.ZERO), gate_data.get("size", Vector2(50, 50))])


# ============================================================
# PLAYER SYNC
# ============================================================

func sync_gates_to_player(player_id: int) -> void:
	var world_node = _get_world_node()
	if not world_node:
		return
	
	for gate in gates:
		var gate_data = gate.get_gate_data()
		var pos_arr = gate_data.get("position", [0, 0])
		var size_arr = gate_data.get("size", [50, 50])
		
		world_node.rpc_id(
			player_id,
			"spawn_gate",
			gate_data.get("id", 0),
			Vector2(pos_arr[0], pos_arr[1]),
			Vector2(size_arr[0], size_arr[1]),
			gate_data.get("name", "Gate"),
			gate_data.get("type", "portal_blue"),
			gate_data.get("target_map_id", 0)
		)
	
	print("🚪 Synced %d gates to player %d" % [gates.size(), player_id])
	
	# Set cooldown on connect/sync to prevent immediate back-port
	set_player_cooldown(player_id, 5.0)


# ============================================================
# COLLISION HANDLING
# ============================================================

func _on_player_entered_gate(player_id: int, gate_entity: Node2D) -> void:
	var gate_data = gate_entity.get_gate_data()
	
	# Check Cooldown
	if _is_player_on_cooldown(player_id):
		return
	
	print("🚪 Player %d entered gate '%s'" % [player_id, gate_data.get("name", "")])
	
	if not _is_allowed_to_travel(player_id, gate_data):
		return
	
	player_entered_gate.emit(player_id, gate_data)
	
	# Set cooldown to prevent double trigger
	set_player_cooldown(player_id, 5.0)
	
	_request_map_transfer(player_id, gate_data)

func _is_allowed_to_travel(player_id: int, gate_data: Dictionary) -> bool:
	var required_level = gate_data.get("required_level", 1)
	var player_node = entity_container.get_node_or_null(str(player_id))
	if not player_node:
		return false
	
	# Check level requirement
	if player_node.has_node("StatsComponent"):
		var stats = player_node.get_node("StatsComponent")
		if stats.has_method("get_level"):
			var player_level = stats.get_level()
			if player_level < required_level:
				print("🚫 Player %d level %d is below required %d" % [player_id, player_level, required_level])
				return false
	
	return true

func _request_map_transfer(player_id: int, gate_data: Dictionary) -> void:
	var target_map_id = gate_data.get("target_map_id", 0)
	var target_spawn = gate_data.get("target_spawn_pos", [0, 0])
	
	if target_map_id <= 0:
		print("⚠️ Invalid target map for gate")
		return
	
	print("🚀 Requesting map transfer for player %d -> Map %d at %s" % [player_id, target_map_id, target_spawn])
	
	var world_node = _get_world_node()
	if world_node:
		world_node.rpc_id(player_id, "on_map_transfer_requested", target_map_id, target_spawn)

func set_player_cooldown(player_id: int, duration: float) -> void:
	var end_time = Time.get_ticks_msec() + (duration * 1000)
	player_cooldowns[player_id] = end_time
	print("⏳ Gate Cooldown set for Player %d (%.1fs)" % [player_id, duration])

func _is_player_on_cooldown(player_id: int) -> bool:
	if not player_cooldowns.has(player_id):
		return false
		
	var current_time = Time.get_ticks_msec()
	if current_time < player_cooldowns[player_id]:
		return true
		
	# Cleanup expired
	player_cooldowns.erase(player_id)
	return false

# ============================================================
# DYNAMIC GATES (Event System)
# ============================================================

func spawn_dynamic_gate(params: Dictionary) -> Node2D:
	var pos = params.get("position", Vector2.ZERO)
	var gate_data = {
		"id": randi() % 90000 + 10000,
		"name": params.get("name", "Event Gate"),
		"position": [pos.x, pos.y],
		"size": params.get("size", [50, 50]),
		"target_map_id": params.get("target_map_id", 0),
		"target_spawn_pos": params.get("target_spawn_pos", [0, 0]),
		"required_level": params.get("required_level", 1),
		"type": params.get("type", "portal_blue"),
		"is_dynamic": true
	}
	
	_spawn_gate(gate_data)
	var gate = gates.back()
	
	# Auto destroy timer
	var duration = params.get("duration_seconds", 0)
	if duration > 0:
		get_tree().create_timer(duration).timeout.connect(func():
			if is_instance_valid(gate):
				gates.erase(gate)
				gate.queue_free()
				print("🚪 Dynamic gate expired and removed")
		)
		
		var world_node = _get_world_node()
		if world_node:
			world_node.rpc("on_dynamic_gate_spawned", gate_data.position, duration)
	
	return gate


# ============================================================
# HELPERS
# ============================================================

func _get_world_node() -> Node:
	if entity_container:
		return entity_container.get_parent()
	return null

func _arr_to_vec2(arr: Array) -> Vector2:
	if arr.size() >= 2:
		return Vector2(arr[0], arr[1])
	return Vector2.ZERO

# ============================================================
# CLEANUP
# ============================================================

func cleanup() -> void:
	for gate in gates:
		if is_instance_valid(gate):
			gate.queue_free()
	gates.clear()
