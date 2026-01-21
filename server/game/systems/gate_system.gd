class_name GateSystem
extends Node

## GateSystem - Manages gates for map transfers
## Spawns Area2D collision zones and handles player entry detection

# Dependencies (Injected)
var map_instance: Map
var entity_container: Node
var game_server # Reference to GameServer

# State
var gates: Array = [] # Array of gate Area2D nodes

# Signals
signal player_entered_gate(player_id: int, gate_data: Dictionary)

func setup(map: Map, container: Node, gs) -> void:
	map_instance = map
	entity_container = container
	game_server = gs
	print("✅ GateSystem initialized")
	
	# Setup gates from config
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
		
		# Get full gate data from registry, merged with overrides
		var gate_data = GateData.get_merged_gate_data(gate_id, gate_ref)
		if gate_data.is_empty():
			print("⚠️ Gate %d not found in registry, skipping" % gate_id)
			continue
		
		_spawn_gate_area(gate_data)
	
	print("✅ Gates setup complete")

func _spawn_gate_area(gate_data: Dictionary) -> void:
	var gate_id = gate_data.get("id", 0)
	var pos_arr = gate_data.get("position", [0, 0])
	var size_arr = gate_data.get("size", [50, 50])
	var gate_name = gate_data.get("name", "Gate %d" % gate_id)
	
	var position = Vector2(pos_arr[0], pos_arr[1])
	var size = Vector2(size_arr[0], size_arr[1])
	
	# Create Area2D for collision detection
	var area = Area2D.new()
	area.name = "Gate_%d" % gate_id
	area.position = position
	area.collision_layer = 0 # Don't collide with anything
	area.collision_mask = 2 # Detect layer 2 (players)
	
	# Create CollisionShape2D
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = size
	collision_shape.shape = rect_shape
	area.add_child(collision_shape)
	
	# Store gate data in metadata
	area.set_meta("gate_data", gate_data)
	
	# Connect signal
	area.body_entered.connect(_on_body_entered_gate.bind(area))
	
	# Add to entity container (same parent as players/mobs)
	entity_container.add_child(area)
	gates.append(area)
	
	print("🚪 Spawned gate '%s' (ID: %d) at %s (size: %s)" % [gate_name, gate_id, position, size])

# ============================================================
# COLLISION HANDLING
# ============================================================

func _on_body_entered_gate(body: Node, gate_area: Area2D) -> void:
	# Check if the body is a player
	if not body.is_in_group("players"):
		return
	
	var player_id = int(str(body.name))
	var gate_data = gate_area.get_meta("gate_data")
	
	print("🚪 Player %d entered gate '%s'" % [player_id, gate_data.get("name", "")])
	
	# Validate travel conditions
	if not _is_allowed_to_travel(player_id, gate_data):
		return
	
	# Emit signal for external handling
	player_entered_gate.emit(player_id, gate_data)
	
	# Send RPC to client to initiate map transfer
	_request_map_transfer(player_id, gate_data)

func _is_allowed_to_travel(player_id: int, gate_data: Dictionary) -> bool:
	var required_level = gate_data.get("required_level", 1)
	
	# Get player node to check level
	var player_node = entity_container.get_node_or_null(str(player_id))
	if not player_node:
		return false
	
	# Check level requirement (if StatsComponent exists)
	if player_node.has_node("StatsComponent"):
		var stats = player_node.get_node("StatsComponent")
		if stats.has_method("get_level"):
			var player_level = stats.get_level()
			if player_level < required_level:
				print("🚫 Player %d level %d is below required %d" % [player_id, player_level, required_level])
				# TODO: Send RPC to notify player about level requirement
				return false
	
	# TODO: Add more checks
	# - Combat check (don't allow transfer while in combat)
	# - Cooldown check (prevent spam transfer)
	
	return true

func _request_map_transfer(player_id: int, gate_data: Dictionary) -> void:
	var target_map_id = gate_data.get("target_map_id", 0)
	var target_spawn = gate_data.get("target_spawn_pos", [0, 0])
	
	if target_map_id <= 0:
		print("⚠️ Invalid target map for gate")
		return
	
	print("🚀 Requesting map transfer for player %d -> Map %d at %s" % [player_id, target_map_id, target_spawn])
	
	# Send RPC to client via World node
	var world_node = entity_container.get_parent()
	if world_node:
		world_node.rpc_id(player_id, "on_map_transfer_requested", target_map_id, target_spawn)

# ============================================================
# DYNAMIC GATES (Event System)
# ============================================================

func spawn_dynamic_gate(params: Dictionary) -> Area2D:
	var gate_data = {
		"id": randi() % 90000 + 10000, # Random ID for dynamic gates
		"name": params.get("name", "Event Gate"),
		"position": [params.get("position", Vector2.ZERO).x, params.get("position", Vector2.ZERO).y],
		"size": params.get("size", [50, 50]),
		"target_map_id": params.get("target_map_id", 0),
		"target_spawn_pos": params.get("target_spawn_pos", [0, 0]),
		"required_level": params.get("required_level", 1),
		"is_dynamic": true
	}
	
	_spawn_gate_area(gate_data)
	var gate = gates.back()
	
	# Auto destroy timer
	if params.has("duration_seconds") and params.duration_seconds > 0:
		var duration = params.duration_seconds
		get_tree().create_timer(duration).timeout.connect(func():
			if is_instance_valid(gate):
				gates.erase(gate)
				gate.queue_free()
				print("🚪 Dynamic gate expired and removed")
		)
		
		# Notify clients for VFX
		var world_node = entity_container.get_parent()
		if world_node:
			# Broadcast to all players in map
			world_node.rpc("on_dynamic_gate_spawned", gate_data.position, duration)
	
	return gate

# ============================================================
# CLEANUP
# ============================================================

func cleanup() -> void:
	for gate in gates:
		if is_instance_valid(gate):
			gate.queue_free()
	gates.clear()
