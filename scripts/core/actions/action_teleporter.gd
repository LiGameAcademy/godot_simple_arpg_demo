extends GameAction
class_name ActionTeleport

func init_from_data(_data: Dictionary) -> void:
	pass

func _execute_internal(initiator: Node, target: Node) -> bool:
	# 1. 获取宿主 (Owner)
	# target 是 InteractionComponent，它的父节点通常就是 Teleporter
	var owner_node = target.get_parent()
	
	# 2. 【核心】反射式获取数据 (Duck Typing)
	# 我们不关心 owner_node 是什么类型，只要它有我们需要的数据就行
	var room = owner_node.get("target_room")
	var marker = owner_node.get("target_marker")
	
	# 3. 安全检查
	if not room or not marker:
		printerr("ActionTeleport: 宿主节点 [", owner_node.name, "] 缺少 target_room 或 target_marker 属性！")
		return false
	
	# 4. 执行逻辑
	var main = initiator.get_tree().current_scene
	if main.has_method("transition_to_room"):
		print("传送 -> ", room.name)
		main.transition_to_room(room, marker.global_position)
		return true

	return false
