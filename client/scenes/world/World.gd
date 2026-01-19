extends Node2D

## World Scene
## Main game world container

@onready var entity_container: Node2D = $EntityContainer

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
	
	# Start connection *after* world is loaded
	print("[World] Connecting to server...")
	Net.connect_to_server()
	
	# UI Setup
	var channel_selector = $UI/ChannelSelector
	if channel_selector:
		channel_selector.item_selected.connect(_on_channel_selected)

func _on_channel_selected(index: int):
	# index is 0-based, IDs are 1-based (set in tscn)
	var channel_id = index + 1
	print("[UI] Requesting switch to Channel %d" % channel_id)
	
	# Call Server RPC
	# We need to call this on the MapServer.
	# MapServer logic is handled differently - usually we call RPC on the node that has the RPC method.
	# The RPC is in MapServer.gd, but on client where is the corresponding node?
	# In our setup, MapServer logic is likely authoritative and accessed via valid RPC paths.
	# However, our client doesn't have a MapServer node.
	# We added `request_channel_change` to `MapServer.gd` which is `/root/MapServer`.
	# But wait, our current RPC setup relies on `World` node for common stuff.
	# `request_channel_change` is in `MapServer.gd`, NOT `World.gd` on server.
	# The client needs a node path that matches `/root/MapServer` to call it?
	# Or we should put the RPC stub in `World.gd` (Server) and delegate?
	# Actually, better to move `request_channel_change` to `World.gd` (Server) or ensure Client can call it.
	# For simplified MVP, let's put the RPC call to proper path.
	# BUT we don't have MapServer node stub on client.
	# SOLUTION: Move `request_channel_change` to `Server/Scenes/World/World.gd` or call via `/root/World` if we mapped it.
	# Wait, `MapServer` script is the root `/root/MapServer` on server. Client has no such node.
	# We MUST use `World.gd` on Server as the gateway for Client RPCs.
	
	# Let's call it via the World node derived from `Net` or just `rpc("request_channel_change", ...)` if we implement it in THIS file?
	# If we add `request_channel_change` to CLIENT World.gd as an RPC, we can call it? No, that sends to self or server if configured.
	# Correct way: Add `request_channel_change` STUB to Client World.gd calling `rpc_id(1, ...)`,
	# AND Add `request_channel_change` to SERVER World.gd which then calls MapServer.
	
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
