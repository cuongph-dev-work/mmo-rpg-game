class_name MobServer
extends CharacterBody2D

const MobData = preload("res://game/data/mob_data.gd")
const StatsComponentScript = preload("res://game/components/stats_component.gd")
const MobAIComponentScript = preload("res://game/components/mob_ai_component.gd")

# Components
var stats_comp: Node # Explicit type might fail if class not loaded, using Node or implicit
var ai_comp: Node

# Identity
var mob_type_id: String = ""
var is_elite: bool = false
var spawn_group_index: int = -1
var channel_id: int = 1 # Default to Channel 1

# Sync
var server_sync_position: Vector2 = Vector2.ZERO

signal died(mob_node)

func _ready():
	add_to_group("enemies")
	
	# Physics Optimization: Only collide with World (Layer 1)
	# Disables entity-entity collision (prevents cross-channel blocking)
	collision_mask = 1
	
	# Setup Sync Authority
	var sync_node = get_node_or_null("MultiplayerSynchronizer")
	if sync_node:
		sync_node.set_multiplayer_authority(1)
		
		# Network Optimization: Hide by default, reveal only to channel peers
		sync_node.public_visibility = false

func init(start_pos: Vector2, type_id: String, _elite: bool = false, group_idx: int = -1, _channel_id: int = 1):
	position = start_pos
	mob_type_id = type_id
	is_elite = _elite
	spawn_group_index = group_idx
	channel_id = _channel_id
	
	var template = MobData.get_template(type_id)
	if template.is_empty(): return
	
	# Prepare Stats Data (Apply Elite Multipliers here if needed before passing to component)
	var final_stats = template.duplicate()
	if is_elite:
		final_stats["hp"] = int(final_stats.get("hp", 100) * 2.0)
		final_stats["atk"] = int(final_stats.get("atk", 10) * 1.5)
		final_stats["scale"] = final_stats.get("scale", 1.0) * 1.5
		final_stats["moveSpeed"] = final_stats.get("moveSpeed", 100) * 1.2
		# AI buff handled inside component or pre-calc here
		if "ai" in final_stats:
			final_stats["ai"]["aggroRange"] = final_stats["ai"].get("aggroRange", 200.0) * 1.2
	
	# 1. Add Stats Component
	stats_comp = StatsComponentScript.new()
	stats_comp.name = "StatsComponent"
	add_child(stats_comp)
	stats_comp.initialize(final_stats)
	stats_comp.died.connect(_on_died)
	stats_comp.damaged.connect(_on_damaged)
	
	# 2. Add AI Component
	ai_comp = MobAIComponentScript.new()
	ai_comp.name = "MobAIComponent"
	# MobAI needs to be child of Mob to access position/tree
	add_child(ai_comp)
	var move_speed = final_stats.get("moveSpeed", 100.0)
	ai_comp.initialize(final_stats, start_pos, move_speed)
	
	print("✅ Mob %s (Elite: %s) Initialized with Components" % [type_id, is_elite])

func take_damage(amount: int, attacker: Node = null):
	# Delegate to component
	if stats_comp:
		stats_comp.take_damage(amount, attacker)

func _on_damaged(amount: int, attacker: Node):
	if ai_comp:
		ai_comp.on_damaged(amount, attacker)

func _on_died():
	print("💀 Mob %s died" % name)
	died.emit(self)
	queue_free()

func _physics_process(delta):
	# Delegate AI Logic
	if ai_comp:
		velocity = ai_comp.physics_process(delta)
		move_and_slide()
		server_sync_position = position
