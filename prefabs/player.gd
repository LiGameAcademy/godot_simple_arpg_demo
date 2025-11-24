extends CharacterBody3D

@export_group("Movement")
@export var speed: float = 5.0
@export var acceleration: float = 20.0 # 加速度：决定起步快慢
@export var rotation_speed: float = 12.0 # 转身速度

@onready var visuals: Node3D = $Visuals
@onready var animation_tree: AnimationTree = $Visuals/Barbarian/AnimationTree
@onready var interaction_area: Area3D = $Visuals/InteractionArea
@onready var inventory_component: C_Inventory = $InventoryComponent

# 记录当前焦点，用于对比变化
var current_interactable: InteractionComponent = null

var animation_state_machine: AnimationNodeStateMachinePlayback
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	animation_state_machine = animation_tree.get("parameters/StateMachine/playback")
	animation_state_machine.travel("movement")
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

	# 每帧更新交互焦点
	_update_interaction_focus()
	
	# 6. 应用移动
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		# 直接使用已经检测到的 current_interactable，无需再次 get_overlapping_areas
		if is_instance_valid(current_interactable):
			current_interactable.interact(self)
	elif event.is_action_pressed("attack"):
		_play_anim("attack")

func get_inventory() -> C_Inventory:
	return inventory_component

func _play_anim(anim_name: String) -> void:
	if not is_instance_valid(animation_state_machine):
		animation_state_machine = animation_tree.get("parameters/StateMachine/playback")
	if not is_instance_valid(animation_state_machine): return
	animation_state_machine.travel(anim_name)
	
func _set_movement_blend_position(blend_position: float) -> void:
	animation_tree.set("parameters/StateMachine/movement/blend_position", blend_position)

func _update_interaction_focus() -> void:
	# 获取探测区域内所有的 Area3D
	var areas = interaction_area.get_overlapping_areas()
	var new_interactable: InteractionComponent = null
	
	# 筛选出最近的一个 InteractionComponent
	if areas.size() > 0:
		# 这里简单取第一个，严谨的做法是遍历计算距离最近的那个
		var target = areas[0]
		if target is InteractionComponent:
			new_interactable = target
	else:
		if current_interactable:
			current_interactable.unfocused()
		current_interactable = null
	
	# 【核心逻辑】焦点切换检测
	# 如果当前注视的物体发生了变化 (从有到无，从A到B)
	if new_interactable != current_interactable:
		# 1. 告诉旧的物体：我不看你了，隐藏提示
		if current_interactable:
			current_interactable.unfocused()
		
		# 2. 告诉新的物体：我在看你，显示提示
		if new_interactable:
			new_interactable.focused()
		
		# 3. 更新记录
		current_interactable = new_interactable

func _on_dialogue_started() -> void:
	set_physics_process(false)
	velocity = Vector3.ZERO

func _on_dialogue_finished() -> void:
	# 恢复控制
	set_physics_process(true)
