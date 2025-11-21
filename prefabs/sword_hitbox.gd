extends Area3D

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	# 因为 Mask 设为了 4，所以撞到的一定是敌人的 Hurtbox
	# Hurtbox 的父节点才是 Enemy 实体
	var enemy = area.get_parent()
	if enemy.has_method("take_damage"):
		enemy.take_damage(1) # 造成 1 点伤害
