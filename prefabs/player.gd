extends CharacterBody3D
class_name Player

@export var player_data : PlayerData = null

@export_group("Movement")
@export var speed: float = 5.0
@export var acceleration: float = 20.0 # 加速度：决定起步快慢
@export var rotation_speed: float = 12.0 # 转身速度

@onready var visuals: Node3D = $Visuals
@onready var animation_tree: AnimationTree = $Visuals/Barbarian/AnimationTree
@onready var interaction_area: Area3D = $Visuals/InteractionArea
@onready var inventory_component: C_Inventory = $InventoryComponent

@onready var attribute_component: GameplayVitalAttributeComponent = %GameplayAttributeComponent
@onready var ability_component: Node = $GameplayAbilityComponent

var animation_state_machine: AnimationNodeStateMachinePlayback
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
## 属性点数管理器
var attribute_points_manager: AttributePointsManager = AttributePointsManager.new(10)

func _ready() -> void:
	animation_state_machine = animation_tree.get("parameters/StateMachine/playback")
	animation_state_machine.travel("movement")

	_init_components()

	# 【测试福利】送 3 瓶药水
	var potion = load("res://data/items/potion_health_small.tres")
	if potion:
		for i in range(3):
			inventory_component.add_item(potion.duplicate())

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
		_try_attack()

#func get_gameplay_attribute_component() -> GameplayAttributeComponent:
	#return attribute_component

func get_inventory() -> C_Inventory:
	return inventory_component

func _play_anim(anim_name: String) -> void:
	if not is_instance_valid(animation_state_machine):
		animation_state_machine = animation_tree.get("parameters/StateMachine/playback")
	if not is_instance_valid(animation_state_machine): return
	animation_state_machine.travel(anim_name)
	
func _set_movement_blend_position(blend_position: float) -> void:
	animation_tree.set("parameters/StateMachine/movement/blend_position", blend_position)

func _try_interact() -> void:
	# 获取探测区域内所有的物体
	var bodies = interaction_area.get_overlapping_areas() # 假设交互物也是Area3D
	if bodies.size() > 0:
		# 找到最近的一个 (简单处理：取第一个)
		var target = bodies[0]
		# 检查目标是否有 interact 方法
		if target.has_method("interact"):
			target.interact()

## 组件初始化
func _init_components() -> void:
	if not is_instance_valid(player_data):
		push_error("PlayerData is not set")
		return
	attribute_component.initialize(player_data.attribute_sets, player_data.vitals)
	
	# 初始化能力组件（如果有普通攻击能力）
	# 加载普通攻击能力
	var basic_attack = load("res://data/abilities/basic_attack.tres")
	if basic_attack:
		ability_component.learn_ability(basic_attack)

## 尝试攻击
func _try_attack() -> void:
	# 查找最近的敌人
	var target = _find_nearest_enemy()
	if not is_instance_valid(target):
		# 没有目标，只播放动画
		_play_anim("attack")
		return
	
	# 使用能力系统进行攻击
	var ability_id = &"basic_attack"
	if ability_component.can_cast(ability_id, target):
		# 提交施法（消耗资源、开始冷却）
		if ability_component.commit_cast(ability_id):
			# 播放攻击动画
			_play_anim("attack")
			# 应用技能效果
			ability_component.apply_ability_effect(ability_id, target)
	else:
		# 无法施法（可能在冷却中），只播放动画
		_play_anim("attack")

## 查找最近的敌人
func _find_nearest_enemy() -> Node:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	if enemies.is_empty():
		return null
	
	var nearest: Node = null
	var nearest_distance: float = INF
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 检查敌人是否有生命值组件（使用能力系统）
		var health_comp = GameplayAbilitySystem.get_component_by_interface(enemy, "HealthComponent")
		if not health_comp:
			# 尝试使用旧的接口
			if not enemy.has_method("take_damage"):
				continue
		
		# 计算距离
		var distance = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	
	# 检查是否在攻击范围内（假设攻击范围为 2.0）
	if nearest and nearest_distance <= 2.0:
		return nearest
	
	return null
