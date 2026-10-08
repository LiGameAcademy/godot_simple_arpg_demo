extends Node
const Executor = preload("res://addons/laoli_dialogue_system/scenes/cutscene_player/cutscene_player.gd")
const Definition = preload("res://addons/laoli_dialogue_system/scripts/core/cutscene/cutscene_definition.gd")
const Step = preload("res://addons/laoli_dialogue_system/scripts/core/cutscene/cutscene_step.gd")
var _executor: Executor
var _results: Array[int] = []
var _requested_run: int = -1
var _requested_index: int = -1
var _old_started: int = 0
var _requested_clip: StringName

func _ready() -> void:
	_executor = Executor.new()
	add_child(_executor)
	_executor.step_requested.connect(_on_step)
	_executor.finished.connect(_on_finished)
	call_deferred("_run")

func _run() -> void:
	var definition: Definition = Definition.new()
	definition.cutscene_id = &"contract_test"
	var clip: Step = Step.new()
	clip.clip_id = &"test_clip"
	clip.timeout_seconds = 0.1
	definition.steps.append(clip)
	var first: int = _executor.play(definition)
	assert(_executor.play(definition) == -1, "Busy executor accepted another play")
	await _wait_request(first)
	_executor.complete_step(first, 0)
	_executor.complete_step(first, 0)
	await _wait_idle()
	assert(_results == [Executor.Outcome.COMPLETED], "Duplicate completion terminated twice")
	var second: int = _executor.play(definition)
	await _wait_request(second)
	_executor.complete_step(first, 0)
	assert(_executor.is_playing(), "Old run advanced a new run")
	_executor.skip(second)
	_executor.cancel(second, "late cancellation")
	assert(_results.size() == 2 and _results.back() == Executor.Outcome.SKIPPED)
	var third: int = _executor.play(definition)
	await _wait_request(third)
	await _wait_idle()
	assert(_results.back() == Executor.Outcome.FAILED, "Clip timeout was treated as success")
	var waiting: Step = Step.new()
	waiting.kind = Step.StepKind.WAIT
	waiting.duration_seconds = 100.0
	definition.steps = [waiting]
	var fourth: int = _executor.play(definition)
	await get_tree().process_frame
	_executor.cancel(fourth, "cancel waiting")
	assert(_results.back() == Executor.Outcome.CANCELED)
	assert(waiting.duration_seconds == 100.0, "Executor modified its shared definition")
	var line: DialogueNode = DialogueNode.new()
	line.node_id = "session_contract"
	line.text_key = "test"
	line.next_node_id = "END"
	DialogueManager.dialogue_graph[line.node_id] = line
	var session: int = DialogueManager.start_dialogue_session(line.node_id)
	assert(DialogueManager.start_dialogue_session(line.node_id) == -1)
	DialogueManager.cancel_dialogue_session(session)
	await get_tree().process_frame
	assert(not DialogueManager.is_active)
	DialogueManager.dialogue_started.connect(_on_old_started)
	DialogueManager.dialogue_session_started.connect(_cancel_on_start)
	DialogueManager.start_dialogue_session(line.node_id)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not DialogueManager.is_active and _old_started == 0, "Canceled reservation emitted a late start")
	var immutable: Definition = Definition.new()
	immutable.cutscene_id = &"snapshot"
	var snapshot_clip: Step = Step.new()
	snapshot_clip.clip_id = &"original"
	immutable.steps = [snapshot_clip]
	var snapshot_run: int = _executor.play(immutable)
	snapshot_clip.clip_id = &"changed"
	immutable.steps.clear()
	await _wait_request(snapshot_run)
	assert(_requested_clip == &"original", "External config mutation altered running steps")
	_executor.cancel(snapshot_run, "snapshot test")
	var exiting_run: int = _executor.play(definition)
	_executor.queue_free()
	await get_tree().process_frame
	assert(_results.back() == Executor.Outcome.CANCELED and exiting_run > 0)
	print("PASS: config snapshot and executor exit cancellation")
	print("PASS: duplicate/stale callbacks, busy/timeout/WAIT cancellation, immutable configuration, session reservation and reentrant cancellation")
	get_tree().quit()

func _wait_request(run_id: int) -> void:
	for frame_index: int in range(30):
		await get_tree().process_frame
		if _requested_run == run_id:
			return
	assert(false, "No step request")

func _wait_idle() -> void:
	for frame_index: int in range(60):
		await get_tree().process_frame
		if not _executor.is_playing():
			return
	assert(false, "Executor did not terminate")

func _on_step(run_id: int, index: int, step: Step) -> void:
	_requested_run = run_id
	_requested_index = index
	_requested_clip = step.clip_id

func _on_finished(_run_id: int, _id: StringName, outcome: int) -> void:
	_results.append(outcome)

func _cancel_on_start(session_id: int) -> void:
	DialogueManager.cancel_dialogue_session(session_id)

func _on_old_started() -> void:
	_old_started += 1
