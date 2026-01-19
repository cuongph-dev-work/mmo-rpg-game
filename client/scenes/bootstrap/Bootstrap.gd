extends Node

## Bootstrap Scene
## Entry point - handles connection and initial game setup

@onready var status_label: Label = $UI/Panel/VBoxContainer/StatusLabel

func _ready():
	print("[Bootstrap] Starting bootstrap sequence...")
	
	# Setup UI
	if status_label:
		status_label.text = "Initializing..."
	else:
		print("Warning: UI/StatusLabel not found")
	
	# Just wait a moment then load world
	await get_tree().create_timer(0.5).timeout
	_load_world()

func _load_world():
	"""Load the world scene"""
	if status_label:
		status_label.text = "Loading World..."
	
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/world/World.tscn")
