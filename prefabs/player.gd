extends CharacterBase
class_name Player

@export var player_data : PlayerData = null

@export_group("Movement")
@export var speed: float = 5.0
@export var acceleration: float = 20.0 # 加速度：决定起步快慢
@export var rotation_speed: float = 12.0 # 转身速度

@onready var visuals: Node3D = $Visuals
@onready var interaction_area: Area3D = $Visuals/InteractionArea
@onready var inventory_component: C_Inventory = $InventoryComponent

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
## 属性点数管理器
var attribute_points_manager: AttributePointsManager = AttributePointsManager.new(10)
## 技能快捷键管理器
var shortcut_manager: AbilityShortcutManager = AbilityShortcutManager.new()

func _ready() -> void:
	super()
	
	# 播放初始动画（通过 VisualAdapter）
	if is_instance_valid(_visual_adapter):
		_visual_adapter.play_animation("movement")
	
	# 【测试福利】送 3 瓶药水
	var potion = load("res://data/items/potion_health_small.tres")
	if potion:
		for i in range(3):
			inventory_component.add_item(potion.duplicate())
	
	# 初始化快捷键绑定（在技能学会后绑定）
	_setup_shortcuts()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# 1. 获取输入 (2D向量)
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 2. 转换为 3D 方向 (X/Z 平面)
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction:
		# 3. 移动逻辑：利用 move_toward 实现平滑加速
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
		
		# 4. 旋转逻辑：让 Visuals 平滑转向移动方向
		var target_angle = atan2(input_dir.x, input_dir.y)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, rotation_speed * delta)
	else:
		# 停止逻辑：利用 move_toward 实现平滑减速 (惯性停车)
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		
	_set_movement_blend_position(velocity.length())
	# 6. 应用移动
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("attack"):
		# 向后兼容：仍然支持鼠标左键攻击
		_try_attack()
	
	# 处理技能快捷键
	if shortcut_manager.handle_input(event, self):
		# 快捷键已处理，阻止进一步传播
		get_viewport().set_input_as_handled()

#func get_gameplay_attribute_component() -> GameplayAttributeComponent:
	#return attribute_component

func get_inventory() -> C_Inventory:
	return inventory_component

func _set_movement_blend_position(blend_position: float) -> void:
	# 通过 VisualAdapter 设置混合参数
	if is_instance_valid(_visual_adapter) and _visual_adapter.has_method("set_blend_parameter"):
		_visual_adapter.set_blend_parameter("StateMachine/movement/blend_position", blend_position)

func _try_interact() -> void:
	# 获取探测区域内所有的物体
	var bodies = interaction_area.get_overlapping_areas() # 假设交互物也是Area3D
	if bodies.size() > 0:
		# 找到最近的一个 (简单处理：取第一个)
		var target = bodies[0]
		# 检查目标是否有 interact 方法
		if target.has_method("interact"):
			target.interact()

## 组件初始化（重写基类方法）
func _init_components() -> void:
	super()
	if not is_instance_valid(player_data):
		push_error("PlayerData is not set")
		return
	attribute_component.initialize(player_data.attribute_sets, player_data.vitals)
	
	# 初始化能力组件
	# 加载普通攻击能力
	var basic_attack = player_data.basic_attack_ability
	if basic_attack:
		ability_component.learn_ability(basic_attack)
	else:
		push_error("BasicAttackAbility is not set")
	
	# 加载初始技能列表（如冲刺、火球等）
	for ability in player_data.initial_abilities:
		if is_instance_valid(ability):
			ability_component.learn_ability(ability)
	
	# 连接技能学会信号，自动绑定快捷键
	if not ability_component.ability_learned.is_connected(_on_ability_learned):
		ability_component.ability_learned.connect(_on_ability_learned)

## 设置快捷键绑定
func _setup_shortcuts() -> void:
	if not is_instance_valid(ability_component):
		return
	
	# 默认快捷键映射
	var default_shortcuts = {
		&"basic_attack": "1",
		&"dash": "2",
	}
	
	# 绑定已学会的技能
	var learned_abilities = ability_component.get_all_learned_abilities()
	for ability_id in learned_abilities.keys():
		var shortcut = default_shortcuts.get(ability_id, "")
		if shortcut != "":
			shortcut_manager.bind_shortcut(ability_id, shortcut)

## 技能学会回调（自动绑定快捷键）
func _on_ability_learned(ability_id: StringName) -> void:
	# 默认快捷键映射
	var default_shortcuts = {
		&"basic_attack": "1",
		&"dash": "2",
	}
	
	var shortcut = default_shortcuts.get(ability_id, "")
	if shortcut != "":
		shortcut_manager.bind_shortcut(ability_id, shortcut)

## 获取攻击能力（重写基类方法）
func _get_attack_ability() -> GameplayAbility:
	if not is_instance_valid(player_data):
		return null
	return player_data.basic_attack_ability

## 获取角色面朝角度（重写基类方法，使用 visuals 节点）
func _get_facing_angle() -> float:
	if is_instance_valid(visuals) and visuals is Node3D:
		return visuals.rotation.y
	return super._get_facing_angle()
