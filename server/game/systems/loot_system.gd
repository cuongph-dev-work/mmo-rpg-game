class_name LootSystem
extends Node

## LootSystem
## Handles loot generation and distribution.

signal loot_dropped(item_id: String, position: Vector2, owner_id: int)

func setup():
	print("✅ LootSystem initialized")

func drop_loot_for_mob(mob_type_id: String, position: Vector2, killer_id: int):
	# TODO: Read from loot table based on mob_type_id
	# For now, 50% chance to drop a potion
	if randf() < 0.5:
		spawn_item_drop("potion_hp", position, killer_id)

func spawn_item_drop(item_id: String, position: Vector2, owner_id: int):
	print("💎 Dropped %s at %s for player %d" % [item_id, position, owner_id])
	loot_dropped.emit(item_id, position, owner_id)
	
	# In a real implementation:
	# 1. Spawn a LootNode (Entity)
	# 2. Add to EntityManager
	# 3. ChannelManager syncs it to players
