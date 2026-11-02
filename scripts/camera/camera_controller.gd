extends Node
class_name CameraController
## Applies camera shake to the explicit room camera supplied by the level.
@export var current_room_marker: Marker3D
@export var enable_shake: bool = true
var _camera: Camera3D
var _base_position: Vector3 = Vector3.ZERO
var _shake_offset: Vector3 = Vector3.ZERO
func _ready() -> void:
	AbilityEventBus.game_event_occurred.connect(_on_game_event_occurred)
func initialize(camera: Camera3D, marker: Marker3D) -> void:
	_camera = camera
	set_room_marker(marker)
func _process(_delta: float) -> void:
	if is_instance_valid(_camera):
		var origin: Vector3 = current_room_marker.global_position if is_instance_valid(current_room_marker) else _base_position
		_camera.global_position = origin + _shake_offset
func set_base_position(position: Vector3) -> void:
	_base_position = position
func set_room_marker(marker: Marker3D) -> void:
	current_room_marker = marker
	if is_instance_valid(marker):
		_base_position = marker.global_position
func _on_game_event_occurred(event_type: StringName, context: Dictionary) -> void:
	if event_type == &"camera_offset_update":
		_shake_offset = context.get("offset", Vector3.ZERO) if enable_shake else Vector3.ZERO
