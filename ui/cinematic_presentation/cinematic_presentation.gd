extends Node3D

const SUPPORTED_CLIPS : Array[StringName] = [&"establish", &"corrupt", &"return", &"title"]

@export var config : BossPresentationConfig

@onready var cinematic_camera: Camera3D = $CinematicCamera
@onready var cutscene_overlay: CanvasLayer = $CutsceneOverlay

var _game_camera : Camera3D
var _focus : Vector3
var _room_camera : Transform3D
var _tween : Tween
var _run_id : int = - 1
var _index : int = -1
var _clip: StringName = &""
var _elapsed : float = 0.0
var _mirrored : bool = false

signal clip_finished(run_id: int, step_index: int)
signal corruption_changed(amount: float)
signal actor_cue(cue: StringName)

func _process(delta: float) -> void:
	if _run_id < 0:
		return
	_elapsed += delta
	if _clip == &"corrupt":
		corruption_changed.emit(clampf(_elapsed / config.durations[_clip], 0.0, 1.0))

func _exit_tree() -> void:
	cleanup()

func prepare(game_camera: Camera3D, focus: Vector3, room_camera: Transform3D) -> void:
	_game_camera = game_camera
	_focus = focus
	_room_camera = room_camera
	cinematic_camera.global_transform = game_camera.global_transform
	cinematic_camera.projection = game_camera.projection
	cinematic_camera.fov = game_camera.fov
	cinematic_camera.size = game_camera.size
	cinematic_camera.near = game_camera.near
	cinematic_camera.far = game_camera.far
	cinematic_camera.make_current()
	cutscene_overlay.set_active(true)

func has_clip(clip: StringName) -> bool:
	return SUPPORTED_CLIPS.has(clip) and is_instance_valid(config) and config.is_valid_clip(clip)

func play_clip(run_id: int, index: int, clip: StringName) -> bool:
	if not has_clip(clip):
		return false
	stop_clip()
	_run_id = run_id
	_index = index
	_clip = clip
	_elapsed = 0.0
	_mirrored = false
	var duration: float = config.durations[clip]
	var destination: Transform3D = cinematic_camera.global_transform
	match clip:
		&"establish":
			destination = _view_transform(_focus + config.overview_offset, _focus)
		&"corrupt":
			destination = _view_transform(_focus + config.close_offset, _focus)
		&"mirror":
			actor_cue.emit(&"mirror_player")
		&"return":
			destination = _room_camera
		&"title":
			cutscene_overlay.show_title()
	_tween = create_tween()
	_tween.tween_property(cinematic_camera, "global_transform", destination, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_on_clip_finished.bind(run_id, index), CONNECT_ONE_SHOT)
	return true
		
func stop_clip() -> void:
	_run_id = -1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func cleanup() -> void:
	stop_clip()
	if is_instance_valid(cutscene_overlay):
		cutscene_overlay.set_active(false)
	if is_instance_valid(_game_camera) and _game_camera.is_inside_tree():
		_game_camera.make_current()
	elif is_instance_valid(cinematic_camera) and cinematic_camera.is_inside_tree():
		cinematic_camera.clear_current(false)

func _view_transform(pos: Vector3, fouce: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pos).looking_at(fouce)

func _on_clip_finished(run_id: int, index: int) -> void:
	if run_id != _run_id or index != _index:
		return
	_run_id = -1
	if _clip == &"corrupt":
		corruption_changed.emit(1.0)
	clip_finished.emit(run_id, index)
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
