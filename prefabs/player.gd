extends CharacterBase
class_name Player
## Owns player controls; vitals, abilities and inventory remain component-owned.

@onready var animation_tree: AnimationTree = $Visuals/Barbarian/AnimationTree
@onready var animation_state_machine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/StateMachine/playback")
var _control_locks: Array[StringName] = []
var _focused_interaction: InteractionComponent


@export var player_data : PlayerData = null

@export_group("Movement")
@export var speed: float = 5.0:
	get:
		if not is_instance_valid(attribute_component):
			return speed
		return attribute_component.get_value("speed", speed)
@export var acceleration: float = 20.0 # 加速度：决定起步快慢
@export var rotation_speed: float = 12.0 # 转身速度

@export_group("Combat")

@onready var visuals: Node3D = $Visuals
@onready var interaction_area: Area3D = $Visuals/InteractionArea
@onready var inventory_component: InventoryComponent = $InventoryComponent
@onready var equipment_component: EquipmentComponent = $EquipmentComponent
@onready var equipment_handler: PlayerEquipment = $PlayerEquipment
@onready var inventory_binding: PlayerInventory = $PlayerInventory

@onready var hand_slot_attachment_r: BoneAttachment3D = $Visuals/Barbarian/Rig_Medium/Skeleton3D/HandSlotAttachmentR
@onready var hand_slot_attachment_l: BoneAttachment3D = $Visuals/Barbarian/Rig_Medium/Skeleton3D/HandSlotAttachmentL

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## 属性点数管理器
var attribute_points_manager: AttributePointsManager = AttributePointsManager.new(10)
## 技能快捷键管理器
var shortcut_manager: AbilityShortcutManager = AbilityShortcutManager.new()
## 最后移动方向（用于近战技能朝向）
var _last_movement_direction: Vector2 = Vector2(0, 1)

func _ready() -> void:
	super()
	ability_component.modifier_component = $GameplayModifierComponent as GameplayModifierComponent
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	
	# 将快捷键管理器添加到场景树，使其能够接收 _unhandled_input
	if not shortcut_manager.is_inside_tree():
		add_child(shortcut_manager)
	
	# 播放初始动画（通过 VisualAdapter）
	if is_instance_valid(_visual_adapter):
		_visual_adapter.play_animation("movement")
	
	var attachments: Dictionary[StringName, BoneAttachment3D] = _attachment_point_mapping.duplicate()
	attachments[&"hand_right"] = hand_slot_attachment_r
	attachments[&"hand_left"] = hand_slot_attachment_l
	equipment_handler.initialize(attribute_component, ability_component, self, attachments)
	equipment_component.equip_changed.connect(equipment_handler.apply_equipment)
	inventory_binding.initialize(inventory_component, equipment_component, self)
	# 初始化快捷键绑定（在技能学会后绑定）
	_setup_shortcuts()
	
	# 连接快捷键管理器的信号到技能组件
	_connect_shortcut_signals()
	
	# 监听技能完成信号
	if is_instance_valid(ability_component):
		ability_component.ability_completed.connect(_on_ability_completed)
	

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# 【标签系统】检查是否被眩晕或定身（无法移动）
	if TagManager.has_tag(self, &"state.stunned") or TagManager.has_tag(self, &"state.rooted"):
		# 眩晕/定身状态：停止移动，但保持重力
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		_set_movement_blend_position(velocity.length())
		move_and_slide()
		return
	
	# 1. 获取输入 (2D向量)
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down") if can_control() else Vector2.ZERO

	# 2. 转换为 3D 方向 (X/Z 平面)
	# 注意：模型朝向 -Z（Godot 默认前方）
	# - input_dir.x 是左右（对应 3D 的 X 轴，正值为右）
	# - input_dir.y 是前后（对应 3D 的 Z 轴，正值为前，但在 2D 输入映射中是 Y）
	# 当 input_dir.y = 1（向上键，向前）时，应该朝向 -Z
	# 所以需要取反：Vector3(input_dir.x, 0, -input_dir.y)
	var direction: Vector3 = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction:
		# 3. 移动逻辑：利用 move_toward 实现平滑加速
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
		
		# 4. 旋转逻辑：平滑转向移动方向
		# 注意：模型朝向 -Z（Godot 默认前方）
		# - input_dir.x 是左右（对应 3D 的 X 轴，正值为右）
		# - input_dir.y 是前后（对应 3D 的 Z 轴，正值为前，但在 2D 输入映射中是 Y）
		# 当 input_dir.y = 1（向上键，向前）时，应该朝向 -Z
		# 由于模型从 +Z 改为 -Z（旋转了 180 度），角度需要加 π
		var base_angle: float = atan2(input_dir.x, input_dir.y)
		var target_angle: float = base_angle + PI
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, rotation_speed * delta)
		
		# 保存最后移动方向（用于近战技能朝向）
		_last_movement_direction = input_dir.normalized()
	else:
		# 停止逻辑：利用 move_toward 实现平滑减速 (惯性停车)
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		
	_set_movement_blend_position(velocity.length())
	# 6. 应用移动
	move_and_slide()
	_update_interaction_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not can_control():
		return
	if event.is_action_pressed("interact"):
		_try_interact()

#func get_gameplay_attribute_component() -> GameplayAttributeComponent:
	#return attribute_component

func get_inventory() -> InventoryComponent:
	return inventory_component

func _set_movement_blend_position(blend_position: float) -> void:
	# 通过 VisualAdapter 设置混合参数
	if is_instance_valid(_visual_adapter) and _visual_adapter.has_method("set_blend_parameter"):
		_visual_adapter.set_blend_parameter("StateMachine/movement/blend_position", blend_position)

func _try_interact() -> void:
	# 获取探测区域内所有的物体
	var bodies: Array[Area3D] = interaction_area.get_overlapping_areas() # 假设交互物也是Area3D
	if bodies.size() > 0:
		# 找到最近的一个 (简单处理：取第一个)
		var target: Area3D = bodies[0]
		# 检查目标是否有 interact 方法
		if target.has_method("interact"):
			target.interact(self)

## 组件初始化（重写基类方法）
func _init_components() -> void:
	super()
	if not is_instance_valid(player_data):
		push_error("PlayerData is not set")
		return
	attribute_component.initialize(player_data.attribute_sets, player_data.vitals)
	
	# 初始化能力组件
	# 加载初始技能列表（所有技能都通过技能系统管理，包括攻击技能）
	for ability: GameplayAbilityDefinition in player_data.initial_abilities:
		if is_instance_valid(ability):
			ability_component.learn_ability(ability)
	
	# 连接技能学会信号，自动绑定快捷键
	if not ability_component.ability_learned.is_connected(_on_ability_learned):
		ability_component.ability_learned.connect(_on_ability_learned)

## 连接快捷键管理器的信号到技能组件
func _connect_shortcut_signals() -> void:
	if not is_instance_valid(shortcut_manager) or not is_instance_valid(ability_component):
		push_warning("Player: Cannot connect shortcut signals, shortcut_manager or ability_component is not valid")
		return
	
	# 连接技能施放信号
	if not shortcut_manager.cast_ability_requested.is_connected(_on_cast_ability_requested):
		shortcut_manager.cast_ability_requested.connect(_on_cast_ability_requested)
	
	# 连接引导取消信号
	if not shortcut_manager.cancel_channeling_requested.is_connected(_on_cancel_channeling_requested):
		shortcut_manager.cancel_channeling_requested.connect(_on_cancel_channeling_requested)

## 设置快捷键绑定
func _setup_shortcuts() -> void:
	if not is_instance_valid(ability_component) or not is_instance_valid(player_data):
		return
	
	# 从 PlayerData 读取快捷键配置
	var shortcuts: Dictionary = player_data.ability_shortcuts
	if shortcuts.is_empty():
		return
	
	# 绑定已学会的技能
	var learned_abilities: Dictionary = ability_component.get_all_ability_instances()
	for ability_id: StringName in learned_abilities.keys():
		var shortcut: String = shortcuts.get(ability_id, "")
		if shortcut != "":
			shortcut_manager.bind_shortcut(ability_id, shortcut)

## 技能学会回调（自动绑定快捷键）
func _on_ability_learned(ability_id: StringName) -> void:
	if not is_instance_valid(player_data):
		return
	
	# 从 PlayerData 读取快捷键配置
	var shortcuts: Dictionary = player_data.ability_shortcuts
	var shortcut: String = shortcuts.get(ability_id, "")
	if shortcut != "":
		shortcut_manager.bind_shortcut(ability_id, shortcut)

#region ========== 双流向输入处理：朝向攻击 vs 指向攻击 ==========

## 获取鼠标在世界空间中的位置（通过射线检测）
## [return] Vector3 鼠标指向的世界位置，如果检测失败则返回角色前方位置
func get_mouse_world_position() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		# 如果没有摄像机，返回角色前方位置
		return global_position + -global_transform.basis.z * 5.0
	
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_pos)
	var ray_end: Vector3 = ray_origin + ray_direction * 2000.0
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	
	if result:
		return result.position
	else:
		# 如果射线没有命中任何物体，计算射线与地面（Y=0）的交点
		# 或者返回角色前方一定距离的位置
		var t: float = -ray_origin.y / ray_direction.y if ray_direction.y != 0 else 10.0
		return ray_origin + ray_direction * t

## 判断技能是否为远程技能（需要鼠标指向）
## 【业务层逻辑】这是业务层的判断，不应该放在框架层
## [param] ability_instance: GameplayAbilityInstance 技能数据
## [return] bool 是否为远程技能
func is_ranged_ability(ability_instance: GameplayAbilityInstance) -> bool:
	if not is_instance_valid(ability_instance):
		return false
	
	# 方案1: 通过技能标签判断（推荐，最灵活）
	# 如果技能有 "ranged" 标签，则认为是远程技能
	if ability_instance.get_definition().tags.has(&"ranged"):
		return true
	
	# 默认返回 false（保守策略）
	return false

## 重写基类的 try_cast_ability，设置鼠标位置到 context
## [param] ability_id: StringName 技能 ID
## [param] context: Dictionary 上下文信息（可选）
func try_activate_ability(ability_id: StringName, context: Dictionary = {}) -> void:
	if not can_control():
		return
	if not is_instance_valid(ability_component):
		push_warning("Player: Cannot cast ability, ability_component is not valid")
		return
	
	# 获取技能数据
	var ability_instance: GameplayAbilityInstance = ability_component.get_ability_instance(ability_id)
	if not is_instance_valid(ability_instance):
		push_warning("Player: Ability not found: %s" % ability_id)
		return
	
	context.instigator = self
	context["resolve_combat_entity"] = CombatUtils.get_entity_from_collider
	context["base_damage"] = attribute_component.get_value(&"attack")
	
	# 检查技能是否可以释放
	if not ability_component.can_activate_ability(ability_id, context):
		return
	
	# 将鼠标位置传入 context（用于目标选择等）
	# 转向逻辑已移至行为树节点（AbilityNodeFaceTarget）
	if not context.has("target_position"):
		context["target_position"] = get_mouse_world_position()
	if context["target_position"] is Vector3:
		face_point(context["target_position"] as Vector3)
	context["facing_direction"] = -visuals.global_basis.z
	
	# 调用基类方法
	super(ability_id, context)

#endregion

func _get_facing_angle() -> float:
	if is_instance_valid(visuals) and visuals is Node3D:
		return visuals.rotation.y
	return super()

## 技能完成回调
## [param] _ability_id: StringName 技能ID（未使用，保留以匹配信号签名）
func _on_ability_completed(_ability: GameplayAbilityInstance) -> void:
	_visual_adapter.play_animation("movement")


## 处理技能施放请求（信号回调）
func _on_cast_ability_requested(ability_id: StringName, _shortcut: String, context: Dictionary) -> void:
	if not is_instance_valid(ability_component):
		return
	
	# 调用技能组件的施放方法
	try_activate_ability(ability_id, context)

## 处理引导取消请求（信号回调）
## 当按键释放时，通知引导技能停止
func _on_cancel_channeling_requested(ability_id: StringName, _shortcut: String) -> void:
	if not is_instance_valid(ability_component):
		return
	
	# 获取技能实例
	var ability_instance: GameplayAbilityInstance = ability_component.get_ability_instance(ability_id)
	if not is_instance_valid(ability_instance):
		return
	
	# 检查技能是否处于激活状态（正在引导）
	if not ability_instance.is_active:
		return
	
	# 设置黑板变量，通知行为树按键已释放
	# 引导技能的行为树会通过 BTWaitSignal 监听这个信号
	var blackboard: BTBlackboard = ability_instance.get_blackboard()
	if is_instance_valid(blackboard):
		# 设置信号，触发行为树中的 BTWaitSignal
		blackboard.set_var("event_input_released", true)

func can_control() -> bool:
	var health: HealthVital = attribute_component.get_vital(&"health") as HealthVital
	return _control_locks.is_empty() and health != null and health.is_alive

func set_control_lock(reason: StringName, locked: bool) -> void:
	if locked and not _control_locks.has(reason):
		_control_locks.append(reason)
	elif not locked:
		_control_locks.erase(reason)
	if locked:
		velocity = Vector3.ZERO
		var current: GameplayAbilityInstance = ability_component.get_current_casting_ability()
		if current != null and current.is_active:
			ability_component.cancel_ability(current.get_definition().ability_id)

func face_point(point: Vector3) -> void:
	var offset: Vector3 = point - global_position
	visuals.rotation.y = atan2(offset.x, offset.z) + PI

func take_damage(amount: int) -> void:
	var health: HealthVital = attribute_component.get_vital(&"health") as HealthVital
	if not can_control() or health == null or amount <= 0:
		return
	var damage: DamageInfo = DamageInfo.new()
	damage.final_damage = float(amount)
	health.apply_damage(damage, self)

func restore_checkpoint() -> void:
	var health: HealthVital = attribute_component.get_vital(&"health") as HealthVital
	health.initialize(attribute_component)
	_is_dead = false
	_control_locks.clear()
	remove_from_group("death")
	animation_tree.active = true
	animation_state_machine.start(&"movement")

func _on_dialogue_started() -> void:
	set_control_lock(&"dialogue", true)

func _on_dialogue_finished() -> void:
	set_control_lock(&"dialogue", false)

func _update_interaction_focus() -> void:
	var selected: InteractionComponent
	if can_control():
		for area: Area3D in interaction_area.get_overlapping_areas():
			if area is InteractionComponent:
				selected = area as InteractionComponent
				break
	if selected == _focused_interaction:
		return
	if is_instance_valid(_focused_interaction):
		_focused_interaction.unfocused()
	_focused_interaction = selected
	if is_instance_valid(selected):
		selected.focused()
