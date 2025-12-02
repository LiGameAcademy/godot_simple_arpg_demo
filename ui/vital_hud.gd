extends Control
class_name VitalHUD

## Vital HUD 面板
## 在 HUD 中显示角色的生命值、法力值等 Vital 信息

# UI 节点引用
@onready var health_bar : VitalBar = %HealthBar
@onready var mana_bar : VitalBar = %ManaBar

# 组件引用
var _vital_component: GameplayVitalAttributeComponent

func _ready() -> void:
	# 尝试获取玩家和组件
	_initialize_from_player()

## 从玩家初始化
func _initialize_from_player() -> void:
	var player: Player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player):
		push_warning("VitalHUD: Player not found")
		return
	
	# 获取 Vital 组件
	var comp = GameplayAbilitySystem.get_component_by_interface(player, "GameplayAttributeComponent")
	if not is_instance_valid(comp) or not comp is GameplayVitalAttributeComponent:
		push_warning("VitalHUD: GameplayVitalAttributeComponent not found")
		return
	
	initialize(comp as GameplayVitalAttributeComponent)

## 初始化 HUD
## [param] comp: GameplayVitalAttributeComponent Vital 属性组件
func initialize(comp: GameplayVitalAttributeComponent) -> void:
	_vital_component = comp
	
	# 初始化生命值条
	if health_bar and _vital_component.has_vital(&"health"):
		health_bar.initialize(_vital_component, &"health")
	
	# 初始化法力值条
	if mana_bar and _vital_component.has_vital(&"mana"):
		mana_bar.initialize(_vital_component, &"mana")
