extends MarginContainer
class_name AbilityButton

## 技能按钮 UI 组件
## 显示技能图标、冷却进度、快捷键等

# UI 节点引用
@onready var icon_texture: TextureRect = %IconTexture
@onready var cooldown_overlay: ColorRect = %CooldownOverlay
@onready var cooldown_progress: ProgressBar = %CooldownProgress
@onready var circular_progress: ColorRect = %CircularProgress
@onready var shortcut_label: Label = %ShortcutLabel
@onready var button: Button = %Button

# 环形进度条材质
var progress_material: ShaderMaterial = null

# 数据
var ability_id: StringName = &""
var ability_component: GameplayAbilityComponent = null
var shortcut_key: String = ""
var _last_icon: Texture = null  ## 上次显示的图标（用于避免重复更新）


func _process(_delta: float) -> void:
	# 持续更新冷却显示（用于平滑的进度条动画）
	_update_cooldown_display()
	# 定期检查并更新图标（确保连击推进时图标能及时更新）
	# 注意：_update_icon 内部会检查图标是否改变，避免重复更新
	_update_icon()

## 初始化技能按钮
## [param] comp: GameplayAbilityComponent 技能组件
## [param] id: StringName 技能 ID
## [param] shortcut: String 快捷键（如 "1", "Q", "E" 等）
func initialize(comp: GameplayAbilityComponent, id: StringName, shortcut: String = "") -> void:
	ability_component = comp
	ability_id = id
	shortcut_key = shortcut
	
	# 获取技能数据
	var ability_data = comp.get_ability_data(id)
	if not is_instance_valid(ability_data):
		push_warning("AbilityButton: Ability data not found for %s" % id)
		return
	
	# 设置图标（初始化时使用 get_icon 方法，支持连击技能和切换技能）
	var initial_icon: Texture = ability_data.get_icon(comp)
	
	if is_instance_valid(initial_icon):
		icon_texture.texture = initial_icon
		_last_icon = initial_icon
	
	# 设置快捷键标签
	if shortcut != "":
		shortcut_label.text = shortcut
		shortcut_label.visible = true
	else:
		shortcut_label.visible = false
	
	# 连接按钮点击事件
	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)
	
	# 连接技能组件信号
	if not comp.ability_cast.is_connected(_on_ability_cast):
		comp.ability_cast.connect(_on_ability_cast)
	if not comp.ability_completed.is_connected(_on_ability_completed):
		comp.ability_completed.connect(_on_ability_completed)
	if not comp.cooldown_ready.is_connected(_on_cooldown_ready):
		comp.cooldown_ready.connect(_on_cooldown_ready)
	
	# 初始化环形进度条
	_init_circular_progress()
	
	# 初始化冷却显示
	_update_cooldown_display()
	
	# 设置 tooltip
	_update_tooltip()

## 初始化环形进度条
func _init_circular_progress() -> void:
	if not is_instance_valid(circular_progress):
		return
	
	# 确保 CircularProgress 可见
	circular_progress.visible = true
	
	# 获取或创建材质
	if circular_progress.material:
		progress_material = circular_progress.material as ShaderMaterial
	else:
		# 如果没有材质，创建一个
		progress_material = ShaderMaterial.new()
		progress_material.shader = load("res://ui/shaders/circular_progress.gdshader")
		circular_progress.material = progress_material
	
	# 确保材质已正确设置
	if not is_instance_valid(progress_material):
		push_warning("AbilityButton: Failed to create progress material")
		return

## 更新技能图标
## 对于连击技能，会动态显示当前段的图标
func _update_icon() -> void:
	if not is_instance_valid(ability_component):
		return
	
	var ability_data = ability_component.get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return
	
	# 获取图标（连击技能会返回当前段的图标，切换技能会根据状态返回不同图标）
	var new_icon: Texture = ability_data.get_icon(ability_component)
	
	# 只在图标真正改变时更新（避免重复设置）
	if new_icon != _last_icon and is_instance_valid(icon_texture):
		icon_texture.texture = new_icon
		_last_icon = new_icon

## 更新冷却显示
func _update_cooldown_display() -> void:
	if not is_instance_valid(ability_component):
		return
	
	var progress = ability_component.get_cooldown_progress(ability_id)
	var is_ready = ability_component.is_cooldown_ready(ability_id)
	
	# 更新环形进度条（使用 shader）
	if is_instance_valid(progress_material) and is_instance_valid(circular_progress):
		progress_material.set_shader_parameter("progress", progress)
		# 确保 CircularProgress 可见
		circular_progress.visible = true
	
	# 更新传统进度条（向后兼容，如果存在）
	if cooldown_progress:
		cooldown_progress.value = (1.0 - progress) * 100.0
	
	# 更新冷却遮罩（可选，如果使用环形进度条可以隐藏）
	if cooldown_overlay:
		if is_ready:
			cooldown_overlay.color.a = 0.0
		else:
			# 如果使用环形进度条，可以降低遮罩透明度或隐藏
			cooldown_overlay.color.a = 0.3
	
	# 更新按钮状态
	if button:
		button.disabled = not is_ready

## 按钮点击事件
func _on_button_pressed() -> void:
	if not is_instance_valid(ability_component):
		return
	
	# 尝试施放技能（通过能力组件获取父节点）
	var entity = ability_component.get_parent()
	if is_instance_valid(entity) and entity.has_method("try_cast_ability"):
		entity.try_cast_ability(ability_id)

## 技能施放回调
func _on_ability_cast(casted_ability_id: StringName) -> void:
	if casted_ability_id == ability_id:
		_update_cooldown_display()
		# 连击技能在施放时可能已经推进到下一段，更新图标
		_update_icon()

## 技能完成回调
func _on_ability_completed(completed_ability_id: StringName) -> void:
	if completed_ability_id == ability_id:
		# 连击技能在完成时推进到下一段，更新图标
		_update_icon()

## 冷却就绪回调
func _on_cooldown_ready(ready_ability_id: StringName) -> void:
	if ready_ability_id == ability_id:
		_update_cooldown_display()

## 更新 Tooltip 显示
func _update_tooltip() -> void:
	if not is_instance_valid(ability_component):
		return
	
	var ability_data = ability_component.get_ability_data(ability_id)
	if not is_instance_valid(ability_data):
		return
	
	var tooltip_lines: Array[String] = []
	
	# 1. 技能名称
	if ability_data.ability_name != "":
		tooltip_lines.append(ability_data.ability_name)
	
	# 2. 快捷键
	if shortcut_key != "":
		tooltip_lines.append("快捷键: %s" % shortcut_key)
	
	# 3. 普通描述
	if ability_data.description != "":
		tooltip_lines.append("")
		tooltip_lines.append(ability_data.description)
	
		# 4. 消耗描述
		var costs_desc = ""
		if ability_data.has_method("get_costs_description"):
			costs_desc = ability_data.get_costs_description()
		if costs_desc != "":
			tooltip_lines.append("")
			tooltip_lines.append("消耗:")
			# 处理消耗描述，每行添加缩进
			var cost_lines = costs_desc.split("\n")
			for line in cost_lines:
				if line.strip_edges() != "":
					tooltip_lines.append("  • %s" % line.strip_edges())
		
		# 5. 效果描述
		var effects_desc = ability_data.get_effects_description()
		if effects_desc != "":
			tooltip_lines.append("")
			tooltip_lines.append("效果:")
			# 处理效果描述，每行添加缩进
			var effect_lines = effects_desc.split("\n")
			for line in effect_lines:
				if line.strip_edges() != "":
					tooltip_lines.append("  • %s" % line.strip_edges())
	
	# 设置 tooltip_text（设置在 AbilityButton 本身，而不是 Button）
	# 因为 MarginContainer 需要接收鼠标事件才能显示 tooltip
	tooltip_text = "\n".join(tooltip_lines)
