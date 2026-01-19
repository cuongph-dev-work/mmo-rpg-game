extends BaseEntity

func _ready():
	super._ready()
	entity_type = "mob"

func init(type_id: String, is_elite: bool):
	# Simple visual logic for MVP
	if type_id == "wolf":
		$Sprite2D.modulate = Color.GRAY
	elif type_id == "slime":
		$Sprite2D.modulate = Color.GREEN
		
	if is_elite:
		scale = Vector2(1.5, 1.5)
		$Sprite2D.modulate = $Sprite2D.modulate.lightened(0.5) # Brighter
		print("Mob %s is Elite!" % name)

func _physics_process(delta):
	# Interpolation logic (same as other players)
	# BaseEntity has server_sync_position
	# Tuned for 30Hz Server Tickrate (delta * 10 is smoother)
	position = position.lerp(server_sync_position, delta * 10)
