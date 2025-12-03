extends Control
class_name AbilityBar

## 技能栏容器
## 动态绑定已学会的技能，显示技能按钮

# UI 节点引用
@onready var button_container: HBoxContainer = %ButtonContainer

@export var _ability_button_scene: PackedScene = preload("res://ui/ability_button.tscn")

# 数据
var ability_component: GameplayAbilityComponent = null
var ability_buttons: Dictionary[StringName, AbilityButton] = {}

# 快捷键映射（技能 ID -> 快捷键）
var shortcut_mapping: Dictionary[StringName, String] = {
	&"basic_attack": "1",
	# 可以在这里添加更多快捷键映射
}

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	var ability_comp = GameplayAbilitySystem.get_component_by_interface(player, "GameplayAbilityComponent")
	if not is_instance_valid(ability_comp):
		push_error("AbilityBar: Ability component is not valid")
		return
	initialize(ability_comp)

## 初始化技能栏
## [param] comp: GameplayAbilityComponent 技能组件
func initialize(comp: GameplayAbilityComponent) -> void:
	ability_component = comp
	
	if not is_instance_valid(ability_component):
		push_warning("AbilityBar: Ability component is not valid")
		return
	
	# 连接技能组件信号
	if not ability_component.ability_learned.is_connected(_on_ability_learned):
		ability_component.ability_learned.connect(_on_ability_learned)
	if not ability_component.ability_forgotten.is_connected(_on_ability_forgotten):
		ability_component.ability_forgotten.connect(_on_ability_forgotten)
	
	# 初始化已学会的技能
	_refresh_abilities()

## 刷新技能栏（显示所有已学会的技能）
func _refresh_abilities() -> void:
	if not is_instance_valid(ability_component):
		return
	
	# 获取所有已学会的技能
	var learned_abilities = ability_component.get_all_learned_abilities()
	
	# 移除已遗忘的技能按钮
	for ability_id in ability_buttons.keys():
		if not learned_abilities.has(ability_id):
			_remove_ability_button(ability_id)
	
	# 添加新学会的技能按钮
	for ability_id in learned_abilities.keys():
		if not ability_buttons.has(ability_id):
			_add_ability_button(ability_id)

## 添加技能按钮
## [param] ability_id: StringName 技能 ID
func _add_ability_button(ability_id: StringName) -> void:
	if not is_instance_valid(ability_component):
		return
	
	# 加载按钮场景
	var button_scene = _ability_button_scene
	if not is_instance_valid(button_scene):
		push_error("AbilityBar: Cannot load ability_button.tscn")
		return
	
	# 实例化按钮
	var button = button_scene.instantiate() as AbilityButton
	if not is_instance_valid(button):
		push_error("AbilityBar: Cannot instantiate ability button")
		return
	
	# 获取快捷键
	var shortcut = shortcut_mapping.get(ability_id, "")
	
	# 添加到容器
	button_container.add_child(button)
	ability_buttons[ability_id] = button

	# 初始化按钮
	button.initialize(ability_component, ability_id, shortcut)

## 移除技能按钮
## [param] ability_id: StringName 技能 ID
func _remove_ability_button(ability_id: StringName) -> void:
	if not ability_buttons.has(ability_id):
		return
	
	var button = ability_buttons[ability_id]
	if is_instance_valid(button):
		button.queue_free()
	
	ability_buttons.erase(ability_id)

## 技能学会回调
func _on_ability_learned(_ability_id: StringName) -> void:
	_refresh_abilities()

## 技能遗忘回调
func _on_ability_forgotten(_ability_id: StringName) -> void:
	_refresh_abilities()
