extends Node3D

# 只需要定义变量，供 Action 读取
# 变量名必须和 Action 里查找的名字一致！
@export_group("Teleport Settings")
@export var target_room: DungeonRoom
@export var target_marker: Node3D
