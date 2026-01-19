class_name BaseEntity
extends CharacterBody2D

## Base Entity Class
## Shared logic for networked entities (Players, Mobs)

@export var speed: float = 0.0

var entity_id: String = ""
var entity_type: String = "entity"
var server_sync_position: Vector2 = Vector2.ZERO # Synced from Server for interpolation

func _ready():
	if entity_id == "":
		entity_id = name
		print("[Entity] Auto-set entity_id: %s" % entity_id)

func set_entity_id(id: String) -> void:
	entity_id = id

func get_entity_id() -> String:
	return entity_id

func set_entity_type(type: String) -> void:
	entity_type = type

func get_entity_type() -> String:
	return entity_type
