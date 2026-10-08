extends Area3D
signal damage_requested(amount: int)

func receive_damage(amount: int) -> void:
	if amount > 0:
		damage_requested.emit(amount)
