class_name PlayerManager
extends Node

var players: Dictionary = {}  # player_id -> PlayerInfo

func add_player(player_id: int, player_data: Dictionary = {}):
	players[player_id] = {
		"player_id": player_id,
		"connected_at": Time.get_unix_time_from_system(),
		"data": player_data
	}

func remove_player(player_id: int):
	players.erase(player_id)

func get_player(player_id: int) -> Dictionary:
	return players.get(player_id, {})

func get_player_count() -> int:
	return players.size()
