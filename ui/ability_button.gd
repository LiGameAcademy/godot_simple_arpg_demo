extends MarginContainer
class_name AbilityButton

## 技能按钮 UI 组件 (适配 GAS Instance 架构)
## 职责：
## 1. 绑定特定的 GameplayAbilityInstance
## 2. 每帧从 CooldownFeature 读取进度
## 3. 组装 Feature 描述生成 Tooltip

#region ========== UI 节点引用 ==========
@onready var icon_texture: TextureRect = %IconTexture
@onready var cooldown_overlay: ColorRect = %CooldownOverlay
@onready var cooldown_progress_bar: ProgressBar = %CooldownProgress
@onready var circular_progress: ColorRect = %CircularProgress
@onready var shortcut_label: Label = %ShortcutLabel
@onready var button: Button = %Button
#endregion

#region ========== 内部变量 ==========
# 核心引用
var _component: GameplayAbilityComponent = null
var _instance: GameplayAbilityInstance = null

# 缓存特性引用 (性能优化，避免每帧查找)
var _cached_cooldown_feature: CooldownFeature = null

# 状态
var _ability_id: StringName = &""
var _shortcut_key: String = ""
var _progress_material: ShaderMaterial = null
var _last_icon: Texture = null
#endregion

#region ========== 生命周期 ==========

func _exit_tree() -> void:
	# 清理信号连接
	if is_instance_valid(_instance):
		if _instance.ability_completed.is_connected(_on_ability_completed):
			_instance.ability_completed.disconnect(_on_ability_completed)
		if _instance.ability_data_changed.is_connected(_on_ability_data_changed):
			_instance.ability_data_changed.disconnect(_on_ability_data_changed)
			
	if is_instance_valid(_component):
		if _component.ability_activated.is_connected(_on_ability_activated):
			_component.ability_activated.disconnect(_on_ability_activated)

func _process(_delta: float) -> void:
	if not is_instance_valid(_instance):
		set_process(false)
		return
		
	# 持续更新冷却显示
	_update_cooldown_display()
	
#endregion

#region ========== 初始化 ==========

## 初始化技能按钮
func initialize(comp: GameplayAbilityComponent, id: StringName, shortcut: String = "") -> void:
	_component = comp
	_ability_id = id
	_shortcut_key = shortcut
	
	# 1. 获取技能实例
	_instance = comp.get_ability_instance(id) # 以前是 get_ability_data
	
	if not is_instance_valid(_instance):
		push_warning("AbilityButton: Ability Instance not found for %s" % id)
		visible = false # 或者显示一个禁用状态
		set_process(false)
		return
	
	# 2. 缓存关键特性 (查找名为 "CooldownFeature" 的特性)
	# 如果你的特性改名了，这里需要同步，或者遍历查找类型为 CooldownFeature 的特性
	if _instance.has_feature("CooldownFeature"):
		_cached_cooldown_feature = _instance.get_feature("CooldownFeature") as CooldownFeature
	
	# 3. 初始化 UI 状态
	_update_icon(true) # 强制更新一次
	_init_shortcut_label()
	_init_circular_progress()
	_update_cooldown_display()
	_update_tooltip() # 生成动态 Tooltip
	
	# 4. 连接信号
	button.pressed.connect(_on_button_pressed)
	
	# 监听 Component 的激活信号 (用于立即响应按键反馈)
	if not comp.ability_activated.is_connected(_on_ability_activated):
		comp.ability_activated.connect(_on_ability_activated)
	
	# 监听 Instance 的完成信号 (用于刷新连击图标)
	if not _instance.ability_completed.is_connected(_on_ability_completed):
		_instance.ability_completed.connect(_on_ability_completed)
	
	# 监听 Instance 的数据改变信号 (用于更新连击图标)
	if not _instance.ability_data_changed.is_connected(_on_ability_data_changed):
		_instance.ability_data_changed.connect(_on_ability_data_changed)
	
	set_process(true)

func _init_shortcut_label() -> void:
	if _shortcut_key != "":
		shortcut_label.text = _shortcut_key
		shortcut_label.visible = true
	else:
		shortcut_label.visible = false

func _init_circular_progress() -> void:
	if not is_instance_valid(circular_progress): return
	
	circular_progress.visible = true
	if circular_progress.material:
		_progress_material = circular_progress.material as ShaderMaterial
	else:
		_progress_material = ShaderMaterial.new()
		# 确保这个 shader 路径是正确的
		_progress_material.shader = load("res://ui/shaders/circular_progress.gdshader")
		circular_progress.material = _progress_material

#endregion

#region ========== 状态更新 ==========

func _update_icon(force: bool = false) -> void:
	# 优先从 Definition 获取基础图标
	var current_icon = _instance.get_current_icon()
	
	if force or current_icon != _last_icon:
		if is_instance_valid(icon_texture):
			icon_texture.texture = current_icon
		_last_icon = current_icon

func _update_cooldown_display() -> void:
	var progress = 0.0
	var is_ready = true
	
	# 从缓存的 CooldownFeature 读取状态
	# 注意：必须传入 _instance，因为 Feature 是无状态的享元
	if is_instance_valid(_cached_cooldown_feature):
		progress = _cached_cooldown_feature.get_cooldown_progress(_instance)
		is_ready = _cached_cooldown_feature.is_cooldown_ready(_instance)
	
	# 更新 Shader
	if is_instance_valid(_progress_material):
		_progress_material.set_shader_parameter("progress", progress)
	
	# 更新传统进度条
	if cooldown_progress_bar:
		cooldown_progress_bar.value = (1.0 - progress) * 100.0
	
	# 更新遮罩和按钮状态
	if cooldown_overlay:
		cooldown_overlay.visible = not is_ready
		
	if button:
		# 只有当不可用且未激活时才禁用 (防止打断连击手感)
		# 也可以选择永远不 disabled，只变灰，让 try_activate 反馈失败
		# button.disabled = not is_ready 
		pass

func _update_tooltip() -> void:
	if not is_instance_valid(_instance): return
	
	var def = _instance.get_definition()
	var lines: Array[String] = []
	
	# 1. 标题
	lines.append(def.display_name if "display_name" in def else _ability_id)
	
	# 2. 快捷键
	if _shortcut_key != "":
		lines.append("[color=yellow]快捷键: %s[/color]" % _shortcut_key)
	
	# 3. 描述
	if def.description != "":
		lines.append("")
		lines.append(def.description)
	
	# 4. 遍历特性获取详细描述 (动态生成)
	# 需要 Feature 基类实现 get_description()
	var features_desc: Array[String] = []
	for feature in _instance.get_all_features().values():
		if not is_instance_valid(feature): continue
		
		# 过滤掉空的描述
		var f_desc = feature.get_description()
		if f_desc != "":
			features_desc.append(f_desc)
	
	if not features_desc.is_empty():
		lines.append("")
		lines.append("[color=gray]详细属性:[/color]")
		for desc in features_desc:
			lines.append(" • %s" % desc)
			
	tooltip_text = "\n".join(lines)

#endregion

#region ========== 交互回调 ==========

func _on_button_pressed() -> void:
	if not is_instance_valid(_component): return
	
	# 使用新的 Component API
	_component.try_activate_ability(_ability_id)

func _on_ability_activated(ability_inst: GameplayAbilityInstance) -> void:
	if ability_inst == _instance:
		_update_cooldown_display()
		# 这里可以播放一个点击动画，比如缩放一下

func _on_ability_completed(ability_inst: GameplayAbilityInstance) -> void:
	if ability_inst == _instance:
		_update_icon() # 连击结束可能重置图标

func _on_ability_data_changed(ability_inst: GameplayAbilityInstance) -> void:
	if ability_inst == _instance:
		_update_tooltip()
		_update_icon()

#endregion
