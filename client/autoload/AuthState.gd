extends Node

## AuthState - Authentication & Character State Management
## Stores user authentication and current character information

# Authentication state
var access_token: String = ""
var user_id: String = ""

# Character state
var current_character_id: String = ""
var current_character_data: Dictionary = {}

# Map Server allocation data (from Gateway enter_world_success)
var map_server_data: Dictionary = {}

# Persistent storage path
const SAVE_PATH = "user://auth_state.json"

func _ready():
	print("[AuthState] Authentication state manager initialized")

## Authentication Methods

func set_auth(token: String, user: String) -> void:
	"""Store authentication credentials"""
	access_token = token
	user_id = user
	print("[AuthState] ✅ Authentication set for user: %s" % user_id)

func clear_auth() -> void:
	"""Clear all authentication and character data"""
	access_token = ""
	user_id = ""
	current_character_id = ""
	current_character_data = {}
	print("[AuthState] 🔓 Authentication cleared")

func is_authenticated() -> bool:
	"""Check if user is authenticated"""
	return access_token != "" and user_id != ""

func get_auth_header() -> String:
	"""Get Bearer token header for HTTP requests"""
	return "Bearer " + access_token

## Character Methods

func set_character(character_id: String, character_data: Dictionary) -> void:
	"""Store current character information"""
	current_character_id = character_id
	current_character_data = character_data
	print("[AuthState] 👤 Character set: %s (ID: %s)" % [character_data.get("name", "Unknown"), character_id])

func clear_character() -> void:
	"""Clear current character selection"""
	current_character_id = ""
	current_character_data = {}
	print("[AuthState] Character cleared")

func has_character() -> bool:
	"""Check if a character is selected"""
	return current_character_id != ""

func get_character_name() -> String:
	"""Get current character name"""
	return current_character_data.get("name", "")

func get_character_map_id() -> int:
	"""Get current character's map ID"""
	return current_character_data.get("map_id", 1)

func get_character_position() -> Vector2:
	"""Get current character's position"""
	var pos = current_character_data.get("position", {"x": 0, "y": 0})
	return Vector2(pos.get("x", 0), pos.get("y", 0))

## Persistence Methods

func save_to_disk() -> void:
	"""Save auth state to disk for auto-login"""
	var save_data = {
		"access_token": access_token,
		"user_id": user_id,
		"current_character_id": current_character_id,
		"current_character_data": current_character_data,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("[AuthState] 💾 Auth state saved to disk")
	else:
		print("[AuthState] ❌ Failed to save auth state")

func load_from_disk() -> bool:
	"""Load auth state from disk. Returns true if valid data loaded."""
	if not FileAccess.file_exists(SAVE_PATH):
		print("[AuthState] No saved auth state found")
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		print("[AuthState] ❌ Failed to open auth state file")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("[AuthState] ❌ Failed to parse saved auth state")
		return false
	
	var save_data = json.get_data()
	
	# Check if token is expired (24 hours)
	var timestamp = save_data.get("timestamp", 0)
	var current_time = Time.get_unix_time_from_system()
	var age_hours = (current_time - timestamp) / 3600.0
	
	if age_hours > 24:
		print("[AuthState] ⏰ Saved auth state expired (%.1f hours old)" % age_hours)
		clear_saved_state()
		return false
	
	# Restore state
	access_token = save_data.get("access_token", "")
	user_id = save_data.get("user_id", "")
	current_character_id = save_data.get("current_character_id", "")
	current_character_data = save_data.get("current_character_data", {})
	
	print("[AuthState] ✅ Auth state loaded from disk (%.1f hours old)" % age_hours)
	print("[AuthState] User: %s, Character: %s" % [user_id, current_character_id])
	return true

func clear_saved_state() -> void:
	"""Delete saved auth state from disk"""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("[AuthState] 🗑️ Saved auth state deleted")
