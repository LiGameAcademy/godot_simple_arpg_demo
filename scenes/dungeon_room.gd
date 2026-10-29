extends Node3D
class_name DungeonRoom

## 摄像机在这个房间应该停在这个位置
@export var camera_marker: Marker3D
# 引用存放怪物的父节点
# 在编辑器里把那个 "Enemies" 节点拖进来赋值
@export var enemies_container: Node3D
@export var exit_trigger: Area3D

signal room_exit_requested(body: CharacterBody3D)

func _ready() -> void:
	if is_instance_valid(exit_trigger):
		exit_trigger.passage_requested.connect(_on_exit_requested)

# --- 房间生命周期 ---
# 这个函数由 Main.gd (LevelManager) 在传送结束、屏幕亮起前调用
func on_player_enter() -> void:
	print("玩家进入房间：", name)
	
	# 唤醒所有怪物
	if is_instance_valid(enemies_container):
		_awaken_all_enemies()

func _awaken_all_enemies() -> void:
	# 遍历 Enemies 节点下的所有孩子
	for enemy in enemies_container.get_children():
		# 检查孩子是否有 awaken 方法 (防止你把非怪物的节点放进去了)
		if enemy.has_method("awaken"):
			enemy.awaken()

func _on_exit_requested(body: CharacterBody3D) -> void:
	room_exit_requested.emit(body)
