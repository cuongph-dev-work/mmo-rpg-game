extends Node2D

## World Scene
## Main game world container

@onready var entity_container: Node2D = $EntityContainer
@onready var position_label: Label = $UI/PositionLabel

var spawn_position: Vector2 = Vector2(400, 300)
var player_scene = preload("res://entities/player/Player.tscn")
var mob_scene = preload("res://entities/mob/Mob.tscn")

func _ready():
	print("[World] World scene loaded")
	
	# Listen for global events
	Bus.spawn_position_set.connect(_on_spawn_position_set)
	Bus.connection_established.connect(_on_net_connected)
	
	# Multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	# Gateway session events
	GatewayClient.session_replaced.connect(_on_session_replaced)
	
	# GameState position updates
	PlayerState.position_changed.connect(_on_position_changed)
	
	# UI Setup
	var channel_selector = $UI/ChannelSelector
	if channel_selector:
		channel_selector.item_selected.connect(_on_channel_selected)
	
	# Check if we have map server data from Character Select
	if AuthState.map_server_data.is_empty():
		print("[World] ERROR: No map server data! Returning to character select...")
		get_tree().change_scene_to_file("res://scenes/character_select/CharacterSelect.tscn")
		return
	
	# Use map server data from AuthState
	_connect_to_map_server(AuthState.map_server_data)

func _connect_to_map_server(data: Dictionary):
	"""Connect to allocated Map Server using data from Gateway"""
	var map_ip = data.get("map_ip", "127.0.0.1")
	var map_port = data.get("map_port", 4001)
	var ticket = data.get("ticket", "")
	var spawn_pos = data.get("spawn_pos", {"x": 400, "y": 300})
	
	print("[World] 🎯 Received Map Server allocation:")
	print("  - IP: %s" % map_ip)
	print("  - Port: %d" % map_port)
	print("  - Ticket: %s" % ticket)
	print("  - Spawn: (%s, %s)" % [spawn_pos.get("x"), spawn_pos.get("y")])
	
	# Set spawn position
	spawn_position = Vector2(spawn_pos.get("x", 400), spawn_pos.get("y", 300))
	Bus.spawn_position_set.emit(spawn_position)
	
	# Connect to Map Server
	print("[World] Connecting to Map Server at %s:%d..." % [map_ip, map_port])
	Net.connect_to_server(map_ip, map_port)
	
	# UI Setup
	var channel_selector = $UI/ChannelSelector
	if channel_selector:
		channel_selector.item_selected.connect(_on_channel_selected)

func _on_channel_selected(index: int):
	# index is 0-based, IDs are 1-based (set in tscn)
	var channel_id = index + 1
	print("[UI] Requesting switch to Channel %d" % channel_id)
	
	# Call Server RPC
	# Route: Client(World) -> Server(World) -> MapServer
	rpc_id(1, "request_channel_change", channel_id)

@rpc("any_peer", "call_remote", "reliable")
func request_channel_change(target_channel_id: int):
	# Stub for RPC mechanism
	pass

func _on_net_connected():
	print("[World] Connection established!")
	
	# Spawn local player immediately so we can receive server sync data
	var my_id = multiplayer.get_unique_id()
	print("[World] Spawning local player: %d" % my_id)
	_spawn_player(my_id)

func _on_peer_connected(id):
	if id == 1:
		return
		
	print("[World] Peer connected: %d" % id)
	_spawn_player(id)

func _on_peer_disconnected(id):
	print("[World] Peer disconnected: %d" % id)
	if entity_container.has_node(str(id)):
		entity_container.get_node(str(id)).queue_free()

func _on_spawn_position_set(pos: Vector2):
	spawn_position = pos
	print("[World] Spawn position set to: %s" % spawn_position)

func _on_position_changed(pos: Vector2):
	if position_label:
		position_label.text = "Position: (%.0f, %.0f)" % [pos.x, pos.y]


func _spawn_player(id: int):
	if entity_container.has_node(str(id)):
		return

	var player = player_scene.instantiate()
	
	player.position = spawn_position
	player.name = str(id)
	
	# Set Multiplayer Authority
	player.set_multiplayer_authority(id)
	
	# Ensure Synchronizer listens to Server (Authority 1)
	if player.has_node("MultiplayerSynchronizer"):
		player.get_node("MultiplayerSynchronizer").set_multiplayer_authority(1)
	
	entity_container.add_child(player)
	
	Bus.player_spawned.emit(str(id))
	print("[World] Player spawned: %d" % id)

@rpc("authority", "call_remote", "reliable")
func spawn_mob(id: int, pos: Vector2, type_id: String, is_elite: bool):
	print("DEBUG: Client received spawn_mob RPC for ID: ", id)
	if entity_container.has_node(str(id)):
		print("DEBUG: Mob %d already exists, skipping." % id)
		return
		
	var mob = mob_scene.instantiate()
	mob.name = str(id)
	mob.position = pos
	
	# Sync Authority: Server (1)
	mob.set_multiplayer_authority(1)
	if mob.has_node("MultiplayerSynchronizer"):
		mob.get_node("MultiplayerSynchronizer").set_multiplayer_authority(1)
	
	# Init Client Mob (Visuals)
	if mob.has_method("init"):
		mob.init(type_id, is_elite)
		
	entity_container.add_child(mob)
	
	Bus.mob_spawned.emit(str(id))
	print("[World] Mob spawned: %d (%s) at %s" % [id, type_id, pos])

@rpc("authority", "call_remote", "reliable")
func despawn_mob(id: int):
	if entity_container.has_node(str(id)):
		var node = entity_container.get_node(str(id))
		node.queue_free()
		Bus.mob_despawned.emit(str(id))
		print("[World] Mob despawned: %d" % id)

# ============================================================
# GATE SYSTEM - MAP TRANSFER
# ============================================================

@rpc("authority", "call_remote", "reliable")
func on_map_transfer_requested(target_map_id: int, target_spawn_pos: Array):
	"""Handle server request to transfer to another map"""
	print("[World] 🚀 Map transfer requested to Map %d at %s" % [target_map_id, target_spawn_pos])
	
	# Store target spawn position
	var spawn_pos = Vector2(target_spawn_pos[0], target_spawn_pos[1])
	
	# Disconnect from current map server
	print("[World] Disconnecting from current map server...")
	Net.disconnect_from_server()
	
	# Request new map server from Gateway
	print("[World] Requesting new map server for Map %d from Gateway..." % target_map_id)
	GatewayClient.send_join_map(target_map_id)
	
	# Wait for Gateway response via signal
	# The _on_map_transfer_success callback will handle reconnection
	GatewayClient.map_transfer_success.connect(_on_map_transfer_success.bind(spawn_pos), CONNECT_ONE_SHOT)

func _on_map_transfer_success(data: Dictionary, override_spawn_pos: Vector2):
	"""Handle successful map transfer - connect to new map server"""
	print("[World] ✅ Received new map server data: %s" % data)
	
	# Update AuthState with new map server data
	AuthState.map_server_data = data
	
	# Override spawn position with gate's target position
	if override_spawn_pos != Vector2.ZERO:
		AuthState.map_server_data["spawn_pos"] = {
			"x": override_spawn_pos.x,
			"y": override_spawn_pos.y
		}
	
	# Reload world scene to connect to new map
	get_tree().reload_current_scene()

@rpc("authority", "call_remote", "reliable")
func on_dynamic_gate_spawned(pos: Array, duration_seconds: float):
	"""Handle dynamic gate spawn notification for VFX"""
	var position = Vector2(pos[0], pos[1])
	print("[World] 🌀 Dynamic gate spawned at %s (duration: %.0fs)" % [position, duration_seconds])
	
	# TODO: Spawn visual effect for dynamic gate
	# var gate_vfx = gate_vfx_scene.instantiate()
	# gate_vfx.position = position
	# entity_container.add_child(gate_vfx)


@rpc("authority", "call_remote", "reliable")
func spawn_player(id: int, pos: Vector2):
	print("[World] RPC spawn_player received: %d at %s" % [id, pos])
	if entity_container.has_node(str(id)):
		# Nếu player đã tồn tại, chỉ cần update vị trí (teleport)
		var p = entity_container.get_node(str(id))
		p.position = pos
		# Reset physics interpolation nếu cần
		p.server_sync_position = pos
		return
		
	# Nếu là local player (id == my_id), đã được spawn ở _on_net_connected rồi, 
	# nhưng có thể server muốn force spawn lại hoặc di chuyển?
	var my_id = multiplayer.get_unique_id()
	if id == my_id:
		# Update vị trí của chính mình nếu server yêu cầu
		if entity_container.has_node(str(id)):
			var me = entity_container.get_node(str(id))
			me.position = pos
		return

	# Spawn remote player
	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = pos
	
	player.set_multiplayer_authority(id)
	if player.has_node("MultiplayerSynchronizer"):
		player.get_node("MultiplayerSynchronizer").set_multiplayer_authority(1)
		
	entity_container.add_child(player)
	Bus.player_spawned.emit(str(id))

@rpc("authority", "call_remote", "reliable")
func despawn_player(id: int):
	print("[World] RPC despawn_player received: %d" % id)
	var my_id = multiplayer.get_unique_id()
	if id == my_id:
		return # Không bao giờ despawn chính mình theo lệnh này
		
	if entity_container.has_node(str(id)):
		entity_container.get_node(str(id)).queue_free()
		print("[World] Player despawned: %d" % id)

func _on_session_replaced(message: String):
	"""Handle session replacement - another device logged in"""
	print("[World] ⚠️ Session replaced: %s" % message)
	
	# Clear authentication state
	AuthState.on_session_replaced()
	
	# Disconnect from map server
	Net.disconnect_from_server()
	
	# Show notification dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Session Ended"
	dialog.dialog_text = message
	dialog.dialog_hide_on_ok = true
	add_child(dialog)
	dialog.popup_centered()
	
	# Return to login after dialog closed
	dialog.confirmed.connect(func():
		get_tree().change_scene_to_file("res://scenes/login/Login.tscn")
	)
	dialog.canceled.connect(func():
		get_tree().change_scene_to_file("res://scenes/login/Login.tscn")
	)
