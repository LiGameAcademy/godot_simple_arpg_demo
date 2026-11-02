extends Node
class_name CameraController

## 相机控制器组件
## 负责处理相机的屏幕震动、位置更新等逻辑
## 应该附加到 Camera3D 节点上

@export_group("References")
## 当前房间的相机标记（用于计算基础位置）
## 如果为空，将尝试自动查找
@export var current_room_marker: Marker3D = null

@export_group("Shake Settings")
## 是否启用屏幕震动
@export var enable_shake: bool = true

# 运行时数据
var _camera: Camera3D = null
var _shake_offset: Vector3 = Vector3.ZERO
var _base_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	# 获取相机节点（应该是父节点）
	_camera = get_viewport().get_camera_3d()
	if not is_instance_valid(_camera):
		push_error("CameraController: Parent node is not a Camera3D")
		return
	
	# 监听相机偏移更新事件
	AbilityEventBus.game_event_occurred.connect(_on_game_event_occurred)
	
	# 保存基础位置
	_base_position = _camera.global_position

func _process(_delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	
	# 更新相机位置（应用震动偏移）
	_update_camera_position()

## 设置基础位置（供外部调用，如房间切换时）
func set_base_position(position: Vector3) -> void:
	_base_position = position

## 设置当前房间标记（供外部调用）
func set_room_marker(marker: Marker3D) -> void:
	current_room_marker = marker

## 更新相机位置（应用屏幕震动偏移）
func _update_camera_position() -> void:
	if not is_instance_valid(_camera):
		return
	
	# 获取基础位置
	var base_pos = _get_base_position()
	if base_pos == Vector3.ZERO and _base_position != Vector3.ZERO:
		# 如果没有找到房间标记，使用保存的基础位置
		base_pos = _base_position
	
	# 应用震动偏移
	_camera.global_position = base_pos + _shake_offset

## 获取基础位置（从当前房间的相机标记）
func _get_base_position() -> Vector3:
	# 优先使用手动指定的标记
	if is_instance_valid(current_room_marker):
		return current_room_marker.global_position
	
	# 尝试自动查找当前房间
	var current_room = _find_current_room()
	if is_instance_valid(current_room) and is_instance_valid(current_room.camera_marker):
		return current_room.camera_marker.global_position
	
	return Vector3.ZERO

## 查找当前房间
func _find_current_room() -> DungeonRoom:
	# 尝试从场景树中查找玩家
	var player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player):
		return null
	
	# 获取玩家所在的房间（父节点）
	var parent = player.get_parent()
	if not is_instance_valid(parent):
		return null
	
	# 检查是否是 DungeonRoom
	if parent is DungeonRoom:
		return parent as DungeonRoom
	
	return null

## 处理游戏事件
func _on_game_event_occurred(event_type: StringName, context: Dictionary) -> void:
	if event_type == &"camera_offset_update":
		# 应用相机偏移（屏幕震动）
		if enable_shake:
			_shake_offset = context.get("offset", Vector3.ZERO)
		else:
			_shake_offset = Vector3.ZERO
