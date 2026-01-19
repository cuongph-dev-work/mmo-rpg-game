extends Node

## Network Manager
## Handles ENet connection and multiplayer signals

var peer = ENetMultiplayerPeer.new()
var hostname = "127.0.0.1"
var port = 3001

func _ready():
	print("[Net] Network manager initialized (ENet)")
	
	# Connect to multiplayer signals
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func connect_to_server():
	"""Connect to the game server"""
	print("[Net] Connecting to %s:%d..." % [hostname, port])
	
	var error = peer.create_client(hostname, port)
	if error != OK:
		print("[Net] ❌ Failed to create client: %s" % error)
		return
		
	multiplayer.multiplayer_peer = peer

func disconnect_from_server():
	"""Disconnect from server"""
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	print("[Net] Disconnected")

func _on_connected_to_server():
	print("[Net] ✅ Connected to server!")
	Bus.connection_established.emit()

func _on_connection_failed():
	print("[Net] ❌ Connection failed")
	Bus.connection_lost.emit()
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	print("[Net] ⚠️ Server disconnected")
	Bus.connection_lost.emit()
	multiplayer.multiplayer_peer = null

func is_network_connected() -> bool:
	return multiplayer.multiplayer_peer != null and \
		   multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
