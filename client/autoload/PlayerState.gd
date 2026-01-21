extends Node

## PlayerState - Global Player State Management
## Stores runtime player data like current position, map info, etc.

# Signals
signal position_changed(pos: Vector2)
signal map_changed(map_id: int, map_name: String)

# Current Position
var current_position: Vector2 = Vector2.ZERO:
	set(value):
		current_position = value
		position_changed.emit(value)

# Current Map Info
var current_map_id: int = 0
var current_map_name: String = ""

# Local Player Reference
var local_player: Node = null

func _ready():
	print("[PlayerState] Player state initialized")

func set_local_player(player: Node) -> void:
	local_player = player
	print("[PlayerState] Local player set: %s" % player.name)

func update_position(pos: Vector2) -> void:
	current_position = pos

func set_current_map(map_id: int, map_name: String = "") -> void:
	current_map_id = map_id
	current_map_name = map_name
	map_changed.emit(map_id, map_name)
	print("[PlayerState] Current map: %s (ID: %d)" % [map_name, map_id])

func clear() -> void:
	"""Clear player state on logout"""
	current_position = Vector2.ZERO
	current_map_id = 0
	current_map_name = ""
	local_player = null
	print("[PlayerState] Player state cleared")
