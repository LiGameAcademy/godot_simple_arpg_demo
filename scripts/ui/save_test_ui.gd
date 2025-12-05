extends Control
class_name SaveTestUI

## 存档测试UI
## 用于测试对话历史和任务状态的存档功能

@onready var save_button: Button = %SaveAllButton
@onready var load_button: Button = %LoadAllButton
@onready var save_dialogue_button: Button = %SaveDialogueButton
@onready var load_dialogue_button: Button = %LoadDialogueButton
@onready var save_quest_button: Button = %SaveQuestButton
@onready var load_quest_button: Button = %LoadQuestButton
@onready var history_button: Button = %HistoryButton
@onready var status_label: Label = %StatusLabel
@onready var history_panel: Panel = %HistoryPanel
@onready var history_container: VBoxContainer = %HistoryContainer
@onready var close_history_button: Button = %CloseButton

func _ready() -> void:
	# 连接按钮信号
	save_button.pressed.connect(_on_save_all_pressed)
	load_button.pressed.connect(_on_load_all_pressed)
	save_dialogue_button.pressed.connect(_on_save_dialogue_pressed)
	load_dialogue_button.pressed.connect(_on_load_dialogue_pressed)
	save_quest_button.pressed.connect(_on_save_quest_pressed)
	load_quest_button.pressed.connect(_on_load_quest_pressed)
	history_button.pressed.connect(_on_history_pressed)
	close_history_button.pressed.connect(_on_close_history_pressed)
	
	# 初始隐藏历史面板
	history_panel.hide()
	
	# 更新状态显示
	_update_status()

func _on_save_all_pressed() -> void:
	var success = DialogueManager.save_manager.save_all()
	if success:
		_show_status("✓ 所有数据保存成功！", Color.GREEN)
	else:
		_show_status("✗ 保存失败！", Color.RED)

func _on_load_all_pressed() -> void:
	var success = DialogueManager.save_manager.load_all()
	if success:
		_show_status("✓ 所有数据加载成功！", Color.GREEN)
		_update_status()
	else:
		_show_status("✗ 加载失败！", Color.RED)

func _on_save_dialogue_pressed() -> void:
	var success = DialogueManager.save_manager.save_dialogue_history()
	if success:
		_show_status("✓ 对话历史保存成功！", Color.GREEN)
	else:
		_show_status("✗ 对话历史保存失败！", Color.RED)

func _on_load_dialogue_pressed() -> void:
	var success = DialogueManager.save_manager.load_dialogue_history()
	if success:
		_show_status("✓ 对话历史加载成功！", Color.GREEN)
		_update_status()
	else:
		_show_status("✗ 对话历史加载失败！", Color.RED)

func _on_save_quest_pressed() -> void:
	var success = DialogueManager.save_manager.save_quest_data()
	if success:
		_show_status("✓ 任务状态保存成功！", Color.GREEN)
	else:
		_show_status("✗ 任务状态保存失败！", Color.RED)

func _on_load_quest_pressed() -> void:
	var success = DialogueManager.save_manager.load_quest_data()
	if success:
		_show_status("✓ 任务状态加载成功！", Color.GREEN)
		_update_status()
	else:
		_show_status("✗ 任务状态加载失败！", Color.RED)

func _on_history_pressed() -> void:
	_show_history()
	history_panel.show()

func _on_close_history_pressed() -> void:
	history_panel.hide()

func _show_status(message: String, color: Color = Color.WHITE) -> void:
	status_label.text = message
	status_label.modulate = color
	
	# 3秒后清除状态
	await get_tree().create_timer(3.0).timeout
	if status_label.text == message:
		status_label.text = ""
		status_label.modulate = Color.WHITE

func _update_status() -> void:
	# 这个方法可以用于更新状态显示
	# 目前状态信息在按钮操作后通过 _show_status 显示
	pass

func _show_history() -> void:
	# 清空现有条目
	for child in history_container.get_children():
		child.queue_free()
	
	# 获取对话历史
	var history = DialogueHistoryManager.get_history()
	
	if history.is_empty():
		var empty_label = Label.new()
		empty_label.text = "暂无对话历史"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		history_container.add_child(empty_label)
		return
	
	# 创建历史条目
	for entry in history:
		var entry_panel = _create_history_entry(entry)
		history_container.add_child(entry_panel)

func _create_history_entry(entry: DialogueHistoryEntry) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 100)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)
	
	# 角色名称和时间戳
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var name_label = Label.new()
	name_label.text = entry.character_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.CYAN)
	header.add_child(name_label)
	
	header.add_child(Control.new())  # 占位符
	
	var time_label = Label.new()
	var time_str = _format_timestamp(entry.timestamp)
	time_label.text = time_str
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", Color.GRAY)
	header.add_child(time_label)
	
	# 对话文本
	var text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.text = entry.dialogue_text
	text_label.custom_minimum_size = Vector2(0, 50)
	text_label.scroll_following = false
	vbox.add_child(text_label)
	
	# 选择的选项（如果有）
	if not entry.selected_choice.is_empty():
		var choice_label = Label.new()
		choice_label.text = "选择：%s" % entry.selected_choice
		choice_label.add_theme_font_size_override("font_size", 12)
		choice_label.add_theme_color_override("font_color", Color.YELLOW)
		vbox.add_child(choice_label)
	
	# 已读标记
	if entry.is_read:
		var read_label = Label.new()
		read_label.text = "已读"
		read_label.add_theme_font_size_override("font_size", 10)
		read_label.add_theme_color_override("font_color", Color.GREEN)
		vbox.add_child(read_label)
	
	return panel

func _format_timestamp(timestamp: float) -> String:
	var date = Time.get_datetime_dict_from_unix_time(int(timestamp))
	return "%02d:%02d:%02d" % [date.hour, date.minute, date.second]
