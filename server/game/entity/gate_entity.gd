class_name GateEntity
extends Node2D

## Server-side Gate Entity
## Handles player detection and mob blocking

var gate_id: int = 0
var gate_name: String = ""
var target_map_id: int = 0
var target_spawn_pos: Array = [0, 0]
var required_level: int = 1
var gate_type: String = "portal_blue"

signal player_entered(player_id: int, gate_entity: Node2D)

@onready var detection_area: Area2D = $DetectionArea
@onready var mob_blocker: StaticBody2D = $MobBlocker

func _ready():
	detection_area.body_entered.connect(_on_body_entered)

func init(data: Dictionary) -> void:
	gate_id = data.get("id", 0)
	gate_name = data.get("name", "Gate")
	target_map_id = data.get("target_map_id", 0)
	target_spawn_pos = data.get("target_spawn_pos", [0, 0])
	required_level = data.get("required_level", 1)
	gate_type = data.get("type", "portal_blue")
	
	# Set position
	var pos_arr = data.get("position", [0, 0])
	position = Vector2(pos_arr[0], pos_arr[1])
	
	# Set size
	var size_arr = data.get("size", [50, 50])
	var size = Vector2(size_arr[0], size_arr[1])
	_update_collision_size(size)
	
	# Store full data in metadata for sync
	set_meta("gate_data", data)
	
	print("🚪 Gate '%s' (ID: %d) initialized at %s" % [gate_name, gate_id, position])

func _update_collision_size(size: Vector2) -> void:
	# Update detection area shape with PADDING (to compensate for latency)
	var detect_shape = detection_area.get_node("CollisionShape2D")
	if detect_shape and detect_shape.shape:
		var padding = 20.0 # +10px each side
		detect_shape.shape.size = size + Vector2(padding, padding)
	
	# Update mob blocker shape (Keep EXACT size to avoid invisible walls)
	var blocker_shape = mob_blocker.get_node("CollisionShape2D")
	if blocker_shape and blocker_shape.shape:
		blocker_shape.shape.size = size

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players"):
		var player_id = int(str(body.name))
		print("🚪 Player %d entered gate '%s'" % [player_id, gate_name])
		player_entered.emit(player_id, self)

func get_gate_data() -> Dictionary:
	return get_meta("gate_data", {})
