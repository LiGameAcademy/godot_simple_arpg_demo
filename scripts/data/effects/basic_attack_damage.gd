extends GameplayEffect
class_name GE_BasicAttackDamage

## 普通攻击伤害效果
## 使用攻击属性值计算伤害

@export var damage_multiplier: float = 1.0  ## 伤害倍数（基于攻击力）

func _apply(target: Node, instigator: Node, _context: Dictionary) -> void:
	if not is_instance_valid(target) or not is_instance_valid(instigator):
		return
	
	# 获取施法者的属性组件
	var caster_attr_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayAttributeComponent")
	if not caster_attr_comp:
		push_warning("GE_BasicAttackDamage: Caster has no GameplayAttributeComponent!")
		return
	
	# 获取目标的生命值组件（使用鸭子类型）
	var target_health_comp = GameplayAbilitySystem.get_component_by_interface(target, "HealthComponent")
	if not target_health_comp:
		# 尝试使用 HealthVital
		var vital_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayVitalAttributeComponent")
		if vital_comp and vital_comp.has_vital(&"health"):
			var health_vital = vital_comp.get_vital(&"health")
			if health_vital:
				# 计算伤害
				var vital_attack_value = caster_attr_comp.get_value(&"attack", 0.0)
				var vital_damage = vital_attack_value * damage_multiplier
				
				# 创建伤害信息
				var vital_damage_info = DamageInfo.new(instigator, null, vital_damage, false)
				
				# 应用伤害
				health_vital.apply_damage(vital_damage_info, target)
				return
		
		push_warning("GE_BasicAttackDamage: Target has no HealthComponent or HealthVital!")
		return
	
	# 计算伤害
	var attack_value = caster_attr_comp.get_value(&"attack", 0.0)
	var damage = attack_value * damage_multiplier
	
	# 创建伤害信息
	var damage_info = DamageInfo.new(instigator, null, damage, false)
	
	# 应用伤害
	if target_health_comp.has_method("apply_damage"):
		target_health_comp.apply_damage(damage_info)
	else:
		push_warning("GE_BasicAttackDamage: HealthComponent does not have apply_damage method!")

func _get_description() -> String:
	return "Deal %s%% attack damage\n" % (damage_multiplier * 100.0)

