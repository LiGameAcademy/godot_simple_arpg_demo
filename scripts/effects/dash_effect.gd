extends GameplayEffect
## Moves the recipient along its facing direction, stopping at the first collision.
@export var distance: float = 3.0
func _apply(target: Node, _instigator: Node, _context: Dictionary) -> void:
	var body: Player = target as Player
	if body == null or not body.can_control():
		return
	var forward: Vector3 = -body.visuals.global_basis.z
	forward.y = 0.0
	body.move_and_collide(forward.normalized() * distance)
