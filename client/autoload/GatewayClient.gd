extends Node

## GatewayClient - WebSocket Gateway Communication
## Handles connection to Gateway service and enter_world protocol

# Signals
signal gateway_connected()
signal gateway_disconnected()
signal enter_world_success(data: Dictionary)
signal gateway_error(error: Dictionary)

# WebSocket
var ws: WebSocketPeer = null
var connection_status: WebSocketPeer.State = WebSocketPeer.STATE_CLOSED
var is_connecting: bool = false

func _ready():
	print("[GatewayClient] Gateway client initialized")

func _process(_delta):
	if ws:
		ws.poll()
		var state = ws.get_ready_state()
		
		# Connection state changed
		if state != connection_status:
			connection_status = state
			_on_connection_state_changed(state)
		
		# Process incoming messages
		if state == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var packet = ws.get_packet()
				var message = packet.get_string_from_utf8()
				_on_message_received(message)

func connect_to_gateway(token: String) -> void:
	"""Connect to Gateway WebSocket with authentication token"""
	if is_connecting or (ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN):
		print("[GatewayClient] ⚠️ Already connected or connecting")
		return
	
	var gateway_url = Config.get_gateway_url()
	var url = gateway_url + "?token=" + token
	
	print("[GatewayClient] Connecting to Gateway: %s" % gateway_url)
	
	ws = WebSocketPeer.new()
	var err = ws.connect_to_url(url)
	
	if err != OK:
		print("[GatewayClient] ❌ Failed to connect: %s" % err)
		gateway_error.emit({"code": "CONNECTION_FAILED", "message": "Failed to connect to Gateway"})
		return
	
	is_connecting = true

func disconnect_from_gateway() -> void:
	"""Disconnect from Gateway"""
	if ws:
		ws.close()
		ws = null
	connection_status = WebSocketPeer.STATE_CLOSED
	is_connecting = false
	print("[GatewayClient] Disconnected from Gateway")

func send_enter_world(character_id: String) -> void:
	"""Send enter_world message to Gateway"""
	if not ws or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("[GatewayClient] ❌ Cannot send enter_world - not connected")
		return
	
	var message = {
		"event": "enter_world",
		"data": {
			"character_id": character_id
		}
	}
	
	var json_string = JSON.stringify(message)
	ws.send_text(json_string)
	print("[GatewayClient] 📤 Sent enter_world for character: %s" % character_id)

func send_join_map(map_id: int) -> void:
	"""Send join_map message to Gateway"""
	if not ws or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("[GatewayClient] ❌ Cannot send join_map - not connected")
		return
	
	var message = {
		"event": "join_map",
		"data": {
			"map_id": map_id
		}
	}
	
	var json_string = JSON.stringify(message)
	ws.send_text(json_string)
	print("[GatewayClient] 📤 Sent join_map for map: %d" % map_id)

func _on_connection_state_changed(state: WebSocketPeer.State) -> void:
	"""Handle WebSocket connection state changes"""
	match state:
		WebSocketPeer.STATE_OPEN:
			print("[GatewayClient] ✅ Connected to Gateway")
			is_connecting = false
			gateway_connected.emit()
		
		WebSocketPeer.STATE_CLOSED:
			print("[GatewayClient] 🔌 Disconnected from Gateway")
			is_connecting = false
			gateway_disconnected.emit()

func _on_message_received(message: String) -> void:
	"""Handle incoming WebSocket messages"""
	print("[GatewayClient] 📥 Received: %s" % message)
	
	var json = JSON.new()
	var parse_result = json.parse(message)
	
	if parse_result != OK:
		print("[GatewayClient] ❌ Failed to parse message: %s" % message)
		return
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		print("[GatewayClient] ❌ Invalid message format")
		return
	
	var event = data.get("event", "")
	var payload = data.get("data", {})
	
	_handle_event(event, payload)

func _handle_event(event: String, payload: Dictionary) -> void:
	"""Route events to appropriate handlers"""
	match event:
		"welcome":
			print("[GatewayClient] 👋 Welcome message: %s" % payload.get("message", ""))
		
		"enter_world_success":
			print("[GatewayClient] ✅ Enter world success!")
			enter_world_success.emit(payload)
		
		"join_map_success":
			print("[GatewayClient] ✅ Join map success: %s" % payload)
		
		"error":
			var error_code = payload.get("code", "UNKNOWN")
			var error_message = payload.get("message", "Unknown error")
			print("[GatewayClient] ❌ Error: %s - %s" % [error_code, error_message])
			gateway_error.emit(payload)
		
		_:
			print("[GatewayClient] ⚠️ Unhandled event: %s" % event)
