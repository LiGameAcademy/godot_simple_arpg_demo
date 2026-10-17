extends Node

const Executor = preload("res://addons/laoli_dialogue_system/scenes/cutscene_player/cutscene_player.gd")
const Presentation = preload("res://ui/cinematic_presentation/cinematic_presentation.gd")

@export var definition : CutsceneDefinition

@onready var executor: Executor = $CutscenePlayer
@onready var presentation: Presentation = $CinematicPresentation

var _run_id : int = -1
var last_error: String = ""

signal finished(outcome: Executor.Outcome)
signal corruption_changed(amount: float)

func _ready() -> void:
	executor.step_requested.connect(_on_step)
	executor.finished.connect(_on_finished)
	presentation.clip_finished.connect(executor.complete_step)
	presentation.corruption_changed.connect(
		func(amount: float) -> void:
			corruption_changed.emit(amount)
	)

func start(camera: Camera3D, fouce: Vector3, room_view: Transform3D) -> bool:
	if _run_id >= 0 or not is_instance_valid(camera) or definition == null:
		return false
	last_error = definition.validata()
	if not last_error.is_empty():
		return false
	for step: CutsceneStep in definition.steps:
		if step.kind == CutsceneStep.StepKind.SHOW_DIALOGUE:
			last_error = "Dialogue support is added in this Lesson"
			return false
		if step.kind == CutsceneStep.StepKind.PLAY_CLIP and not presentation.has_clip(step.clip_id):
			last_error = "Unknown clip: " + String(step.clip_id)
			return false
	_run_id = executor.play(definition)
	if _run_id < 0:
		last_error = executor.last_error
		return false
	presentation.prepare(camera, fouce, room_view)
	return true

func is_playing() -> bool:
	return _run_id >= 0

func _on_step(run_id: int, index: int, step: CutsceneStep) -> void:
	if run_id == _run_id and step.kind == CutsceneStep.StepKind.PLAY_CLIP:
		if not presentation.play_clip(run_id, index, step.clip_id):
			executor.fail_step(run_id, index, "Unknown clip")

func _on_finished(run_id: int, _id: StringName, outcome: Executor.Outcome) -> void:
	if run_id != _run_id:
		return
	_run_id = -1
	presentation.cleanup()
	finished.emit(outcome)
