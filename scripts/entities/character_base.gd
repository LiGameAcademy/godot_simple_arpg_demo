extends CharacterBody3D
class_name CharacterBase

## 角色基类
## 提供通用的动画系统、属性组件等基础功能

@export_group("Components")
## 属性组件（使用 unique_name_in_owner 时使用 %GameplayAttributeComponent）
@onready var attribute_component: GameplayVitalAttributeComponent = %GameplayAttributeComponent
## 能力组件（可选，如果角色需要使用能力系统）
@export var ability_component: GameplayAbilityComponent
## 视觉适配器（处理动画相关逻辑，连接业务层和技能组件）
@export var _visual_adapter: VisualAdapter = null
## 挂点映射
@export var _attachment_point_mapping: Dictionary[StringName, BoneAttachment3D] = {}

func _ready() -> void:
	_init_components()

## 获取属性组件
func get_attribute_component() -> GameplayVitalAttributeComponent:
	return attribute_component

## 获取能力组件
func get_ability_component() -> GameplayAbilityComponent:
	return ability_component

## 获取视觉适配器
func get_visual_adapter() -> Node:
	return _visual_adapter

#region ========== 能力系统相关 ==========

## 尝试施放技能（通用方法，替代原来的 _try_attack）
## [param] ability_id: StringName 技能 ID
## [param] target: Node 目标节点（可选）
## [param] context: Dictionary 上下文信息（可选）
func try_cast_ability(ability_id: StringName, target: Node = null, context: Dictionary = {}) -> void:
	if not is_instance_valid(ability_component):
		push_warning("CharacterBase: Cannot cast ability, ability_component is not valid")
		return
	
	if ability_component.can_cast(ability_id, target, context):
		var ok := ability_component.commit_cast(ability_id, target, context)
		if not ok:
			push_warning("CharacterBase: Failed to commit cast for ability: %s" % ability_id)
			return
		print("CharacterBase: Ability committed cast: ", ability_id)
	else:
		print("CharacterBase: Ability can not cast: ", ability_id)

## 尝试攻击（向后兼容，内部调用 try_cast_ability）
## 默认实现：使用 _get_attack_ability() 获取攻击能力并施放
func _try_attack() -> void:
	var attack_ability = _get_attack_ability()
	if not is_instance_valid(attack_ability):
		push_warning("CharacterBase: Cannot attack, attack ability is not valid")
		return
	
	try_cast_ability(attack_ability.ability_id)

## 获取攻击能力（子类必须重写）
## [return] GameplayAbility 攻击能力数据，如果返回 null 则无法攻击
func _get_attack_ability() -> GameplayAbility:
	push_warning("CharacterBase: _get_attack_ability() not implemented, please override in subclass")
	return null

## 获取角色面朝角度（子类可重写）
## [return] float 面朝角度（弧度），如果返回 null 则不设置 facing_angle
func _get_facing_angle() -> float:
	# 默认实现：尝试从 visuals 子节点获取
	var visuals = get_node_or_null("Visuals")
	if is_instance_valid(visuals) and visuals is Node3D:
		return (visuals as Node3D).rotation.y
	
	# 如果没有 visuals，尝试从自身获取
	if rotation.y != 0.0:
		return rotation.y
	
	# 如果都没有，从 transform 计算
	var forward = -global_transform.basis.z
	return atan2(forward.x, forward.z)

## 获取挂点节点（用于 Cue 系统）
## [param] attachment_point: StringName 挂点名（如 "head", "foot", "body" 等）
## [return] Node3D 挂点节点，如果找不到则返回 null
func get_attachment_point(attachment_point: StringName) -> Node3D:
	return _attachment_point_mapping.get(attachment_point, null)

#endregion

## 初始化组件（子类可重写）
func _init_components() -> void:
	pass
