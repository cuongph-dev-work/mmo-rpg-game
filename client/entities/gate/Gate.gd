extends Node2D

## Gate Visual Entity
## Client-side visual representation of a gate/portal

var gate_id: int = 0
var gate_name: String = ""
var target_map_id: int = 0
var gate_type: String = "portal_blue"

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready():
	print("[Gate] Gate visual ready: %s" % gate_name)

func init(data: Dictionary):
	gate_id = data.get("id", 0)
	gate_name = data.get("name", "Gate")
	target_map_id = data.get("target_map_id", 0)
	gate_type = data.get("type", "portal_blue")
	
	# Set position
	var pos_arr = data.get("position", [0, 0])
	position = Vector2(pos_arr[0], pos_arr[1])
	
	# Set size
	var size_arr = data.get("size", [50, 50])
	var size = Vector2(size_arr[0], size_arr[1])
	$Sprite2D/ColorRect.size = size
	$Sprite2D/ColorRect.position = - size / 2
	
	# Set color based on type
	match gate_type:
		"portal_blue":
			$Sprite2D/ColorRect.color = Color(0.2, 0.4, 0.9, 0.7)
		"portal_green":
			$Sprite2D/ColorRect.color = Color(0.2, 0.8, 0.3, 0.7)
		_:
			$Sprite2D/ColorRect.color = Color(0.8, 0.2, 0.8, 0.7)
	
	# Set label
	$Label.text = gate_name
	$Label.position = Vector2(-size.x / 2, -size.y / 2 - 25)
	
	print("[Gate] 🚪 Initialized gate '%s' at %s (target: Map %d)" % [gate_name, position, target_map_id])
