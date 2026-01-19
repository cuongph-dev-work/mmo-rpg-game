class_name CombatSystem
extends Node

## CombatSystem
## Centralizes combat logic, damage calculation and validation.
## Server Authoritative.

signal combat_log(message: String)

var entity_manager: EntityManager

func setup(p_entity_manager: EntityManager):
	entity_manager = p_entity_manager
	print("✅ CombatSystem initialized")

## Process an attack request
## Returns true if damage was applied
func process_attack(attacker_id: int, target_id: int, skill_id: String = "basic_attack") -> bool:
	# 1. Validation
	var attacker = entity_manager.get_entity_node(attacker_id)
	var target = entity_manager.get_entity_node(target_id)
	
	if not attacker or not target:
		return false
		
	# 2. Get Stats
	var att_stats = _get_stats(attacker)
	var tar_stats = _get_stats(target)
	
	if not att_stats or not tar_stats:
		return false
		
	if tar_stats.current_hp <= 0:
		return false # Already dead
		
	# 3. Calculate Damage
	# TODO: Use skill_id for multipliers
	var raw_damage = att_stats.atk
	
	# 4. Apply Damage
	# This emits signals on the component which other systems can listen to (e.g. LootSystem on death)
	tar_stats.take_damage(raw_damage, attacker)
	
	print("⚔️ %s dealt %d damage to %s" % [attacker.name, raw_damage, target.name])
	return true

func _get_stats(entity: Node) -> StatsComponent:
	if entity.has_node("StatsComponent"):
		return entity.get_node("StatsComponent")
	# Check children?
	for child in entity.get_children():
		if child is StatsComponent:
			return child
	return null
