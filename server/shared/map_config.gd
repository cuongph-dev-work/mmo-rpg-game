class_name MapConfig
extends Resource

@export var map_id: int
@export var map_name: String
@export var max_channels: int = 5
@export var max_players_per_channel: int = 50
@export var scene_path: String
@export var description: String = ""
@export var mob_spawns: Array = []
@export var gates: Array = [] # Gate references [{ gate_id, size? }]