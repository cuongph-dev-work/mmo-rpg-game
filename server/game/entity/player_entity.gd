class_name PlayerEntity
extends CharacterBody2D

var speed = 200.0
var channel_id: int = 1
# velocity is built-in for CharacterBody2D
var input_vector = Vector2.ZERO
var server_sync_position: Vector2 = Vector2.ZERO

func _ready():
	add_to_group("players") # Add to group for Gate detection
	print("Player Entity Ready: %s (Path: %s)" % [name, get_path()])
	
	# Physics Optimization: Only collide with World (Layer 1)
	collision_mask = 1
	
	_setup_sync()

func _setup_sync():
	# Configure MultiplayerSynchronizer explicitly if needed
	var sync_node = get_node_or_null("MultiplayerSynchronizer")
	if sync_node:
		sync_node.set_multiplayer_authority(1) # Server is authority for Sync

var input_buffer: Array = [] # Array of { input: Vector2, seq: int }
var last_processed_seq: int = 0

func _physics_process(_delta):
	# PROCESS: Consume input buffer
	if input_buffer.size() > 0:
		# Sort buffer by sequence (handling out-of-order packets)
		input_buffer.sort_custom(func(a, b): return a.seq < b.seq)
		
		for data in input_buffer:
			if data.seq <= last_processed_seq:
				continue # Skip old/duplicate packets
			
			var input = data.input
			# Apply movement for this input step
			if input != Vector2.ZERO:
				velocity = input.normalized() * speed
				move_and_slide()
				print("Player %s moved to: %s" % [name, position])
			else:
				velocity = Vector2.ZERO
			
			last_processed_seq = data.seq
		
		# Clear buffer after processing
		input_buffer.clear()

	
	# Update sync variable for clients to interpolate/reconcile towards
	server_sync_position = position
	if input_buffer.size() > 0:
		print("Player %s pos: %s" % [name, position])


@rpc("any_peer")
func receive_input(input: Vector2, seq: int):
	# INBOUND: Buffer input instead of immediate processing
	# Validate input
	if input.length_squared() > 1.1:
		input = input.normalized()
	
	input_buffer.append({
		"input": input,
		"seq": seq
	})
	
	# Update Authority if not set correctly (Safety Fallback)
	# The sender of this RPC is the player client
	var sender_id = multiplayer.get_remote_sender_id()
	if name != str(sender_id):
		# Just a warning, might happen if ID logic is off
		pass
