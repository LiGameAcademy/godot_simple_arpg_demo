extends MarginContainer
class_name TalentButton

## 天赋按钮 UI 组件
## 显示天赋图标、名称、状态（已学/可学/锁定）、消耗点数等

# UI 节点引用
@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel
@onready var cost_label: Label = %CostLabel
@onready var button: Button = %Button
@onready var locked_overlay: ColorRect = %LockedOverlay
@onready var learned_indicator: ColorRect = %LearnedIndicator

# 数据
var talent_data: TalentData = null

signal talent_button_pressed(talent: TalentData)

func _ready() -> void:
	TalentManager.talent_points_changed.connect(_on_points_changed)
	TalentManager.talent_learned.connect(_on_talent_learned)
	
	# 连接按钮点击事件
	if is_instance_valid(button):
		button.pressed.connect(_on_button_pressed)

## 初始化天赋按钮
## [param] talent: TalentData 天赋数据
func initialize(talent: TalentData) -> void:
	talent_data = talent
	
	if not is_instance_valid(talent_data):
		push_warning("TalentButton: Talent data is not valid")
		return
	
	# 设置图标
	if is_instance_valid(icon_texture) and is_instance_valid(talent_data.icon):
		icon_texture.texture = talent_data.icon
	
	# 设置名称
	if is_instance_valid(name_label):
		name_label.text = talent_data.display_name
	
	# 设置消耗点数
	if is_instance_valid(cost_label):
		cost_label.text = str(talent_data.cost)
	
	# 设置 tooltip
	tooltip_text = _build_tooltip()
	
	# 更新状态显示
	_update_state()

## 构建 Tooltip 文本
func _build_tooltip() -> String:
	if not is_instance_valid(talent_data):
		return ""
	
	var lines: Array[String] = []
	
	# 1. 天赋名称
	if talent_data.display_name != "":
		lines.append(talent_data.display_name)
	
	# 2. 消耗点数
	lines.append("消耗: %d 天赋点" % talent_data.cost)
	
	# 3. 描述
	if talent_data.description != "":
		lines.append("")
		lines.append(talent_data.description)
	
	# 4. 前置天赋
	if not talent_data.prerequisites.is_empty():
		lines.append("")
		lines.append("前置天赋:")
		for pre_id in talent_data.prerequisites:
			lines.append("  • %s" % pre_id)
	
	# 5. 状态
	var status = _get_talent_status()
	match status:
		"learned":
			lines.append("")
			lines.append("✓ 已学会")
		"can_learn":
			lines.append("")
			lines.append("可学习")
		"locked":
			lines.append("")
			lines.append("锁定（前置未满足）")
		"insufficient_points":
			lines.append("")
			lines.append("点数不足")
	
	return "\n".join(lines)

## 获取天赋状态
## [return] String "learned" | "can_learn" | "locked" | "insufficient_points"
func _get_talent_status() -> String:
	if not is_instance_valid(talent_data):
		return "locked"
	
	if TalentManager.is_learned(talent_data.talent_id):
		return "learned"
	
	if not TalentManager.can_learn(talent_data):
		# 检查是前置未满足还是点数不足
		if TalentManager.available_points < talent_data.cost:
			return "insufficient_points"
		return "locked"
	
	return "can_learn"

## 更新按钮状态显示
func _update_state() -> void:
	if not is_instance_valid(talent_data):
		return
	
	var status = _get_talent_status()
	
	# 更新按钮可用性
	if is_instance_valid(button):
		button.disabled = (status != "can_learn")
	
	# 更新锁定遮罩
	if is_instance_valid(locked_overlay):
		locked_overlay.visible = (status == "locked" or status == "insufficient_points")
	
	# 更新已学指示器
	if is_instance_valid(learned_indicator):
		learned_indicator.visible = (status == "learned")
	
	# 更新 tooltip（状态可能已改变）
	tooltip_text = _build_tooltip()

## 按钮点击事件
func _on_button_pressed() -> void:
	if not is_instance_valid(talent_data):
		return
	
	talent_button_pressed.emit(talent_data)

## 点数变更回调
func _on_points_changed(_points: int) -> void:
	_update_state()

## 天赋学会回调
func _on_talent_learned(talent_id: StringName) -> void:
	if is_instance_valid(talent_data) and talent_data.talent_id == talent_id:
		_update_state()
