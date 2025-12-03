extends CharacterBody3D
class_name CharacterBase

## 角色基类
## 提供通用的动画系统、属性组件等基础功能

@export_group("Animation")
## 动画树路径（子类可以设置，或通过 _get_animation_tree_path() 重写）
@export var animation_tree_path: NodePath = NodePath("")
var animation_tree: AnimationTree = null

@export_group("Components")
## 属性组件（使用 unique_name_in_owner 时使用 %GameplayAttributeComponent）
@onready var attribute_component: GameplayVitalAttributeComponent = %GameplayAttributeComponent
## 能力组件（可选，如果角色需要使用能力系统）
@export var ability_component: GameplayAbilityComponent

## 动画状态机
var animation_state_machine: AnimationNodeStateMachinePlayback
## 当前正在执行的能力ID（用于动画事件触发）
var _current_ability_id: StringName = &""

func _ready() -> void:
	_init_animation()
	_init_components()

## 获取属性组件
func get_attribute_component() -> GameplayVitalAttributeComponent:
	return attribute_component

## 获取动画树
func get_animation_tree() -> AnimationTree:
	return animation_tree

## 获取动画状态机
func get_animation_state_machine() -> AnimationNodeStateMachinePlayback:
	return animation_state_machine

## 获取能力组件
func get_ability_component() -> GameplayAbilityComponent:
	return ability_component

#region ========== 能力系统相关 ==========

## 尝试攻击（子类可重写以自定义攻击逻辑）
## 默认实现：使用 _get_attack_ability() 获取攻击能力并施放
func _try_attack() -> void:
	if not is_instance_valid(ability_component):
		push_warning("CharacterBase: Cannot attack, ability_component is not valid")
		return
	
	var attack_ability = _get_attack_ability()
	if not is_instance_valid(attack_ability):
		push_warning("CharacterBase: Cannot attack, attack ability is not valid")
		return
	
	if ability_component.can_cast(attack_ability.ability_id):
		var ok := ability_component.commit_cast(attack_ability.ability_id)
		if not ok:
			push_warning("CharacterBase: Failed to commit cast for ability: %s" % attack_ability.ability_id)
			return
		print("CharacterBase: Attack ability committed cast: ", attack_ability.ability_id)
	else:
		print("CharacterBase: Attack ability can not cast: ", attack_ability.ability_id)

## 获取攻击能力（子类必须重写）
## [return] GameplayAbility 攻击能力数据，如果返回 null 则无法攻击
func _get_attack_ability() -> GameplayAbility:
	push_warning("CharacterBase: _get_attack_ability() not implemented, please override in subclass")
	return null

## 能力施放时的回调（由能力组件信号触发）
func _on_ability_cast(ability_id: StringName) -> void:
	if not is_instance_valid(ability_component):
		return
	
	var ability_data = ability_component.get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		push_error("CharacterBase: Ability data is not valid for ability_id: %s" % ability_id)
		return
	
	if ability_data is ActiveAbility:
		var active_ability = ability_data as ActiveAbility
		_play_anim(active_ability.animation_name)
		_current_ability_id = ability_id
	
	print("CharacterBase: Ability casted: ", ability_id)

## 能力激活时的回调（由能力组件信号触发）
func _on_ability_activated(_ability_id: StringName) -> void:
	print("CharacterBase: Ability activated: ", _ability_id)

## 动画事件回调（由动画系统触发）
## [param] event_name: String 事件名称
## [param] _data: Variant 事件数据
func _on_anim_event(event_name: String, _data: Variant = null) -> void:
	# 如果事件名是技能生效点，则执行技能效果
	if event_name == "ability_activated" and not _current_ability_id.is_empty():
		if not is_instance_valid(ability_component):
			push_warning("CharacterBase: Cannot apply ability effect, ability_component is not valid")
			_current_ability_id = &""
			return
		
		# 构建上下文，包含角色面朝方向
		var context: Dictionary = {}
		var facing_angle = _get_facing_angle()
		# facing_angle 是 float 类型，总是有值，直接设置
		context["facing_angle"] = facing_angle
		
		ability_component.apply_ability_effect(_current_ability_id, null, context)
		#TODO 如果你的连招系统（Animation State Machine）允许快速切换，_current_ability_id 可能会在动画还没结束时就被覆盖。
		#TODO 建议在 commit_cast 时将 ID 存入一个队列，或者确保动画状态机锁定（不可打断）直到生效点结束。
		_current_ability_id = &""
		print("CharacterBase: Ability effect applied: %s on animation event: %s" % [_current_ability_id, event_name])

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

#endregion

## 初始化动画系统
func _init_animation() -> void:
	# 如果还没有设置动画树，尝试获取
	if not is_instance_valid(animation_tree):
		# 优先使用子类重写的路径
		var path = _get_animation_tree_path()
		if path != NodePath(""):
			animation_tree = get_node_or_null(path)
		
		# 如果还是没有，尝试使用 export 的路径
		if not is_instance_valid(animation_tree) and animation_tree_path != NodePath(""):
			animation_tree = get_node_or_null(animation_tree_path)
	
	if not is_instance_valid(animation_tree):
		push_warning("CharacterBase: AnimationTree not found. Override _get_animation_tree_path() or set animation_tree_path.")
		return
	
	animation_state_machine = animation_tree.get("parameters/StateMachine/playback")
	if not is_instance_valid(animation_state_machine):
		push_warning("CharacterBase: AnimationNodeStateMachinePlayback not found in AnimationTree")
		return

## 获取动画树路径（子类可重写）
## [return] NodePath 动画树的路径
func _get_animation_tree_path() -> NodePath:
	return NodePath("")

## 初始化组件（子类可重写）
func _init_components() -> void:
	if is_instance_valid(ability_component):
		ability_component.ability_cast.connect(_on_ability_cast)
		ability_component.ability_activated.connect(_on_ability_activated)
	else:
		push_warning("CharacterBase: Ability component is not valid")

## 播放动画
## [param] anim_name: String 动画名称
func _play_anim(anim_name: String) -> void:
	if not is_instance_valid(animation_state_machine):
		# 尝试重新获取
		if is_instance_valid(animation_tree):
			animation_state_machine = animation_tree.get("parameters/StateMachine/playback")
	
	if not is_instance_valid(animation_state_machine):
		push_warning("CharacterBase: Cannot play animation '%s', animation_state_machine is invalid" % anim_name)
		return
	
	animation_state_machine.travel(anim_name)
