class_name MapDataManager
extends RefCounted

static func load_map_config(map_id: int) -> MapConfig:
	var file_path = "res://data/maps/map_%d.json" % map_id
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		print("Warning: Map config not found for map_id ", map_id, ", using defaults")
		return create_default_config(map_id)
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Error parsing map config for map_id ", map_id)
		return create_default_config(map_id)
	
	var data = json.data
	var config = MapConfig.new()
	config.map_id = data.get("map_id", map_id)
	config.map_name = data.get("map_name", "Unknown Map")
	config.max_channels = data.get("max_channels", 5)
	config.max_players_per_channel = data.get("max_players_per_channel", 50)
	config.scene_path = data.get("scene_path", "")
	config.description = data.get("description", "")
	config.mob_spawns = data.get("mob_spawns", [])
	
	return config

static func create_default_config(map_id: int) -> MapConfig:
	var config = MapConfig.new()
	config.map_id = map_id
	config.map_name = "Map %d" % map_id
	config.max_channels = 5
	config.max_players_per_channel = 50
	config.scene_path = ""
	config.description = ""
	return config

static func get_all_map_ids() -> Array:
	var map_ids = []
	var dir = DirAccess.open("res://data/maps/")
	
	if dir == null:
		return map_ids
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.begins_with("map_") and file_name.ends_with(".json"):
			var id_str = file_name.trim_prefix("map_").trim_suffix(".json")
			if id_str.is_valid_int():
				map_ids.append(int(id_str))
		file_name = dir.get_next()
	
	map_ids.sort()
	return map_ids
