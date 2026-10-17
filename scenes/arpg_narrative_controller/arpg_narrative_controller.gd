extends Node

const Executor = preload("res://addons/laoli_dialogue_system/scenes/cutscene_player/cutscene_player.gd")
const Presentation = preload("res://ui/cinematic_presentation/cinematic_presentation.gd")

@export var definition : CutsceneDefinition

@onready var executor: Executor = $CutscenePlayer
@onready var presentation: Presentation = $CinematicPresentation

var _run_id : int = -1
var _session_id: int = -1
var _step_index: int = -1
var last_error: String = ""

signal finished(outcome: Executor.Outcome)
signal corruption_changed(amount: float)

func _ready() -> void:
	DialogueManager.dialogue_session_finished.connect(_on_dialogue_finished)
	executor.step_requested.connect(_on_step)
	executor.finished.connect(_on_finished)
	presentation.clip_finished.connect(executor.complete_step)
	presentation.corruption_changed.connect(
		func(amount: float) -> void:
			corruption_changed.emit(amount)
	)

func start(camera: Camera3D, fouce: Vector3, room_view: Transform3D) -> bool:
	if _run_id >= 0 or not is_instance_valid(camera) or definition == null\
		or DialogueManager.is_dialogue_active():
		return false
	last_error = definition.validata()
	if not last_error.is_empty():
		return false
	for step: CutsceneStep in definition.steps:
		if step.kind == CutsceneStep.StepKind.SHOW_DIALOGUE and not DialogueManager.dialogue_graph\
			.has(step.dialogue_id):
			last_error = "Missing dialogue"
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
	if run_id != _run_id:
		return
	_step_index = index
	match step.kind:
		CutsceneStep.StepKind.PLAY_CLIP:
			if not presentation.play_clip(run_id, index, step.clip_id):
				executor.fail_step(run_id, index, "Unknown clip")
		CutsceneStep.StepKind.SHOW_DIALOGUE:
			_session_id = DialogueManager.start_dialogue_session(step.dialogue_id)
			if _session_id < 0:
				executor.fail_step(run_id, index, "Dialogue busy")

func _on_finished(run_id: int, _id: StringName, outcome: Executor.Outcome) -> void:
	if run_id != _run_id:
		return
	_run_id = -1
	var session: int = _session_id
	_session_id = -1
	if session >= 0:
		DialogueManager.cancel_dialogue_session(session)
	presentation.cleanup()
	finished.emit(outcome)

func _on_dialogue_finished(session_id: int, reason: int) -> void:
	if session_id != _session_id or _run_id < 0:
		return
	_session_id = -1
	if reason == DialogueManager.DialogueEndReason.COMPLETED:
		executor.complete_step(_run_id, _step_index)
	else:
		executor.fail_step(_run_id, _step_index, "Dialogue interrupted")
