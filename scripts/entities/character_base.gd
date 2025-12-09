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

@export_group("Death Settings")
## 死亡动画名称（如果为空，将尝试使用 "death"）
@export var death_animation_name: StringName = &"death"
## 是否已死亡（防止重复触发）
var _is_dead: bool = false

func _ready() -> void:
	_init_components()
	_setup_death_listener()

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
	
	# 如果上下文中没有 facing_angle，则获取面朝方向
	if not context.has("facing_angle"):
		var facing_angle: float = _get_facing_angle()
		context["facing_angle"] = facing_angle
	
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
	if rotation.y != 0.0:
		return rotation.y
	
	# 如果都没有，从 transform 计算
	# 注意：模型朝向 -Z（Godot 默认前方）
	# 由于模型从 +Z 改为 -Z（旋转了 180 度），角度需要加 π
	var forward = -global_transform.basis.z
	var base_angle = atan2(forward.x, forward.z)
	return base_angle + PI

## 获取挂点节点（用于 Cue 系统）
## [param] attachment_point: StringName 挂点名（如 "head", "foot", "body" 等）
## [return] Node3D 挂点节点，如果找不到则返回 null
func get_attachment_point(attachment_point: StringName) -> Node3D:
	return _attachment_point_mapping.get(attachment_point, null)

#endregion

## 初始化组件（子类可重写）
func _init_components() -> void:
	pass

## 设置死亡监听器
func _setup_death_listener() -> void:
	# 监听统一游戏事件：entity_died
	AbilityEventBus.game_event_occurred.connect(_on_game_event_occurred)

## 处理游戏事件
func _on_game_event_occurred(event_type: StringName, context: Dictionary) -> void:
	if event_type != &"entity_died":
		return
	
	# 检查是否是自己的死亡事件
	var entity = context.get("entity") as Node
	if entity != self:
		return
	
	# 防止重复触发
	if _is_dead:
		return
	
	# 播放死亡动画
	_play_death_animation()

## 播放死亡动画
func _play_death_animation() -> void:
	if _is_dead:
		return
	
	_is_dead = true
	
	# 使用 VisualAdapter 播放死亡动画
	if is_instance_valid(_visual_adapter):
		var anim_name = death_animation_name
		if anim_name.is_empty():
			anim_name = &"death"  # 默认使用 "death"
		
		_visual_adapter.play_animation(anim_name)
		print("CharacterBase: Playing death animation: %s" % anim_name)
	else:
		push_warning("CharacterBase: Cannot play death animation, _visual_adapter is not valid")
