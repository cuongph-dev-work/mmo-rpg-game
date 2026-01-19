extends Node

## Application Manager
## Manages application lifecycle, scene transitions, and global state

enum GameState {
	BOOTSTRAP,
	CONNECTING,
	IN_GAME,
	DISCONNECTED
}

var current_state: GameState = GameState.BOOTSTRAP

func _ready():
	print("[App] Application manager initialized")
	
	# Connect to quit signals
	get_tree().auto_accept_quit = false
	
	# Listen to connection events
	Bus.connection_established.connect(_on_connection_established)
	Bus.connection_lost.connect(_on_connection_lost)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func change_scene(scene_path: String) -> void:
	"""Change to a different scene"""
	print("[App] Changing scene to: %s" % scene_path)
	get_tree().change_scene_to_file(scene_path)

func quit_game() -> void:
	"""Quit the application gracefully"""
	print("[App] Quitting game...")
	
	# Disconnect from server
	Net.disconnect_from_server()
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	get_tree().quit()

func set_game_state(new_state: GameState) -> void:
	"""Update the current game state"""
	if current_state == new_state:
		return
	
	current_state = new_state
	Bus.game_state_changed.emit(get_state_string())
	print("[App] Game state changed to: %s" % get_state_string())

func get_state_string() -> String:
	"""Get current game state as string"""
	match current_state:
		GameState.BOOTSTRAP:
			return "BOOTSTRAP"
		GameState.CONNECTING:
			return "CONNECTING"
		GameState.IN_GAME:
			return "IN_GAME"
		GameState.DISCONNECTED:
			return "DISCONNECTED"
		_:
			return "UNKNOWN"

func _on_connection_established():
	set_game_state(GameState.CONNECTING)

func _on_connection_lost():
	if current_state == GameState.IN_GAME:
		set_game_state(GameState.DISCONNECTED)
		Bus.show_error.emit("Connection to server lost")
