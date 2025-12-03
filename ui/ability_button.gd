extends Control
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
	
	# 设置图标
	if is_instance_valid(ability_data.icon):
		icon_texture.texture = ability_data.icon
	
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
	if not comp.cooldown_ready.is_connected(_on_cooldown_ready):
		comp.cooldown_ready.connect(_on_cooldown_ready)
	
	# 初始化环形进度条
	_init_circular_progress()
	
	# 初始化冷却显示
	_update_cooldown_display()

## 初始化环形进度条
func _init_circular_progress() -> void:
	if not is_instance_valid(circular_progress):
		return
	
	# 获取或创建材质
	if circular_progress.material:
		progress_material = circular_progress.material as ShaderMaterial
	else:
		# 如果没有材质，创建一个
		progress_material = ShaderMaterial.new()
		progress_material.shader = load("res://ui/shaders/circular_progress.gdshader")
		circular_progress.material = progress_material

## 更新冷却显示
func _update_cooldown_display() -> void:
	if not is_instance_valid(ability_component):
		return
	
	var progress = ability_component.get_cooldown_progress(ability_id)
	var is_ready = ability_component.is_cooldown_ready(ability_id)
	
	# 更新环形进度条（使用 shader）
	if is_instance_valid(progress_material):
		progress_material.set_shader_parameter("progress", progress)
	
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

## 冷却就绪回调
func _on_cooldown_ready(ready_ability_id: StringName) -> void:
	if ready_ability_id == ability_id:
		_update_cooldown_display()

func _process(_delta: float) -> void:
	# 持续更新冷却显示（用于平滑的进度条动画）
	_update_cooldown_display()
