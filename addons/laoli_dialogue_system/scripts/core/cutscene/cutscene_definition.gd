extends Resource
class_name CutsceneDefinition

@export var cutscene_id: StringName = &""
@export var steps : Array[CutsceneStep] = []
@export var skippable : bool  = true

func validata() -> String:
	if cutscene_id.is_empty() or steps.is_empty():
		return "演出ID 或步骤为空"
	for index: int in range(steps.size()):
		var step : CutsceneStep = steps[index]
		if step == null:
			return "步骤 %d： 步骤资源为空！" % index
		match step.kind:
			CutsceneStep.StepKind.PLAY_CLIP:
				if step.clip_id.is_empty() or not is_finite(step.timeout_seconds) or step.timeout_seconds <= 0.0:
					return "步骤 %d： 片段或超时配置无效" % index
			CutsceneStep.StepKind.SHOW_DIALOGUE:
				if step.dialogue_id.is_empty():
					return "步骤 %d： 对话ID 为空" % index
			CutsceneStep.StepKind.WAIT:
				if not is_finite(step.duration_seconds) or step.duration_seconds < 0.0:
					return "步骤 %d： 停顿时长无效" % index
			_:
				return "步骤 %d：未知步骤类型" % index
	return ""
