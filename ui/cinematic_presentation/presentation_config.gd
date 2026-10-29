extends Resource
class_name BossPresentationConfig

@export var durations: Dictionary[StringName, float] = {
	&"establish": 1.2, &"recognition": 1.4, &"mirror": 2.0,
	&"corrupt": 2.0, &"return": 1.0, &"title": 1.4, &"release": 1.4
}
@export var overview_offset : Vector3 = Vector3(9, 8, 13)
@export var close_offset: Vector3 = Vector3(4, 2, 6)

func is_valid_clip(clip: StringName) -> bool:
	return durations.has(clip) and is_finite(durations[clip]) and durations[clip] > 0.0
