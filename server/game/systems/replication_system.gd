class_name ReplicationSystem
extends Node

## ReplicationSystem
## Manages network replication rates and snapshot decoupling.
## Allows running game logic at 60Hz while networking runs at 20Hz or variable rates.

var entity_manager: EntityManager
var target_network_rate_hz: int = 30

func setup(p_entity_manager: EntityManager, p_rate_hz: int = 30):
	entity_manager = p_entity_manager
	target_network_rate_hz = p_rate_hz
	print("✅ ReplicationSystem initialized at %d Hz" % target_network_rate_hz)

func apply_replication_settings_to_new_entity(entity: Node):
	"""
	Called when a new entity is spawned to apply default replication settings.
	"""
	if entity.has_node("MultiplayerSynchronizer"):
		var sync = entity.get_node("MultiplayerSynchronizer")
		
		# Set replication interval (throttling)
		# Note: This property exists in Godot 4.2+. If using older version, might need check.
		if "replication_interval" in sync:
			sync.replication_interval = 1.0 / float(target_network_rate_hz)
			
		# Future: Set replication config based on entity type (Player vs Mob)

func update_lod(player_node: Node):
	"""
	Future: Update Level of Detail for replication based on distance to this player.
	"""
	pass
