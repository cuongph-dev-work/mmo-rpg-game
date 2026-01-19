class_name Channel
extends Node

var map_id: int
var channel_id: int
var players: Dictionary = {} # player_id -> PlayerData
var max_players: int

func initialize(map: int, channel: int, max_val: int):
	map_id = map
	channel_id = channel
	max_players = max_val

func get_player_count() -> int:
	return players.size()

func is_full() -> bool:
	return players.size() >= max_players

func add_player(player_id: int, player_data: Dictionary = {}):
	players[player_id] = player_data
	# notify_players_joined.rpc(player_id) - Disabled for MVP (Client doesn't have Channel nodes)

func remove_player(player_id: int):
	players.erase(player_id)
	# notify_players_left.rpc(player_id) - Disabled for MVP
