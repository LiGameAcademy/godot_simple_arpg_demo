extends Resource
class_name DialogueTheme

# --- 面板样式 ---
@export_group("Panel")
@export var panel_style: StyleBox = null  						## 面板背景样式
@export var panel_color: Color = Color(0.1, 0.1, 0.1, 0.9)  	## 面板背景颜色
@export var panel_corner_radius: int = 10  						## 面板圆角半径

# --- 角色名样式 ---
@export_group("Character Name")
@export var name_font: Font = null
@export var name_font_size: int = 22
@export var name_color: Color = Color.WHITE
@export var name_outline_color: Color = Color.BLACK
@export var name_outline_size: int = 5

# --- 对话文本样式 ---
@export_group("Dialogue Text")
@export var text_font: Font = null
@export var text_font_size: int = 16
@export var text_color: Color = Color.WHITE
@export var text_typing_speed: float = 20.0  # 每秒字符数

# --- 选项按钮样式 ---
@export_group("Choice Buttons")
@export var choice_button_style: StyleBox = null
@export var choice_button_font: Font = null
@export var choice_button_font_size: int = 14
@export var choice_button_normal_color: Color = Color(0.2, 0.2, 0.2, 1.0)
@export var choice_button_hover_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var choice_button_pressed_color: Color = Color(0.1, 0.1, 0.1, 1.0)
@export var choice_button_corner_radius: int = 5  # 按钮圆角半径

# --- 音效 ---
@export_group("Audio")
@export var typing_sound: AudioStream = null  # 打字机音效

# --- 便捷方法：应用主题到 UI ---
## 应用主题到 DialogueUI
## [param ui] DialogueUI 实例
func apply_to_ui(ui: Node) -> void:
	if not is_instance_valid(ui):
		push_error("DialogueTheme: apply_to_ui: ui is not valid: %s" % ui)
		return
	
	# 应用面板样式
	var panel = ui.get_node_or_null("%Panel")
	_apply_panel_style(panel)

	# 应用角色名样式
	var name_label = ui.get_node_or_null("%NameLabel")
	_apply_name_style(name_label)
	
	# 应用对话文本样式
	var text_label = ui.get_node_or_null("%TextLabel")
	_apply_text_style(text_label)
	
	# 应用打字速度
	_apply_typing_speed(ui)
	
	# 应用音效
	_apply_typing_sound(ui)

func _apply_panel_style(panel: Node) -> void:
	if not is_instance_valid(panel):
		push_error("DialogueTheme: _apply_panel_style: panel is not valid: %s" % panel)
		return
	
	if panel_style:
		panel.add_theme_stylebox_override("panel", panel_style)
	else:
		var style = StyleBoxFlat.new()
		style.bg_color = panel_color
		style.corner_radius_top_left = panel_corner_radius
		style.corner_radius_top_right = panel_corner_radius
		style.corner_radius_bottom_left = panel_corner_radius

func _apply_name_style(name_label: Node) -> void:
	if not is_instance_valid(name_label):
		push_error("DialogueTheme: _apply_name_style: name_label is not valid: %s" % name_label)
		return
	
	if name_font:
		name_label.add_theme_font_override("font", name_font)
	name_label.add_theme_font_size_override("font_size", name_font_size)
	name_label.add_theme_color_override("font_color", name_color)
	name_label.add_theme_color_override("font_outline_color", name_outline_color)
	name_label.add_theme_constant_override("outline_size", name_outline_size)

func _apply_text_style(text_label: Node) -> void:
	if not is_instance_valid(text_label):
		push_error("DialogueTheme: _apply_text_style: text_label is not valid: %s" % text_label)
		return
	
	if text_font:
		text_label.add_theme_font_override("font", text_font)
	text_label.add_theme_font_size_override("font_size", text_font_size)
	text_label.add_theme_color_override("default_color", text_color)

func _apply_typing_speed(ui: Node) -> void:
	if not is_instance_valid(ui):
		push_error("DialogueTheme: _apply_typing_speed: ui is not valid: %s" % ui)
		return
	
	if ui.has_method("set_typing_speed"):
		ui.set_typing_speed(text_typing_speed)
	elif "typing_speed" in ui:
		ui.typing_speed = text_typing_speed

func _apply_typing_sound(ui: Node) -> void:
	if not is_instance_valid(ui):
		push_error("DialogueTheme: _apply_typing_sound: ui is not valid: %s" % ui)
		return
	
	if typing_sound:
		ui.get_node_or_null("TypingSoundPlayer").stream = typing_sound
