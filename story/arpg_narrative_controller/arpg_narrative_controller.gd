extends Node3D
const Definition = preload("res://addons/laoli_dialogue_system/scripts/core/cutscene/cutscene_definition.gd")
const Step = preload("res://addons/laoli_dialogue_system/scripts/core/cutscene/cutscene_step.gd")
const Executor = preload("res://addons/laoli_dialogue_system/scenes/cutscene_player/cutscene_player.gd")
const Presentation = preload("res://story/cinematic_presentation/cinematic_presentation.gd")
signal finished(outcome: Executor.Outcome)
signal corruption_changed(amount: float)
signal actor_cue(cue: StringName)
@export var definition: Definition
@onready var executor: Executor = $CutscenePlayer
@onready var presentation: Presentation = $CinematicPresentation
var _run_id: int = -1
var _session_id: int = -1
var _step_index: int = -1
var last_error: String = ""
var _targets: Array[Node] = []

func _ready() -> void:
	executor.step_requested.connect(_on_step)
	executor.finished.connect(_on_finished)
	executor.failed.connect(_on_failure)
	presentation.clip_finished.connect(_on_clip_finished)
	presentation.corruption_changed.connect(func(amount: float) -> void: corruption_changed.emit(amount))
	presentation.actor_cue.connect(func(cue: StringName) -> void: actor_cue.emit(cue))
	presentation.overlay.skip_requested.connect(skip)
	DialogueManager.dialogue_session_finished.connect(_on_dialogue_finished)

## required_targets 由宿主显式传入；插件执行器不寻找角色或关卡。
func start(game_camera: Camera3D, focus: Vector3, room_camera: Transform3D, sequence: Definition = null, required_targets: Array[Node] = []) -> bool:
	var selected: Definition = sequence if sequence != null else definition
	last_error = ""
	if not is_node_ready() or not is_inside_tree() or is_queued_for_deletion():
		last_error = "演出控制器未就绪"
		return false
	if _run_id >= 0 or DialogueManager.is_dialogue_active():
		last_error = "演出或对话服务忙碌"
		return false
	if not is_instance_valid(game_camera) or not game_camera.is_inside_tree():
		last_error = "游戏相机不可用"
		return false
	if selected == null:
		last_error = "演出资源为空"
		return false
	last_error = selected.validate()
	if not last_error.is_empty():
		return false
	if presentation.config == null:
		last_error = "表现配置为空"
		return false
	for target: Node in required_targets:
		if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
			last_error = "演出对象不可用"
			return false
	for step: Step in selected.steps:
		if step.kind == Step.StepKind.PLAY_CLIP and not presentation.has_clip(step.clip_id):
			last_error = "片段不存在或时长无效：" + String(step.clip_id)
			return false
		if step.kind == Step.StepKind.SHOW_DIALOGUE and not _valid_dialogue(step.dialogue_id):
			last_error = "对话链无效：" + step.dialogue_id
			return false
	_run_id = executor.play(selected)
	if _run_id < 0:
		last_error = executor.last_error
		return false
	_targets = required_targets.duplicate()
	_targets.append(presentation)
	_targets.append(presentation.camera)
	_targets.append(presentation.overlay)
	if not _targets.has(game_camera):
		_targets.append(game_camera)
	for target: Node in _targets:
		if not target.tree_exiting.is_connected(_on_target_exiting):
			target.tree_exiting.connect(_on_target_exiting)
	presentation.prepare(game_camera, focus, room_camera)
	presentation.overlay.set_skippable(selected.skippable)
	return true

func is_playing() -> bool:
	return _run_id >= 0

func skip() -> void:
	if _run_id >= 0:
		executor.skip(_run_id)

func cancel(reason: String) -> void:
	if _run_id >= 0:
		executor.cancel(_run_id, reason)

func _on_step(run_id: int, index: int, step: Step) -> void:
	if run_id != _run_id:
		return
	_step_index = index
	match step.kind:
		Step.StepKind.PLAY_CLIP:
			if not presentation.play_clip(run_id, index, step.clip_id):
				executor.fail_step(run_id, index, "片段不存在")
		Step.StepKind.SHOW_DIALOGUE:
			_session_id = DialogueManager.start_dialogue_session(step.dialogue_id)
			if _session_id < 0:
				executor.fail_step(run_id, index, "对话被占用")

func _on_clip_finished(run_id: int, index: int) -> void:
	executor.complete_step(run_id, index)

func _on_dialogue_finished(session_id: int, reason: int) -> void:
	if session_id != _session_id or _run_id < 0:
		return
	_session_id = -1
	if reason == DialogueManager.DialogueEndReason.COMPLETED:
		executor.complete_step(_run_id, _step_index)
	else:
		executor.fail_step(_run_id, _step_index, "演出对话被中断")

func _on_finished(run_id: int, _id: StringName, outcome: Executor.Outcome) -> void:
	if run_id != _run_id:
		return
	_run_id = -1
	var session: int = _session_id
	_session_id = -1
	for target: Node in _targets:
		if is_instance_valid(target) and target.tree_exiting.is_connected(_on_target_exiting):
			target.tree_exiting.disconnect(_on_target_exiting)
	_targets.clear()
	if is_instance_valid(presentation):
		presentation.cleanup()
	if session >= 0:
		DialogueManager.cancel_dialogue_session(session)
	finished.emit(outcome)

func _valid_dialogue(node_id: String) -> bool:
	var visited: Array[String] = []
	while node_id != "END":
		if visited.has(node_id) or not DialogueManager.dialogue_graph.has(node_id):
			return false
		visited.append(node_id)
		var node: DialogueNode = DialogueManager.dialogue_graph[node_id]
		if node == null or node.has_choices() or not node.actions.is_empty() or node.next_node_id.is_empty():
			return false
		node_id = node.next_node_id
	return true

func _on_failure(_run: int, index: int, message: String) -> void:
	last_error = "步骤 %d：%s" % [index, message]
	if is_instance_valid(presentation) and is_instance_valid(presentation.overlay):
		presentation.overlay.show_combat_status("演出失败：" + last_error)

func _on_target_exiting() -> void:
	if _run_id >= 0:
		executor.abort(_run_id, "演出对象退出场景树")

func _exit_tree() -> void:
	cancel("场景退出")
