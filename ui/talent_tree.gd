extends Control
class_name TalentTree

## 简易天赋树 UI（业务层）
## 职责：
## - 展示一棵天赋树（基于 TalentTreeData）
## - 响应玩家点击，调用 TalentManager.learn_talent

const TALENT_BUTTON_SCENE = preload("res://ui/talent_button.tscn")

@onready var points_label: Label = %PointsLabel
@onready var talent_container: GridContainer = %TalentContainer

@export_group("Configuration")
@export var talent_tree: TalentTreeData
@export var target_entity: NodePath  ## 一般指向 Player 节点

@export_group("Debug Controls")
## 切换面板显示的快捷键（使用 Input Map 中的 action 名称）
@export var toggle_action: String = "toggle_talent_tree"

var _entity: Node = null

func _ready() -> void:
	# 解析实体
	if not target_entity.is_empty():
		_entity = get_node_or_null(target_entity)
	
	# 初始隐藏面板（默认隐藏）
	visible = false
	
	_build_tree_ui()
	
	# 监听天赋点数变更，刷新 UI 显示
	TalentManager.talent_points_changed.connect(_on_points_changed)
	TalentManager.talent_learned.connect(_on_talent_learned)
	
	# 初始化点数显示
	_on_points_changed(TalentManager.available_points)

## 处理未处理的输入事件（用于快捷键）
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		toggle_visibility()
		get_viewport().set_input_as_handled()

## 切换面板显示/隐藏
func toggle_visibility() -> void:
	visible = not visible
	if visible:
		# 显示时刷新 UI
		_refresh_ui()

## 根据 TalentTreeData 动态创建按钮（使用 TalentButton 场景）
func _build_tree_ui() -> void:
	if not is_instance_valid(talent_tree):
		return
	
	# 获取容器节点（GridContainer）
	var container: Container = get_node_or_null("%TalentContainer")
	if not is_instance_valid(container):
		push_warning("TalentTree: TalentContainer not found, creating fallback container")
		# 回退：创建简单的 VBoxContainer
		for child in get_children():
			if child is VBoxContainer or child is GridContainer:
				remove_child(child)
				child.queue_free()
		var fallback_container = VBoxContainer.new()
		add_child(fallback_container)
		container = fallback_container
	
	# 清空现有按钮
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	
	# 创建按钮
	for talent in talent_tree.talents:
		if not is_instance_valid(talent):
			continue
		
		var button = TALENT_BUTTON_SCENE.instantiate()
		if not is_instance_valid(button):
			push_error("TalentTree: Cannot instantiate talent button")
			continue
		
		if not button.has_method("initialize"):
			push_error("TalentTree: Button does not have initialize method")
			continue
		
		container.add_child(button)
		button.initialize(talent)
		if button.has_signal("talent_button_pressed"):
			button.talent_button_pressed.connect(_on_talent_button_pressed)

func _on_talent_button_pressed(talent: TalentData) -> void:
	if not is_instance_valid(_entity):
		_entity = get_tree().get_first_node_in_group("Player")
	
	if not TalentManager.learn_talent(_entity, talent):
		# 学习成功，刷新 UI
		_refresh_ui()
	else:
		# 学习失败（可能是前置未满足或点数不足），只更新按钮状态
		_update_all_buttons()

func _on_points_changed(points: int) -> void:
	# 更新点数显示
	if is_instance_valid(points_label):
		points_label.text = "剩余点数: %d" % points
	
	# 更新所有按钮状态
	_update_all_buttons()

func _on_talent_learned(_talent_id: StringName) -> void:
	# 更新所有按钮状态（可能有其他天赋变为可学）
	_update_all_buttons()

## 刷新整个 UI（重建所有按钮）
func _refresh_ui() -> void:
	_build_tree_ui()
	# 更新点数显示
	_on_points_changed(TalentManager.available_points)

## 更新所有按钮状态（不重建，只更新状态）
func _update_all_buttons() -> void:
	if not is_instance_valid(talent_container):
		return
	
	for child in talent_container.get_children():
		if child.has_method("update_state"):
			child.update_state()
