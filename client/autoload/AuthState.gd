extends Node

## AuthState - Authentication & Character State Management
## Stores user authentication and current character information

# Authentication state
var access_token: String = ""
var user_id: String = ""

# Character state
var current_character_id: String = ""
var current_character_data: Dictionary = {}

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
