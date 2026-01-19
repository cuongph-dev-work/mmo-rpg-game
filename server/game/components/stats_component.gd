class_name StatsComponent
extends Node

signal died
signal health_changed(current, max)
signal damaged(amount, attacker)

var max_hp: int = 100
var current_hp: int = 100
var atk: int = 10
var def: int = 0

func initialize(stats_data: Dictionary):
	max_hp = stats_data.get("hp", 100)
	current_hp = max_hp
	atk = stats_data.get("atk", 10)
	def = stats_data.get("def", 0)
	
	print("📊 Stats Init: HP %d/%d Atk %d Def %d" % [current_hp, max_hp, atk, def])

func take_damage(amount: int, attacker: Node = null):
	var damage = max(1, amount - def) # Minimum 1 damage
	current_hp -= damage
	health_changed.emit(current_hp, max_hp)
	damaged.emit(damage, attacker)
	
	if current_hp <= 0:
		current_hp = 0
		died.emit()

func heal(amount: int):
	current_hp = min(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)
