extends CharacterBase
class_name Player

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
## 是否允许远程技能时自动转向鼠标方向
@export var auto_face_mouse_for_ranged: bool = true
## 远程技能转向速度（如果为0则使用 rotation_speed）
@export var ranged_rotation_speed: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var interaction_area: Area3D = $Visuals/InteractionArea
@onready var inventory_component: C_Inventory = $InventoryComponent

@onready var hand_slot_attachment_r: BoneAttachment3D = $Visuals/Barbarian/Rig_Medium/Skeleton3D/HandSlotAttachmentR
@onready var hand_slot_attachment_l: BoneAttachment3D = $Visuals/Barbarian/Rig_Medium/Skeleton3D/HandSlotAttachmentL

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
## 属性点数管理器
var attribute_points_manager: AttributePointsManager = AttributePointsManager.new(10)
## 技能快捷键管理器
var shortcut_manager: AbilityShortcutManager = AbilityShortcutManager.new()
## 最后移动方向（用于近战技能朝向）
var _last_movement_direction: Vector2 = Vector2(0, 1)
## 是否应该持续转向鼠标（用于远程技能平滑转向）
var _should_face_mouse: bool = false
## 已应用的装备属性修改器（用于卸下时移除）
## 格式：{装备槽名称: [修改器1, 修改器2, ...]}
var _equipment_modifiers: Dictionary = {}
## 已显示的装备模型实例（用于卸下时移除）
## 格式：{装备槽名称: Node3D实例}
var _equipment_models: Dictionary = {}
## 已注册的装备技能（用于卸下时移除）
## 格式：{装备槽名称: [技能ID1, 技能ID2, ...]}
var _equipment_abilities: Dictionary = {}

func _ready() -> void:
	super()
	
	# 将快捷键管理器添加到场景树，使其能够接收 _unhandled_input
	if not shortcut_manager.is_inside_tree():
		add_child(shortcut_manager)
	
	# 播放初始动画（通过 VisualAdapter）
	if is_instance_valid(_visual_adapter):
		_visual_adapter.play_animation("movement")
	
	# 【测试福利】送 3 瓶药水
	var potion = load("res://data/items/potion_health_small.tres")
	if potion:
		for i in range(3):
			inventory_component.add_item(potion.duplicate())
	
	# 【测试福利】添加武器：斧子和法杖
	var axe = load("res://data/items/axe.tres")
	if axe:
		inventory_component.add_item(axe.duplicate())
	
	var staff = load("res://data/items/staff.tres")
	if staff:
		inventory_component.add_item(staff.duplicate())
	
	# 初始化快捷键绑定（在技能学会后绑定）
	_setup_shortcuts()
	
	# 连接快捷键管理器的信号到技能组件
	_connect_shortcut_signals()
	
	# 监听技能完成信号，清除转向标志
	if is_instance_valid(ability_component):
		ability_component.ability_completed.connect(_on_ability_completed)
	
	# 监听装备变化信号，应用/移除属性修改器
	if is_instance_valid(inventory_component):
		inventory_component.equip_changed.connect(_on_equip_changed)

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
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 2. 转换为 3D 方向 (X/Z 平面)
	# 注意：模型朝向 -Z（Godot 默认前方）
	# - input_dir.x 是左右（对应 3D 的 X 轴，正值为右）
	# - input_dir.y 是前后（对应 3D 的 Z 轴，正值为前，但在 2D 输入映射中是 Y）
	# 当 input_dir.y = 1（向上键，向前）时，应该朝向 -Z
	# 所以需要取反：Vector3(input_dir.x, 0, -input_dir.y)
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction:
		# 3. 移动逻辑：利用 move_toward 实现平滑加速
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
		
		# 4. 旋转逻辑：根据状态选择转向目标
		if _should_face_mouse and auto_face_mouse_for_ranged:
			# 远程技能模式：平滑转向鼠标方向
			face_mouse_direction(delta, false)
		else:
			# 正常移动模式：平滑转向移动方向
			# 注意：模型朝向 -Z（Godot 默认前方）
			# - input_dir.x 是左右（对应 3D 的 X 轴，正值为右）
			# - input_dir.y 是前后（对应 3D 的 Z 轴，正值为前，但在 2D 输入映射中是 Y）
			# 当 input_dir.y = 1（向上键，向前）时，应该朝向 -Z
			# 由于模型从 +Z 改为 -Z（旋转了 180 度），角度需要加 π
			var base_angle = atan2(input_dir.x, input_dir.y)
			var target_angle = base_angle + PI
			visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, rotation_speed * delta)
		
		# 保存最后移动方向（用于近战技能朝向）
		_last_movement_direction = input_dir.normalized()
	else:
		# 停止逻辑：利用 move_toward 实现平滑减速 (惯性停车)
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		
		# 如果没有移动输入，但需要转向鼠标，继续转向
		if _should_face_mouse and auto_face_mouse_for_ranged:
			face_mouse_direction(delta, false)
		
	_set_movement_blend_position(velocity.length())
	# 6. 应用移动
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()

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
	# 加载初始技能列表（所有技能都通过技能系统管理，包括攻击技能）
	for ability in player_data.initial_abilities:
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
	var shortcuts = player_data.ability_shortcuts
	if shortcuts.is_empty():
		return
	
	# 绑定已学会的技能
	var learned_abilities = ability_component.get_all_learned_abilities()
	for ability_id in learned_abilities.keys():
		var shortcut = shortcuts.get(ability_id, "")
		if shortcut != "":
			shortcut_manager.bind_shortcut(ability_id, shortcut)

## 技能学会回调（自动绑定快捷键）
func _on_ability_learned(ability_id: StringName) -> void:
	if not is_instance_valid(player_data):
		return
	
	# 从 PlayerData 读取快捷键配置
	var shortcuts = player_data.ability_shortcuts
	var shortcut = shortcuts.get(ability_id, "")
	if shortcut != "":
		shortcut_manager.bind_shortcut(ability_id, shortcut)

#region ========== 双流向输入处理：朝向攻击 vs 指向攻击 ==========

## 获取鼠标在世界空间中的位置（通过射线检测）
## [return] Vector3 鼠标指向的世界位置，如果检测失败则返回角色前方位置
func get_mouse_world_position() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		# 如果没有摄像机，返回角色前方位置
		return global_position + -global_transform.basis.z * 5.0
	
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var ray_end := ray_origin + ray_direction * 2000.0
	
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	
	if result:
		return result.position
	else:
		# 如果射线没有命中任何物体，计算射线与地面（Y=0）的交点
		# 或者返回角色前方一定距离的位置
		var t := -ray_origin.y / ray_direction.y if ray_direction.y != 0 else 10.0
		return ray_origin + ray_direction * t

## 计算从角色到鼠标位置的方向角度
## [return] float 角度（弧度），如果无法计算则返回当前朝向
## 注意：这个角度应该与 visuals 节点的旋转系统一致
func get_angle_to_mouse() -> float:
	var mouse_world_pos := get_mouse_world_position()
	var direction := mouse_world_pos - global_position
	direction.y = 0.0  # 只考虑水平方向
	
	if direction.length_squared() < 0.01:
		# 如果鼠标位置太近，返回当前朝向
		return _get_facing_angle()
	
	direction = direction.normalized()
	
	# 计算角度：需要与 _physics_process 中的角度计算保持一致
	# 在 _physics_process 中使用 atan2(input_dir.x, input_dir.y) + PI
	# 其中：
	#   - input_dir.x 是左右（对应 3D 的 X 轴，正值为右）
	#   - input_dir.y 是前后（对应 3D 的 Z 轴，正值为前，但在 2D 输入映射中是 Y）
	# 在 3D 世界中：
	#   - direction.x 对应 input_dir.x（左右）
	#   - direction.z 对应 input_dir.y（前后）
	# 注意：模型朝向 -Z，所以需要计算从角色到鼠标的角度，然后加 π 以匹配 visuals.rotation.y 的角度系统
	var base_angle = atan2(direction.x, direction.z)
	var angle = base_angle + PI
	
	# 调试：输出详细信息
	print("Player: get_angle_to_mouse - direction: %s, angle: %.2f rad (%.1f deg)" % [
		direction,
		angle,
		rad_to_deg(angle)
	])
	
	return angle

## 判断技能是否为远程技能（需要鼠标指向）
## 【业务层逻辑】这是业务层的判断，不应该放在框架层
## [param] ability: GameplayAbility 技能数据
## [return] bool 是否为远程技能
func is_ranged_ability(ability: GameplayAbility) -> bool:
	if not is_instance_valid(ability):
		return false
	
	# 方案1: 通过技能标签判断（推荐，最灵活）
	# 如果技能有 "ranged" 标签，则认为是远程技能
	if ability.tags.has(&"ranged"):
		return true
	
	# 方案2: 通过 TargetingStrategy 类型判断（备选方案）
	# 注意：这是业务层的判断逻辑，基于策略类型
	if ability is ActiveAbility:
		var active_ability = ability as ActiveAbility
		if is_instance_valid(active_ability.targeting_strategy):
			# 根据策略类型判断：UnitTargetingStrategy 和 GroundTargetingStrategy 通常需要鼠标指向
			var strategy = active_ability.targeting_strategy
			if strategy is UnitTargetingStrategy or strategy is GroundTargetingStrategy:
				return true
	
	# 默认返回 false（保守策略）
	return false

## 让角色转向鼠标方向（用于远程技能）
## [param] delta: float 帧时间
## [param] instant: bool 是否立即转向（不插值）
func face_mouse_direction(delta: float, instant: bool = false) -> void:
	if not is_instance_valid(visuals):
		push_warning("Player: Cannot face mouse direction, visuals is not valid")
		return
	
	var target_angle := get_angle_to_mouse()
	
	# 调试：输出角度信息
	print("Player: face_mouse_direction - target_angle: %.2f rad (%.1f deg), current: %.2f rad (%.1f deg)" % [
		target_angle,
		rad_to_deg(target_angle),
		visuals.rotation.y,
		rad_to_deg(visuals.rotation.y)
	])
	
	if instant:
		visuals.rotation.y = target_angle
		print("Player: Instantly rotated to %.2f rad (%.1f deg)" % [target_angle, rad_to_deg(target_angle)])
	else:
		var rot_speed := ranged_rotation_speed if ranged_rotation_speed > 0.0 else rotation_speed
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, rot_speed * delta)

## 重写基类的 try_cast_ability，实现双流向输入处理
## [param] ability_id: StringName 技能 ID
## [param] target: Node 目标节点（可选）
## [param] context: Dictionary 上下文信息（可选）
func try_cast_ability(ability_id: StringName, target: Node = null, context: Dictionary = {}) -> void:
	if not is_instance_valid(ability_component):
		push_warning("Player: Cannot cast ability, ability_component is not valid")
		return
	
	# 获取技能数据
	var ability := ability_component.get_ability_data(ability_id)
	if not is_instance_valid(ability):
		push_warning("Player: Ability not found: %s" % ability_id)
		return
	
	# 【重要】先检查技能是否可以释放，如果无法释放（如CD中），不设置转向标志
	if not ability_component.can_cast(ability_id, target, context):
		# 无法释放，清除转向标志（如果之前设置了）
		_should_face_mouse = false
		return
	
	# 判断技能类型并处理朝向（只有在可以释放时才设置）
	var is_ranged := is_ranged_ability(ability)
	if is_ranged and auto_face_mouse_for_ranged:
		# 远程技能：设置持续转向标志，在 _physics_process 中持续处理
		_should_face_mouse = true
		
		# 获取鼠标位置和目标角度
		var mouse_pos = get_mouse_world_position()
		var target_angle = get_angle_to_mouse()
		
		# 将鼠标位置和目标角度传入 context
		# 这样技能会朝鼠标方向发射，即使角色还在转向中
		context["target_position"] = mouse_pos
		context["facing_angle"] = target_angle
		
		# 同时传递方向向量（方便投射物系统使用）
		var facing_direction = Vector3(-sin(target_angle), 0.0, -cos(target_angle))
		context["facing_direction"] = facing_direction
	else:
		# 近战技能：清除转向标志，使用当前朝向
		_should_face_mouse = false
		var mouse_pos = get_mouse_world_position()
		context["target_position"] = mouse_pos
		context["facing_angle"] = _get_facing_angle()
	
	# 调用基类方法（此时已经确认可以释放）
	super(ability_id, target, context)

#endregion

func _get_facing_angle() -> float:
	if is_instance_valid(visuals) and visuals is Node3D:
		return visuals.rotation.y
	return super()

## 技能完成回调（清除转向标志）
## [param] ability_id: StringName 技能ID
func _on_ability_completed(ability_id: StringName) -> void:
	# 检查是否是远程技能
	if is_instance_valid(ability_component):
		var ability = ability_component.get_ability_data(ability_id)
		if is_instance_valid(ability) and is_ranged_ability(ability):
			# 远程技能完成，清除转向标志
			_should_face_mouse = false
	_visual_adapter.play_animation("movement")

#region ========== 装备属性系统 ==========

## 装备变化回调
## [param] equip_slot_name: StringName 装备槽名称
## [param] equip: Equip 装备实例（如果为 null，表示卸下装备）
## 注意：实际传入的应该是 GameplayEquip 实例（业务层装备类）
func _on_equip_changed(equip_slot_name: StringName, equip: Equip) -> void:
	if not is_instance_valid(attribute_component):
		push_warning("Player: Cannot apply equipment attributes, attribute_component is not valid")
		return
	
	# 如果是卸下装备（equip 为 null），移除旧装备的属性修改器、模型和技能
	if equip == null:
		_remove_equipment_modifiers(equip_slot_name)
		_remove_equipment_model(equip_slot_name)
		_remove_equipment_abilities(equip_slot_name)
		return
	
	# 如果是替换装备，先移除旧装备的属性修改器、模型和技能
	_remove_equipment_modifiers(equip_slot_name)
	_remove_equipment_model(equip_slot_name)
	_remove_equipment_abilities(equip_slot_name)
	
	# 应用新装备的属性修改器、模型和技能
	_apply_equipment_modifiers(equip, equip_slot_name)
	_apply_equipment_model(equip, equip_slot_name)
	_apply_equipment_abilities(equip, equip_slot_name)

## 应用装备的属性修改器
## [param] equip: Equip 装备实例（实际应为 GameplayEquip）
## [param] equip_slot_name: StringName 装备槽名称
func _apply_equipment_modifiers(equip: Equip, equip_slot_name: StringName) -> void:
	if not is_instance_valid(equip) or not is_instance_valid(attribute_component):
		return
	
	# 获取装备的属性字典
	var attributes = equip.attributes
	if attributes.is_empty():
		return
	
	# 存储该装备的所有修改器
	var modifiers: Array[GameplayAttributeModifier] = []
	
	# 遍历装备的所有属性，创建修改器
	for attr_name in attributes.keys():
		var attr_value = attributes[attr_name]
		if attr_value == 0.0:
			continue
		
		# 创建属性修改器（使用 ADD 类型，直接加到基础值上）
		var modifier = GameplayAttributeModifier.new()
		modifier.attribute_id = StringName(attr_name)
		modifier.value = attr_value
		modifier.modifier_type = GameplayAttributeModifier.ModifierType.ADD
		modifier.source = self
		
		# 检查属性是否存在
		if not attribute_component.has_attribute(modifier.attribute_id):
			push_warning("Player: Attribute '%s' not found in attribute_component, skipping equipment modifier" % attr_name)
			continue
		
		# 应用修改器
		attribute_component.add_modifier(modifier)
		modifiers.append(modifier)
		
		print("Player: Applied equipment modifier - %s: +%.1f (from %s)" % [attr_name, attr_value, equip.name])
	
	# 存储修改器（使用装备槽名称作为键，因为同一槽位只能有一个装备）
	if not modifiers.is_empty():
		_equipment_modifiers[equip_slot_name] = modifiers

## 移除装备的属性修改器
## [param] equip_slot_name: StringName 装备槽名称
func _remove_equipment_modifiers(equip_slot_name: StringName) -> void:
	if not _equipment_modifiers.has(equip_slot_name):
		return
	
	if not is_instance_valid(attribute_component):
		# 如果属性组件已销毁，直接清除记录
		_equipment_modifiers.erase(equip_slot_name)
		return
	
	# 获取该装备槽的所有修改器
	var modifiers = _equipment_modifiers[equip_slot_name]
	
	# 移除所有修改器
	for modifier in modifiers:
		if is_instance_valid(modifier):
			attribute_component.remove_modifier(modifier)
			print("Player: Removed equipment modifier - %s: %.1f" % [modifier.attribute_id, modifier.value])
	
	# 清除记录
	_equipment_modifiers.erase(equip_slot_name)

## 应用装备模型
## [param] equip: Equip 装备实例（实际应为 GameplayEquip）
## [param] equip_slot_name: StringName 装备槽名称
func _apply_equipment_model(equip: Equip, equip_slot_name: StringName) -> void:
	# 检查是否为 GameplayEquip 实例（业务层装备类）
	if not equip is GameplayEquip:
		# 如果不是 GameplayEquip，说明没有装备模型配置，直接返回
		return
	
	var gameplay_equip = equip as GameplayEquip
	if not is_instance_valid(gameplay_equip) or not is_instance_valid(gameplay_equip.equip_model_scene):
		return
	
	# 获取装备的挂点名称（默认为 hand_right）
	var attachment_point = gameplay_equip.attachment_point
	if attachment_point == &"":
		attachment_point = &"hand_right"
	
	# 根据挂点名称获取对应的 BoneAttachment3D 节点
	var attachment_node: BoneAttachment3D = null
	match attachment_point:
		&"hand_right":
			attachment_node = hand_slot_attachment_r
		&"hand_left":
			attachment_node = hand_slot_attachment_l
		_:
			# 尝试从 _attachment_point_mapping 中查找（如果基类有的话）
			if has_method("get_attachment_point"):
				var point = get_attachment_point(attachment_point)
				if is_instance_valid(point) and point is BoneAttachment3D:
					attachment_node = point as BoneAttachment3D
	
	if not is_instance_valid(attachment_node):
		push_warning("Player: Attachment point '%s' not found for equipment '%s'" % [attachment_point, equip.name])
		return
	
	# 实例化装备模型
	var model_instance = gameplay_equip.equip_model_scene.instantiate()
	if not is_instance_valid(model_instance):
		push_warning("Player: Failed to instantiate equipment model for '%s'" % gameplay_equip.name)
		return
	
	# 添加到挂点节点
	attachment_node.add_child(model_instance)
	_equipment_models[equip_slot_name] = model_instance
	
	print("Player: Applied equipment model '%s' to attachment point '%s'" % [gameplay_equip.name, attachment_point])

## 移除装备模型
## [param] equip_slot_name: StringName 装备槽名称
func _remove_equipment_model(equip_slot_name: StringName) -> void:
	if not _equipment_models.has(equip_slot_name):
		return
	
	var model_instance = _equipment_models[equip_slot_name]
	if is_instance_valid(model_instance):
		model_instance.queue_free()
		print("Player: Removed equipment model from slot '%s'" % equip_slot_name)
	
	# 清除记录
	_equipment_models.erase(equip_slot_name)

## 应用装备技能
## [param] equip: Equip 装备实例（实际应为 GameplayEquip）
## [param] equip_slot_name: StringName 装备槽名称
func _apply_equipment_abilities(equip: Equip, equip_slot_name: StringName) -> void:
	# 检查是否为 GameplayEquip 实例
	if not equip is GameplayEquip:
		return
	
	var gameplay_equip = equip as GameplayEquip
	if not is_instance_valid(gameplay_equip) or not is_instance_valid(ability_component):
		return
	
	# 获取装备的技能列表
	var abilities = gameplay_equip.abilities
	if abilities.is_empty():
		return
	
	# 存储该装备的所有技能ID
	var ability_ids: Array[StringName] = []
	
	# 遍历装备的所有技能，注册到技能组件
	for ability_data in abilities:
		if not is_instance_valid(ability_data):
			continue
		
		var ability_id = ability_data.ability_id
		if ability_id == &"":
			push_warning("Player: Equipment ability has empty ability_id, skipping")
			continue
		
		# 学习技能
		ability_component.learn_ability(ability_data)
		ability_ids.append(ability_id)
		
		print("Player: Learned ability '%s' from equipment '%s'" % [ability_id, gameplay_equip.name])
	
	# 存储技能ID列表（用于卸下时移除）
	if not ability_ids.is_empty():
		_equipment_abilities[equip_slot_name] = ability_ids

## 移除装备技能
## [param] equip_slot_name: StringName 装备槽名称
func _remove_equipment_abilities(equip_slot_name: StringName) -> void:
	if not _equipment_abilities.has(equip_slot_name):
		return
	
	if not is_instance_valid(ability_component):
		# 如果技能组件已销毁，直接清除记录
		_equipment_abilities.erase(equip_slot_name)
		return
	
	# 获取该装备槽的所有技能ID
	var ability_ids = _equipment_abilities[equip_slot_name]
	
	# 遗忘所有技能
	for ability_id in ability_ids:
		ability_component.forget_ability(ability_id)
		print("Player: Forgot ability '%s' from equipment slot '%s'" % [ability_id, equip_slot_name])
	
	# 清除记录
	_equipment_abilities.erase(equip_slot_name)

#endregion

## 处理技能施放请求（信号回调）
func _on_cast_ability_requested(ability_id: StringName, _shortcut: String, context: Dictionary) -> void:
	if not is_instance_valid(ability_component):
		return
	
	# 调用技能组件的施放方法
	try_cast_ability(ability_id, null, context)

## 处理引导取消请求（信号回调）
func _on_cancel_channeling_requested(ability_id: StringName, _shortcut: String) -> void:
	if not is_instance_valid(ability_component):
		return
	
	# 检查是否是当前正在执行的技能
	var current_ability_id = ability_component.get_current_casting_ability_id()
	if current_ability_id != ability_id:
		return
	
	# 检查是否是引导技能且应该取消（按住维持式）
	var ability_data = ability_component.get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return
	
	# 检查是否是 ChannelingAbility 且 stop_on_input_release 为 true（按住维持式）
	if ability_data is ChannelingAbility:
		var channeling_ability = ability_data as ChannelingAbility
		if channeling_ability.stop_on_input_release:
			ability_component.cancel_ability(ability_id)
