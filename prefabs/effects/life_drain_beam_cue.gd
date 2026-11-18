extends GameplayCueBase
## Spawns the ARPG beam for a channel and frees it when the channel stops.

@export var beam_scene: PackedScene

var _beam: LifeDrainBeam

func _execute(target: Node, _location: Vector3, context: Dictionary) -> void:
	var caster: Node3D = context.get("instigator") as Node3D
	var recipient: Node3D = target as Node3D
	if not is_instance_valid(caster) or not is_instance_valid(recipient) or caster == recipient or beam_scene == null:
		return
	if is_instance_valid(_beam):
		_beam.queue_free()
	var visual: Node = beam_scene.instantiate()
	_beam = visual as LifeDrainBeam
	if _beam == null:
		visual.free()
		return
	_beam.bind_endpoints(caster, recipient)
	caster.add_child(_beam)

func _stop(_target: Node) -> void:
	if is_instance_valid(_beam):
		_beam.queue_free()
	_beam = null
