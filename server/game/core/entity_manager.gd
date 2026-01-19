class_name EntityManager
extends Node

var entity_container: Node
var world_root: Node

func setup(p_world_root: Node):
	world_root = p_world_root
	if world_root and world_root.has_node("EntityContainer"):
		entity_container = world_root.get_node("EntityContainer")
	else:
		push_error("❌ EntityManager: World root invalid or missing EntityContainer")

func get_entity_node(entity_id: int) -> Node:
	if not entity_container: return null
	return entity_container.get_node_or_null(str(entity_id))

func has_entity(entity_id: int) -> bool:
	return get_entity_node(entity_id) != null

func get_all_entities() -> Array[Node]:
	if not entity_container: return []
	return entity_container.get_children()

func add_entity(node: Node):
	if entity_container:
		entity_container.add_child(node)

func remove_entity(entity_id: int):
	var node = get_entity_node(entity_id)
	if node:
		node.queue_free()
