extends Area3D

# 目标是哪个房间节点？直接拖拽赋值！
@export var target_room: DungeonRoom
@export var target : Node3D

# 交互接口 (由 Player 脚本调用)
func interact() -> void:
	print("传送开始...")
	if not target_room: return
	
	# 找到主场景，呼叫运镜系统
	var main = get_tree().current_scene
	if main.has_method("transition_to_room"):
		main.transition_to_room(target_room, target.global_position)
