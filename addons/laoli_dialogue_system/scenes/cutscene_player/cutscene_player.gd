extends Node

## 只推进步骤与关联回执；宿主负责表现、对话和最终规则提交。

enum Outcome {
	COMPLETED,
	SKIPPED,
	CANCELED,
	FAILED
}

var last_error: String = ""
var _cutscene_id : StringName
var _steps : Array[CutsceneStep] = []
var _skippable : bool = true
var _next_id : int = 0
var _run_id : int = -1
var _index :int = -1
var _waiting : bool = false
var _time_left : float = -1.0
var _exiting: bool = false

signal step_requested(run_id: int, step_index: int, step: CutsceneStep)
signal finished(run_id: int, cutscene_id: StringName, outcome: Outcome)
signal failed(run_id:int, step_index:int, message: String)
signal trace_event(run_id: int, step_index: int, event: StringName, detail: String)

func _enter_tree() -> void:
	_exiting = false

func _exit_tree() -> void:
	_exiting = true
	if _run_id >= 0:
		_finish(Outcome.CANCELED, "执行器退出场景树")

func _process(delta: float) -> void:
	if not _waiting or _time_left < 0.0:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		if _steps[_index].kind == CutsceneStep.StepKind.WAIT:
			complete_step(_run_id, _index)
		else:
			fail_step(_run_id, _index, "片段超时")

func play(definition : CutsceneDefinition) -> int:
	if _exiting or is_queued_for_deletion() or not is_inside_tree() or _run_id >= 0:
		return -1
	last_error = "演出资源为空" if definition == null else definition.validata()
	if not last_error.is_empty():
		return -1
	# 复制本次标量配置，硬性期间编辑共享资源不能改写正在等待的步骤
	_steps.clear()
	for step: CutsceneStep in definition.steps:
		_steps.append(step.duplicate() as CutsceneStep)
	_cutscene_id = definition.cutscene_id
	_skippable = definition.skippable
	_next_id += 1
	_run_id = _next_id
	_index = -1
	var started_id : int = _run_id
	call_deferred("_advance", started_id)
	return started_id

func complete_step(run_id: int, step_index: int) -> void:
	if not _matches(run_id, step_index):
		return
	_waiting = false
	_time_left = -1.0
	call_deferred("_advance", run_id)
	trace_event.emit(run_id, step_index, &"step_completed", "")

func fail_step(run_id: int, step_index: int, message: String) -> void:
	if _matches(run_id, step_index):
		_finish(Outcome.FAILED, message)

## 环境失效可发生在步骤的间隙，不能只允许等待片段时候失效
func abort(run_id: int, message: String) -> void:
	if run_id == _run_id and _run_id >= 0:
		_finish(Outcome.FAILED, message)

func skip(run_id: int) -> void:
	if _run_id == run_id and _run_id >= 0 and _skippable:
		_finish(Outcome.SKIPPED, "跳过")

func cancel(run_id: int, reason: String) -> void:
	if run_id == _run_id and _run_id >= 0:
		_finish(Outcome.CANCELED, reason)

func is_playing() -> bool:
	return _run_id >= 0

func current_step_index() -> int:
	return _index

func _advance(run_id: int) -> void:
	if not is_inside_tree() or run_id != _run_id:
		return
	await get_tree().process_frame
	if _exiting or run_id != _run_id:
		return
	if _index < 0:
		trace_event.emit(run_id, -1, &"started", String(_cutscene_id))
		if run_id != _run_id:
			return
	_index += 1
	if _index >= _steps.size():
		_finish(Outcome.COMPLETED, "步骤完成")
		return
	var step : CutsceneStep = _steps[_index]
	_waiting = true
	_time_left = -1.0
	if step.kind == CutsceneStep.StepKind.WAIT:
		_time_left = step.duration_seconds
	elif step.kind == CutsceneStep.StepKind.PLAY_CLIP:
		_time_left = step.timeout_seconds
	trace_event.emit(run_id, _index, &"step_started", String(step.clip_id) \
		if step.kind == CutsceneStep.StepKind.PLAY_CLIP else step.dialogue_id)
	if run_id == _run_id and _waiting and step.kind != CutsceneStep.StepKind.WAIT:
		step_requested.emit(run_id, _index, step.duplicate() as CutsceneStep)

func _matches(run_id: int, index: int) -> bool:
	return _run_id >= 0 and run_id == _run_id and index == _index and _waiting

func _finish(outcome : Outcome, reason: String) -> void:
	var ended_id : int = _run_id
	var ended_index: int = _index
	var cutscene_id : StringName = _cutscene_id
	_run_id = -1
	_waiting = false
	_time_left = -1
	_steps.clear()
	last_error = reason if outcome == Outcome.FAILED else ""
	trace_event.emit(ended_id, ended_index, &"finished", "%s, %s" %[Outcome.keys()[outcome], reason])
	if outcome == Outcome.FAILED:
		failed.emit(ended_id, ended_index, reason)
	finished.emit(ended_id, cutscene_id, outcome)

			
			
			
			
			
			
