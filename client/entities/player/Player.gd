extends BaseEntity

## Player Controller
## Handles player input, movement, and server synchronization

var input_vector: Vector2 = Vector2.ZERO
var input_sequence: int = 0
var last_input_vector: Vector2 = Vector2.ZERO

func _ready():
	super._ready()
	# Load speed from config (override base speed if needed)
	if speed == 0.0:
		speed = 200.0 # Default speed
	
	
	entity_type = "player"
	print("[Player] Player controller initialized")

func _physics_process(delta):
	if is_multiplayer_authority(): # Kiểm tra nếu bạn là người điều khiển, trả về false nếu là player khác (do server điều khiển)
		# --- Local Player: Prediction ---
		# 1. Capture and Send Input
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		
		# Send input every frame (Continuous Stream)
		input_sequence += 1
		rpc_id(1, "receive_input", input_vector, input_sequence)
		
		# 2. Predicted Movement (Instant)
		if input_vector != Vector2.ZERO:
			velocity = input_vector.normalized() * speed
			move_and_slide()
		
		# 3. Update GameState with current position
		PlayerState.update_position(position)
		
		# 4. Reconciliation (Check against Server Truth)
		var dist_sq = position.distance_squared_to(server_sync_position)
		if dist_sq > 2500: # > 50px error: Hard Snap (Teleport)
			position = server_sync_position
		elif dist_sq > 100: # > 10px error: Smooth Correction
			position = position.lerp(server_sync_position, 0.2)
			
	else:
		# --- Other Players: Interpolation ---
		# Smoothly move visual position towards the synced server position
		# Tuned for 30Hz Server Tickrate (delta * 10 is smoother than 15)
		position = position.lerp(server_sync_position, delta * 10)

@rpc("any_peer")
func receive_input(_input: Vector2, _seq: int):
	# Stub for RPC configuration
	pass
