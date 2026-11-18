extends Node3D
class_name LifeDrainBeam

## Tracks both endpoints while the channel's Cue owns this visual.

@onready var _mesh: MeshInstance3D = $BeamMesh

var _caster: Node3D
var _target: Node3D

func _ready() -> void:
	top_level = true
	_process(0.0)

func _process(_delta: float) -> void:
	if not is_instance_valid(_caster) or not is_instance_valid(_target):
		queue_free()
		return

	var start: Vector3 = _get_body_position(_caster)
	var finish: Vector3 = _get_body_position(_target)
	var direction: Vector3 = finish - start
	var distance: float = direction.length()
	_mesh.visible = distance > 0.001
	if _mesh.visible:
		var bend: Quaternion = Quaternion(Vector3.UP, direction / distance)
		global_position = (start + finish) / 2.0
		_mesh.basis = Basis(bend).scaled_local(Vector3(1.0, distance, 1.0))

func bind_endpoints(caster: Node3D, target: Node3D) -> void:
	_caster = caster
	_target = target

func _get_body_position(entity: Node3D) -> Vector3:
	if entity.has_method("get_attachment_point"):
		var point: Node3D = entity.call("get_attachment_point", &"body") as Node3D
		if is_instance_valid(point):
			return point.global_position
	return entity.global_position
