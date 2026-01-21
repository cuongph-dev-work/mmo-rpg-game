extends Node2D

# Server-side World Script
# Used primarily to align RPC paths with extends Node2D

var game_server: Node = null

@rpc("authority", "call_remote", "reliable")
func spawn_mob(id: int, pos: Vector2, type_id: String, is_elite: bool):
	pass

@rpc("authority", "call_remote", "reliable")
func despawn_mob(id: int):
	pass

@rpc("authority", "call_remote", "reliable")
func spawn_player(id: int, pos: Vector2):
	pass

@rpc("authority", "call_remote", "reliable")
func despawn_player(id: int):
	pass

# Gate System RPCs
@rpc("authority", "call_remote", "reliable")
func on_map_transfer_requested(target_map_id: int, target_spawn_pos: Array):
	pass

@rpc("authority", "call_remote", "reliable")
func on_dynamic_gate_spawned(pos: Array, duration_seconds: float):
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_channel_change(target_channel_id: int):
	var player_id = multiplayer.get_remote_sender_id()
	
	if game_server:
		game_server.change_player_channel(player_id, target_channel_id)
	else:
		push_error("GameServer reference not set in World!")