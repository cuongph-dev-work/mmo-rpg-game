extends Node2D

# Server-side World Script
# Used primarily to align RPC paths with extends Node2D

var map_server: Node = null

@rpc("authority", "call_remote", "reliable")
func spawn_mob(id: int, pos: Vector2, type_id: String, is_elite: bool):
	pass

@rpc("authority", "call_remote", "reliable")
func despawn_mob(id: int):
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_channel_change(target_channel_id: int):
	var player_id = multiplayer.get_remote_sender_id()
	
	if map_server:
		map_server.change_player_channel(player_id, target_channel_id)
	else:
		push_error("MapServer reference not set in World!")