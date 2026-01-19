extends Resource
class_name MapDef

## Map Definition Resource
## Defines map properties and configuration

@export var map_id: String = ""
@export var display_name: String = ""
@export var bounds: Rect2 = Rect2(0, 0, 2000, 2000)
@export var spawn_points: Array[Vector2] = []

func _init():
	pass
