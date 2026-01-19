extends Node

## Global Configuration
## Provides centralized access to game configuration values

# Network settings
var auth_service_url: String = "http://localhost:3000"
var gateway_url: String = "ws://localhost:3002/ws"
var reconnect_delay: float = 3.0
var network_logging_enabled: bool = true

# Player settings
var player_speed: float = 200.0

# Entity settings
var interpolation_rate: float = 0.1

func _ready():
	print("[Config] Configuration initialized")

func get_auth_service_url() -> String:
	return auth_service_url

func get_gateway_url() -> String:
	return gateway_url

func get_player_speed() -> float:
	return player_speed

func get_interpolation_rate() -> float:
	return interpolation_rate

func is_network_logging_enabled() -> bool:
	return network_logging_enabled

func get_value(section: String, key: String, default_value):
	"""Generic getter for configuration values"""
	# Map section/key pairs to actual config values
	if section == "network" and key == "reconnect_delay":
		return reconnect_delay
	
	return default_value
