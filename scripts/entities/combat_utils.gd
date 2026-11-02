extends RefCounted
class_name CombatUtils

## 兼容技能插件的实体查询；宿主显式登记自己的碰撞体。
static var _entities: Dictionary[int, WeakRef] = {}

static func register_entity(entity: Node, colliders: Array[Node]) -> void:
	for collider: Node in colliders:
		_entities[collider.get_instance_id()] = weakref(entity)

static func unregister_entity(entity: Node) -> void:
	for id: int in _entities.keys():
		if _entities[id].get_ref() == entity:
			_entities.erase(id)

static func get_entity_from_node(node: Node) -> Node:
	if not is_instance_valid(node):
		return null
	var reference: WeakRef = _entities.get(node.get_instance_id(), null)
	return reference.get_ref() as Node if reference != null else null

static func get_entity_from_collider(collider: Node) -> Node:
	return get_entity_from_node(collider)
