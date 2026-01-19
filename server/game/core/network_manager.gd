class_name NetworkManager
extends Node

signal player_connected(player_id: int)
signal player_disconnected(player_id: int)

var network = ENetMultiplayerPeer.new()
var port: int = 3001
var max_players: int = 100

func setup(p_port: int, p_max_players: int):
	port = p_port
	max_players = p_max_players

func start_server() -> int:
	var error = network.create_server(port, max_players)
	if error != OK:
		push_error("❌ Failed to start NetworkManager on port %d: %s" % [port, error])
		return error
	
	multiplayer.multiplayer_peer = network
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	print("✅ NetworkManager started on port %d" % port)
	return OK

func _on_peer_connected(id: int):
	player_connected.emit(id)

func _on_peer_disconnected(id: int):
	player_disconnected.emit(id)
