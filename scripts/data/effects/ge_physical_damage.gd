extends GameplayEffect
class_name GE_PhysicalDamage

## 物理伤害效果
## 基于施法者的攻击属性值计算伤害

@export var damage_multiplier: float = 1.0  ## 伤害倍数（基于攻击力）

func _apply(target: Node, instigator: Node, _context: Dictionary) -> void:
	if not is_instance_valid(target) or not is_instance_valid(instigator):
		return
	
	# 获取施法者的属性组件
	var caster_attr_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayAttributeComponent")
	if not caster_attr_comp:
		push_warning("GE_PhysicalDamage: Caster has no GameplayAttributeComponent!")
		return
	
	# 计算伤害（使用攻击属性值）
	var attack_value = caster_attr_comp.get_value(&"attack", 0.0)
	var damage = attack_value * damage_multiplier
	
	if damage <= 0.0:
		return
	
	# 获取目标的生命值组件（使用鸭子类型）
	var target_health_comp = GameplayAbilitySystem.get_component_by_interface(target, "HealthComponent")
	if target_health_comp and target_health_comp.has_method("apply_damage"):
		var damage_info = DamageInfo.new(instigator, null, damage, false)
		target_health_comp.apply_damage(damage_info)
		return
	
	# 尝试使用 Vital 系统
	var vital_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayVitalAttributeComponent")
	if vital_comp and vital_comp.has_vital(&"health"):
		var health_vital = vital_comp.get_vital(&"health")
		if health_vital:
			var damage_info = DamageInfo.new(instigator, null, damage, false)
			health_vital.apply_damage(damage_info, target)
			return
	
	# 尝试使用旧的接口（向后兼容）
	if target.has_method("take_damage"):
		target.take_damage(int(damage))

func _get_description() -> String:
	return "Deal %s%% attack damage\n" % (damage_multiplier * 100.0)
