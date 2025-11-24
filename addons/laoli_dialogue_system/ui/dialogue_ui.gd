extends CanvasLayer

## 对话UI专用Canvas层

# 使用@onready，确保在访问时节点已经准备就绪
@onready var name_label: Label = %NameLabel
@onready var text_label: RichTextLabel = %TextLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var dialogue_panel: Panel = %Panel
@onready var typing_sound_player: AudioStreamPlayer = $TypingSoundPlayer

# 用于打字机效果的定时器
var typing_timer: Timer
# 控制打字速度（每秒出现的字符数）
@export var typing_speed: float = 20.0

# 【新增】主题支持
@export var theme: DialogueTheme = null

func _ready() -> void:
	# 游戏开始时，订阅DialogueManager的信号
	# 这是全局的，所以可以直接用名字访问
	DialogueManager.text_updated.connect(_on_text_updated)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	DialogueManager.choices_updated.connect(_on_choices_updated)

	# 创建并配置定时器
	typing_timer = Timer.new()
	add_child(typing_timer) # 必须把Timer添加到场景树中才能工作
	typing_timer.timeout.connect(_on_typing_timer_timeout)

	# 默认隐藏自己
	dialogue_panel.hide()

	# 应用主题
	if is_instance_valid(theme):
		theme.apply_to_ui(self)

# 处理线性对话的“继续”逻辑
func _unhandled_input(event) -> void:
	if event.is_action_pressed("ui_accept"):
		if typing_timer.is_stopped():
			# 确保对话正在进行，且当前没有选项需要玩家选择
			if not DialogueManager.is_active or choices_container.get_child_count() > 0:
				return
			
			# 【重构】使用 Resource 而不是 Dictionary
			var current_node = DialogueManager.current_node
			if current_node and not current_node.next_node_id.is_empty():
				DialogueManager.process_node(current_node.next_node_id)
			# 避免重复触发
			get_viewport().set_input_as_handled()
		else:
			# 处理打字机跳过逻辑
			typing_timer.stop()
			text_label.visible_characters = text_label.get_total_character_count()
			get_viewport().set_input_as_handled()

## 设置打字速度
## [param speed] 每秒字符数
func set_typing_speed(speed: float) -> void:
	typing_speed = speed

## 创建选项按钮时应用主题样式
## [param choice_data] 选项数据
## [return] 选项按钮
func _create_choice_button(choice_data: Dictionary) -> Button:
	var button = Button.new()
	button.text = choice_data["text"]
	
	# 应用主题样式
	if theme:
		if theme.choice_button_font:
			button.add_theme_font_override("font", theme.choice_button_font)
		button.add_theme_font_size_override("font_size", theme.choice_button_font_size)
		
		# 创建按钮样式
		if theme.choice_button_style:
			button.add_theme_stylebox_override("normal", theme.choice_button_style)
		else:
			# 如果没有提供样式，使用颜色创建简单样式
			var normal_style = StyleBoxFlat.new()
			normal_style.bg_color = theme.choice_button_normal_color
			normal_style.corner_radius_top_left = theme.choice_button_corner_radius
			normal_style.corner_radius_top_right = theme.choice_button_corner_radius
			normal_style.corner_radius_bottom_left = theme.choice_button_corner_radius
			normal_style.corner_radius_bottom_right = theme.choice_button_corner_radius
			button.add_theme_stylebox_override("normal", normal_style)
			
			var hover_style = normal_style.duplicate()
			hover_style.bg_color = theme.choice_button_hover_color
			button.add_theme_stylebox_override("hover", hover_style)
			
			var pressed_style = normal_style.duplicate()
			pressed_style.bg_color = theme.choice_button_pressed_color
			button.add_theme_stylebox_override("pressed", pressed_style)
	
	button.pressed.connect(_on_choice_pressed.bind(choice_data))
	return button

# 当收到"text_updated"信号时，这个函数会被自动调用
func _on_text_updated(character_name: String, text: String) -> void:
	dialogue_panel.show()
	name_label.text = character_name
	
	# 核心改动：
	text_label.text = text # 先把完整文本设置好
	text_label.visible_characters = 0 # 但一开始只显示0个字符
	
	# 如果有文字需要显示，就开始打字
	if not text.is_empty():
		# 根据速度和文本长度，计算出定时器的等待时间
		typing_timer.start(1.0 / typing_speed)
	
	# 清空上一轮的选项
	for child in choices_container.get_children():
		child.queue_free()

# 当收到"dialogue_finished"信号时，这个函数会被自动调用
func _on_dialogue_finished() -> void:
	dialogue_panel.hide()
	# 同样清空可能残留的选项
	for child in choices_container.get_children():
		child.queue_free()

# 当收到选项数据时，动态创建按钮
func _on_choices_updated(choices: Array) -> void:
	for choice_data in choices:
		var button = _create_choice_button(choice_data)
		choices_container.add_child(button)

# 当玩家点击某个选项按钮时
func _on_choice_pressed(choice_data: Dictionary) -> void:
	# 清空所有选项按钮，防止重复点击
	for child in choices_container.get_children():
		child.queue_free()
	# 通知 DialogueManager，玩家做出了选择
	DialogueManager.make_choice(choice_data)

func _on_typing_timer_timeout() -> void:
	# 每次定时器触发，就增加一个可见字符
	text_label.visible_characters += 1

	# 播放音效
	# 为了避免音效太吵，可以加一些判断，比如只在非空格时播放
	var current_char = text_label.text[text_label.visible_characters - 1]
	if current_char != " ":
		typing_sound_player.play()

	# 检查是否所有文字都已显示完毕
	if text_label.visible_characters >= text_label.get_total_character_count():
		typing_timer.stop() # 停止定时器
	else:
		# 如果没有显示完，就再次启动定时器，准备显示下一个字
		typing_timer.start(1.0 / typing_speed)
