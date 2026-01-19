extends Node

## Global Event Bus
## Provides decoupled communication between components via signals

# Connection events
signal connection_established()
signal connection_lost()

# Map events
signal spawn_position_set(position: Vector2)
signal map_loaded(map_id: String)
signal map_transition_requested(map_id: String, gate_id: String)

# Player events
signal player_spawned(player_id: String)
signal player_despawned(player_id: String)

# Mob events
signal mob_spawned(mob_id: String)
signal mob_despawned(mob_id: String)

# UI events
signal show_notification(message: String, type: String)
signal show_error(message: String)

# Game state events
signal game_state_changed(new_state: String)

func _ready():
	print("[Bus] Event bus initialized")
