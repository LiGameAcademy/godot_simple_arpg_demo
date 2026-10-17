extends Resource
class_name CutsceneStep

enum StepKind {
	PLAY_CLIP,
	SHOW_DIALOGUE,
	WAIT,
}

@export var kind : StepKind = StepKind.PLAY_CLIP
@export var clip_id: StringName = &""
@export var dialogue_id : String = ""
@export var timeout_seconds : float = 8.0
@export var duration_seconds : float = 0.0
