extends Node

const Executor = preload("res://addons/laoli_dialogue_system/scenes/cutscene_player/cutscene_player.gd")
const Presentation = preload("res://ui/cinematic_presentation/cinematic_presentation.gd")

@export var definition : CutsceneDefinition

@onready var executor: Executor = $CutscenePlayer
@onready var presentation: Presentation = $CinematicPresentation

var _run_id : int = -1
var _session_id: int = -1
var _step_index: int = -1
var _targets: Array[Node] = []
var last_error: String = ""

signal finished(outcome: Executor.Outcome)
signal corruption_changed(amount: float)
signal actor_cue(cue: StringName)

func _ready() -> void:
	DialogueManager.dialogue_session_finished.connect(_on_dialogue_finished)
	executor.step_requested.connect(_on_step)
	executor.finished.connect(_on_finished)
	executor.failed.connect(_on_failure)
	presentation.clip_finished.connect(_on_clip_finished)
	presentation.corruption_changed.connect(
		func(amount: float) -> void:
			corruption_changed.emit(amount)
	)
	presentation.actor_cue.connect(func(cue: StringName) -> void: actor_cue.emit(cue))
	presentation.cutscene_overlay.skip_requested.connect(func() -> void: skip())

func _exit_tree() -> void:
	cancel("场景退出")

func start(camera: Camera3D, fouce: Vector3, room_view: Transform3D,\
		sequence: CutsceneDefinition = null, required_targets: Array[Node] = []) -> bool:
	var selected: CutsceneDefinition = sequence if sequence != null else definition
	last_error = ""
	if not is_node_ready() or not is_inside_tree() or is_queued_for_deletion():
		last_error = "演出控制器未就绪"
		return false
	if _run_id > 0 or DialogueManager.is_dialogue_active():
		last_error = "演出或对话服务忙碌"
		return false
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		last_error = "摄像机不可用"
		return false
	if selected == null:
		last_error = "演出资源为空"
		return false
	last_error = selected.validata()
	if not last_error.is_empty():
		return false
	if presentation.config == null:
		last_error = "表现配置为空"
		return false
	for target: Node in required_targets:
		if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
			last_error = "演出对象不可用"
			return false
	for step: CutsceneStep in definition.steps:
		if step.kind == CutsceneStep.StepKind.SHOW_DIALOGUE and not _valid_dialogue(step.dialogue_id):
			last_error = "Missing dialogue: " + step.dialogue_id
			return false
		if step.kind == CutsceneStep.StepKind.PLAY_CLIP and not presentation.has_clip(step.clip_id):
			last_error = "Unknown clip: " + String(step.clip_id)
			return false
	_run_id = executor.play(definition)
	if _run_id < 0:
		last_error = executor.last_error
		return false
	_targets = required_targets.duplicate()
	_targets.append(presentation)
	_targets.append(presentation.cinematic_camera)
	_targets.append(presentation.cutscene_overlay)
	if not _targets.has(camera):
		_targets.append(camera)
	for target: Node in _targets:
		if not target.tree_exited.is_connected(_on_target_exiting):
			target.tree_exited.connect(_on_target_exiting)
	presentation.prepare(camera, fouce, room_view)
	presentation.cutscene_overlay.set_skippable(selected.skippable)
	return true

func is_playing() -> bool:
	return _run_id >= 0

func skip() -> void:
	if _run_id >= 0:
		executor.skip(_run_id)

func cancel(reason: String) -> void:
	if _run_id >= 0:
		executor.cancel(_run_id, reason)

func _valid_dialogue(dialogue_id: String) -> bool:
	var visited: Array[String] = []
	while dialogue_id != "END":
		if visited.has(dialogue_id) or not DialogueManager.dialogue_graph.has(dialogue_id):
			return false
		visited.append(dialogue_id)
		var node: DialogueNode = DialogueManager.dialogue_graph[dialogue_id]
		if node == null or node.has_choices() or not node.actions.is_empty() or node.next_node_id.is_empty():
			return false
		dialogue_id = node.next_node_id
	return true

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

func _on_clip_finished(run_id: int, index: int) -> void:
	executor.complete_step(run_id, index)

func _on_finished(run_id: int, _id: StringName, outcome: Executor.Outcome) -> void:
	if run_id != _run_id:
		return
	_run_id = -1
	var session: int = _session_id
	_session_id = -1
	for target: Node in _targets:
		if is_instance_valid(target) and target.tree_exited.is_connected(_on_target_exiting):
			target.tree_exited.disconnect(_on_target_exiting)
	_targets.clear()
	if is_instance_valid(presentation):
		presentation.cleanup()
	if session >= 0:
		DialogueManager.cancel_dialogue_session(session)
	finished.emit(outcome)

func _on_dialogue_finished(session_id: int, reason: int) -> void:
	if session_id != _session_id or _run_id < 0:
		return
	_session_id = -1
	if reason == DialogueManager.DialogueEndReason.COMPLETED:
		executor.complete_step(_run_id, _step_index)
	else:
		executor.fail_step(_run_id, _step_index, "Dialogue interrupted")

func _on_failure(_run: int, index: int, message: String) -> void:
	last_error = "步骤 %d ： %s" %[index, message]
	if is_instance_valid(presentation) and is_instance_valid(presentation.cutscene_overlay):
		presentation.cutscene_overlay.show_combat_status("演出失败： " + last_error)

func _on_target_exiting() -> void:
	if _run_id >=0:
		executor.abort(_run_id, "演出对象退出场景树")

	
	
	
	
	
	
	
	
