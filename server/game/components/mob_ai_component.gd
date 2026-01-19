class_name MobAIComponent
extends Node

# Dependencies
# Parent should be the Mob CharacterBody2D
@onready var mob = get_parent()

# AI Configs
var aggro_range: float = 200.0
var chase_range: float = 400.0
var leash_range: float = 500.0
var patrol_radius: float = 100.0
var patrol_speed: float = 50.0
var chase_speed: float = 100.0
var behavior: String = "hostile" # passive, neutral, hostile


# State
enum State {IDLE, PATROL, CHASE, FLEE, RETURN}
var current_state: State = State.IDLE
var spawn_pos: Vector2 = Vector2.ZERO
var target: Node2D = null
var idle_timer: float = 0.0
var patrol_target: Vector2 = Vector2.ZERO

# Flee state
var flee_target: Vector2 = Vector2.ZERO
var flee_duration: float = 0.0
var flee_timer: float = 0.0
var last_attacker: Node2D = null
var flee_safe_distance: float = 350.0
var flee_speed_multiplier: float = 1.3

var hate_table: Dictionary = {} # { Node2D: float (threat) }

func initialize(config: Dictionary, _spawn_pos: Vector2, _move_speed: float):
	spawn_pos = _spawn_pos
	chase_speed = _move_speed
	
	var ai_config = config.get("ai", {})
	aggro_range = ai_config.get("aggroRange", 200.0)
	chase_range = ai_config.get("chaseRange", 400.0)
	leash_range = ai_config.get("leashRange", 500.0)
	patrol_radius = ai_config.get("patrolRadius", 100.0)
	patrol_speed = ai_config.get("patrolSpeed", 50.0)
	behavior = ai_config.get("behavior", "hostile")
	flee_safe_distance = ai_config.get("fleeSafeDistance", 350.0)
	flee_speed_multiplier = ai_config.get("fleeSpeedMultiplier", 1.3)
	
	print("🧠 AI Init: Aggro %.0f Chase %.0f Behavior: %s" % [aggro_range, chase_range, behavior])

func on_damaged(amount: int, attacker: Node):
	if behavior == "passive":
		# Passive mobs flee when damaged
		if is_instance_valid(attacker) and attacker is Node2D:
			last_attacker = attacker
			flee_duration = randf_range(5.0, 10.0)
			flee_timer = 0.0
			current_state = State.FLEE
			_calculate_flee_target()
			print("😱 Mob fleeing from %s for %.1fs" % [attacker.name, flee_duration])
		return
		
	if (behavior == "neutral" or behavior == "hostile") and is_instance_valid(attacker) and attacker is Node2D:
		add_threat(attacker, float(amount))

func add_threat(entity: Node2D, amount: float):
	if not is_instance_valid(entity): return
	
	if not hate_table.has(entity):
		hate_table[entity] = 0.0
		
	hate_table[entity] += amount
	_update_target()

func _update_target():
	if hate_table.is_empty():
		target = null
		if current_state == State.CHASE:
			current_state = State.RETURN
		return

	var top_target = null
	var top_threat = -1.0
	
	# Prune invalid targets and find top threat
	var to_remove = []
	for entity in hate_table.keys():
		if not is_instance_valid(entity) or entity.get("channel_id") != mob.channel_id: # Also check channel
			to_remove.append(entity)
			continue
			
		var threat = hate_table[entity]
		if threat > top_threat:
			top_threat = threat
			top_target = entity
			
	for entity in to_remove:
		hate_table.erase(entity)
		
	if top_target:
		# Hysteresis: If we already have a target, switch only if new target has +10% threat
		if target and target != top_target and is_instance_valid(target) and hate_table.has(target):
			var current_threat = hate_table[target]
			if top_threat < current_threat * 1.1:
				return # Stick to current target
		
		target = top_target
		current_state = State.CHASE
		# print("🎯 Logic Target: %s (Threat: %.1f)" % [target.name, top_threat])

func physics_process(delta: float) -> Vector2:
	match current_state:
		State.IDLE:
			return _process_idle(delta)
		State.PATROL:
			return _process_patrol(delta)
		State.CHASE:
			return _process_chase(delta)
		State.FLEE:
			return _process_flee(delta)
		State.RETURN:
			return _process_return(delta)
	return Vector2.ZERO

func _process_idle(delta) -> Vector2:
	idle_timer -= delta
	if idle_timer <= 0:
		var random_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0, patrol_radius)
		patrol_target = spawn_pos + random_offset
		current_state = State.PATROL
	_check_for_aggro()
	return Vector2.ZERO

func _process_patrol(delta) -> Vector2:
	var dist = mob.position.distance_to(patrol_target)
	if dist < 10.0:
		current_state = State.IDLE
		idle_timer = randf_range(1.0, 3.0)
		return Vector2.ZERO
		
	_check_for_aggro()
	return mob.position.direction_to(patrol_target) * patrol_speed

func _process_chase(_delta) -> Vector2:
	if not is_instance_valid(target):
		current_state = State.RETURN
		return Vector2.ZERO
		
	if mob.position.distance_to(spawn_pos) > leash_range:
		target = null
		current_state = State.RETURN
		return Vector2.ZERO
		
	if mob.position.distance_to(target.position) > chase_range:
		target = null
		current_state = State.RETURN
		return Vector2.ZERO
		
	return mob.position.direction_to(target.position) * chase_speed

func _process_return(_delta) -> Vector2:
	var dist = mob.position.distance_to(spawn_pos)
	if dist < 10.0:
		current_state = State.IDLE
		idle_timer = 2.0
		hate_table.clear() # Reset aggro
		return Vector2.ZERO
		
	return mob.position.direction_to(spawn_pos) * chase_speed

func _process_flee(delta: float) -> Vector2:
	flee_timer += delta
	
	# Check if flee duration expired
	if flee_timer >= flee_duration:
		print("😌 Mob flee timeout, returning to spawn")
		current_state = State.RETURN
		last_attacker = null
		return Vector2.ZERO
	
	# Check if reached flee target
	if mob.position.distance_to(flee_target) < 20.0:
		# Find new flee target away from attacker
		_calculate_flee_target()
	
	# Check if far enough from attacker
	if is_instance_valid(last_attacker):
		var distance_to_attacker = mob.position.distance_to(last_attacker.position)
		if distance_to_attacker > flee_safe_distance:
			print("✅ Mob reached safe distance, returning to spawn")
			current_state = State.RETURN
			last_attacker = null
			return Vector2.ZERO
	
	return mob.position.direction_to(flee_target) * chase_speed * flee_speed_multiplier

func _calculate_flee_target():
	if not is_instance_valid(last_attacker):
		# No attacker, just flee towards spawn
		flee_target = spawn_pos
		return
	
	# Calculate direction away from attacker
	var away_direction = (mob.position - last_attacker.position).normalized()
	
	# Try to flee towards spawn if it's in the general "away" direction
	var to_spawn = (spawn_pos - mob.position).normalized()
	var dot_product = away_direction.dot(to_spawn)
	
	if dot_product > 0.3: # Spawn is somewhat away from attacker
		flee_target = spawn_pos
	else:
		# Flee in opposite direction, but stay within leash range
		var flee_distance = min(flee_safe_distance, leash_range * 0.8)
		flee_target = mob.position + away_direction * flee_distance

func _check_for_aggro():
	# Passive and Neutral mobs DO NOT aggro on sight
	if behavior == "passive" or behavior == "neutral":
		return
		
	var players = mob.get_tree().get_nodes_in_group("player")
	for player in players:
		if not is_instance_valid(player): continue
		
		# Channel Isolation Check
		if player.get("channel_id") != mob.channel_id:
			continue
			
		if mob.position.distance_to(player.position) < aggro_range:
			add_threat(player, 1.0) # Initial aggro
			return
