extends Area3D

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	# 命中框只通知接收区域，区域向所属实体发信号。
	if area.has_method("receive_damage"):
		area.call("receive_damage", 1)
