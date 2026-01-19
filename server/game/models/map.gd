class_name Map
extends Node

var map_id: int
var channels: Dictionary = {}  # channel_id -> Channel
var config: MapConfig

func initialize(map_id_param: int):
	map_id = map_id_param
	load_map_config()
	create_channels()

func load_map_config():
	# Load từ data files
	config = MapDataManager.load_map_config(map_id)
	print("Loaded map config: ", config.map_name, " (ID: ", config.map_id, ", Channels: ", config.max_channels, ")")

func create_channels():
	for i in range(config.max_channels):
		var channel = Channel.new()
		channel.initialize(map_id, i + 1, config.max_players_per_channel)
		channels[i + 1] = channel
		add_child(channel)

func get_channel(channel_id: int) -> Channel:
	return channels.get(channel_id)

func get_channel_count() -> int:
	return channels.size()

func get_available_channel() -> Channel:
	for channel in channels.values():
		if not channel.is_full():
			return channel
	return null

func get_total_player_count() -> int:
	var total = 0
	for channel in channels.values():
		total += channel.get_player_count()
	return total

func assign_player_to_channel(player_id: int, preferred_channel_id: int = -1) -> bool:
	var channel: Channel = null
	
	if preferred_channel_id > 0:
		# Assign vào channel được chỉ định
		channel = get_channel(preferred_channel_id)
		if channel and not channel.is_full():
			channel.add_player(player_id)
			return true
		else:
			print("Warning: Preferred channel ", preferred_channel_id, " is full or not found")
	
	# Auto-assign vào channel có slot
	channel = get_available_channel()
	if channel:
		channel.add_player(player_id)
		return true
	
	return false

func get_player_channel(player_id: int) -> Channel:
	for channel in channels.values():
		if channel.players.has(player_id):
			return channel
	return null
