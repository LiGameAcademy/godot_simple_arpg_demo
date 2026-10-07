extends Resource
class_name CutsceneDefinition
const Step = preload("cutscene_step.gd")
@export var cutscene_id: StringName = &""
@export var steps: Array[Step] = []
@export var skippable: bool = true

func validate() -> String:
	if cutscene_id == &"" or steps.is_empty():
		return "演出 ID 或步骤为空"
	for index: int in range(steps.size()):
		var step: Step = steps[index]
		if step == null:
			return "步骤 %d：步骤资源为空" % index
		match step.kind:
			Step.StepKind.PLAY_CLIP:
				if step.clip_id == &"" or not is_finite(step.timeout_seconds) or step.timeout_seconds <= 0.0:
					return "步骤 %d：片段或超时配置无效" % index
			Step.StepKind.SHOW_DIALOGUE:
				if step.dialogue_id.is_empty():
					return "步骤 %d：对话 ID 为空" % index
			Step.StepKind.WAIT:
				if not is_finite(step.duration_seconds) or step.duration_seconds < 0.0:
					return "步骤 %d：停顿时长无效" % index
			_:
				return "步骤 %d：未知步骤类型" % index
	return ""
