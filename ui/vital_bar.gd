extends Control
class_name VitalBar

## Vital 显示条
## 显示单个 Vital（如生命值、法力值）的当前值、最大值和百分比

# UI 节点引用
@onready var label_name : Label = %NameLabel
@onready var label_value : Label = %ValueLabel
@onready var progress_bar : ProgressBar = %ProgressBar

# 数据
var vital_id: StringName
var _vital_component: GameplayVitalAttributeComponent

## 初始化 Vital 条
## [param] comp: GameplayVitalAttributeComponent Vital 属性组件
## [param] id: StringName Vital ID（如 "health", "mana"）
func initialize(comp: GameplayVitalAttributeComponent, id: StringName) -> void:
	_vital_component = comp
	vital_id = id
	
	# 更新显示
	_update_display()
	
	# 监听 Vital 变化
	if _vital_component:
		if not _vital_component.vital_value_changed.is_connected(_on_vital_changed):
			_vital_component.vital_value_changed.connect(_on_vital_changed)

## 更新显示
func _update_display() -> void:
	if not _vital_component or not _vital_component.has_vital(vital_id):
		return
	
	var vital = _vital_component.get_vital(vital_id)
	if not vital:
		return
	
	var current = vital.current_value
	var max_val = vital._cached_max
	var percent = vital.get_percent()
	
	# 更新进度条
	if progress_bar:
		progress_bar.value = percent * 100.0
		progress_bar.max_value = 100.0
	
	# 更新数值标签
	if label_value:
		label_value.text = "%d / %d" % [int(current), int(max_val)]
	
	# 更新名称标签（如果有）
	if label_name:
		if vital.display_name != "":
			label_name.text = vital.display_name
		else:
			# 如果没有设置 display_name，使用 vital_id
			label_name.text = str(vital.vital_id)

## Vital 值变化回调
## [param] id: StringName Vital ID
## [param] current: float 当前值
## [param] max: float 最大值
## [param] percent: float 百分比
func _on_vital_changed(id: StringName, _current: float, _max: float, _percent: float) -> void:
	if id == vital_id:
		_update_display()
