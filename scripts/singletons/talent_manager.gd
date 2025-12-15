extends Node
class_name TalentManager

## 简易天赋管理器（业务层单例）
## 职责：
## - 管理全局天赋点数
## - 记录已学习的天赋
## - 将天赋对应的 GameplayAbilityModifier 应用到指定实体
##
## 使用方式：
## - 在 Project Settings → Autoload 中添加本脚本为单例（名称：TalentManager）
## - 在游戏流程中通过 TalentManager.learn_talent(player, talent_data) 学习天赋

## 可用天赋点数
var available_points: int = 0

## 已学习天赋集合：{ talent_id: true }
var _learned_talents: Dictionary = {}

signal talent_learned(talent_id: StringName)
signal talent_points_changed(new_points: int)

## 增加天赋点数（例如升级时调用）
func add_points(points: int) -> void:
	if points <= 0:
		return
	available_points += points
	talent_points_changed.emit(available_points)

## 获取已用点数
func get_spent_points() -> int:
	var spent: int = 0
	for tid in _learned_talents.keys():
		if _learned_talents[tid]:
			# 这里无法直接拿到 cost，仅做统计用途时可根据需要扩展
			spent += 1
	return spent

## 检查是否已学习
func is_learned(talent_id: StringName) -> bool:
	return _learned_talents.get(talent_id, false)

## 检查是否可以学习指定天赋
func can_learn(talent: TalentData) -> bool:
	if not is_instance_valid(talent):
		return false
	if talent.talent_id.is_empty():
		return false
	if is_learned(talent.talent_id):
		return false
	if available_points < talent.cost:
		return false
	# 检查前置天赋
	for pre_id in talent.prerequisites:
		if not is_learned(pre_id):
			return false
	return true

## 学习天赋并应用到实体
## [param] entity: Node 需要应用天赋效果的实体（通常是 Player）
## [param] talent: TalentData 要学习的天赋
## [return] bool 是否学习成功
func learn_talent(entity: Node, talent: TalentData) -> bool:
	if not can_learn(talent):
		return false
	if not is_instance_valid(entity):
		return false
	
	available_points -= talent.cost
	talent_points_changed.emit(available_points)
	_learned_talents[talent.talent_id] = true
	
	_apply_talent_to_entity(entity, talent)
	
	talent_learned.emit(talent.talent_id)
	return true

## 将天赋效果应用到实体（注册所有 GameplayAbilityModifier）
func _apply_talent_to_entity(entity: Node, talent: TalentData) -> void:
	if not is_instance_valid(talent):
		return
	
	var modifier_comp: GameplayModifierComponent = GameplayAbilitySystem.get_component_by_interface(
		entity,
		"GameplayModifierComponent"
	)
	
	if not is_instance_valid(modifier_comp):
		return
	
	var source_id: String = "talent." + String(talent.talent_id)
	for mod in talent.ability_modifiers:
		if is_instance_valid(mod):
			modifier_comp.add_modifier(mod, source_id)


