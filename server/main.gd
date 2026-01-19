extends Node

## Entry point for MMO RPG Game Server
## Simplified MVP version - just starts a Map Server

func _ready():
	print("==================================================")
	print("MMO RPG Game Server - MVP")
	print("==================================================")
	
	start_game_server()

func start_game_server():
	var game_server = GameServer.new()
	add_child(game_server)
