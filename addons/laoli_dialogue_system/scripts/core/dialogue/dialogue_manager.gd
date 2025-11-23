extends Node

# 【重构】从Dictionary改为Resource图
var dialogue_graph: Dictionary = {}  # Dictionary<String, DialogueNode>
var current_node: DialogueNode = null  # 当前对话节点
var is_active: bool = false 			## 标记对话系统是否正在运行

var action_factory: ActionFactory = ActionFactory.new()
var condition_factory: ConditionFactory = ConditionFactory.new()
var dialogue_parser: DialogueParser = DialogueParser.new(action_factory, condition_factory)

signal text_updated(character_name: String, text: String)
signal dialogue_finished
signal choices_updated(choices: Array)
signal action_triggered(action: Dictionary)

## 加载并解析指定的JSON文件
## [param path] JSON文件的路径
func load_dialogue_file(path: String) -> void:
	var dialogues : Dictionary = dialogue_parser.parse_dialogue_file(path)
	dialogue_graph.merge(dialogues, true)
	if dialogue_graph.is_empty():
		push_error("DialogueManager: 对话文件加载失败 '%s'" % path)
	else:
		print("DialogueManager: 对话文件加载成功，共 %d 个节点" % dialogue_graph.size())

## 提供公开的注册函数（“插座”），让外部系统可以把“检查器”“插”进来
func register_condition(condition_type: String, condition: GameCondition) -> void:
	condition_factory.register_condition(condition_type, condition)

## 提供公开的注册函数（“插座”），让外部系统可以把“动作处理器”“插”进来
func register_action(action_type: String, action: GameAction) -> void:
	action_factory.register_action(action_type, action)

## 对外提供一个开始对话的接口
## [param node_id] 当前需要处理的节点ID
func start_dialogue(node_id: String) -> void:
	if is_active:
		return

	if not dialogue_graph.has(node_id):
		push_error("DialogueManager: 对话节点不存在 '%s'" % node_id)
		_end_dialogue()
		return

	is_active = true # 标记对话开始
	process_node(node_id)

## 处理单个对话节点
## [param node_id] 当前需要处理的节点ID
func process_node(node_id: String) -> void:
	if node_id == "END":
		_end_dialogue()
		return

	if not dialogue_graph.has(node_id):
		push_error("DialogueManager: 节点不存在 '%s'" % node_id)
		_end_dialogue()
		return

	current_node = dialogue_graph[node_id]

	# 发出文本更新信号
	emit_signal("text_updated", current_node.get_character_name(), current_node.get_text())
	
	# 执行节点动作
	_execute_actions(current_node.actions, null)
	
	# 处理选项或下一节点
	if current_node.has_choices():
		# 获取可用的选项（过滤条件不满足的）
		var available_options = current_node.get_available_options(null)  # 暂时传null，后续可以传Player
		
		# 格式化选项数据（保持与UI的兼容性）
		var formatted_choices = []
		for option in available_options:
			var choice_data = {
				"text": option.get_display_text(null),
				"next_node": option.next_node_id,
				"option_resource": option  # 保存Resource引用，方便后续使用
			}
			formatted_choices.append(choice_data)
		
		emit_signal("choices_updated", formatted_choices)
	elif not current_node.next_node_id.is_empty():
		# 单线对话，等待UI继续（不自动跳转）
		pass
	else:
		_end_dialogue()

## 供UI调用，告诉我们玩家做了哪个选择
## [param choice_data] 玩家选择的选项数据
func make_choice(choice_data: Dictionary) -> void:
	# 如果choice_data包含option_resource，使用它
	if choice_data.has("option_resource"):
		var option: DialogueOption = choice_data["option_resource"]
		
		# 执行选项动作
		_execute_actions(option.actions, null)
		
		# 跳转到下一节点
		if not option.next_node_id.is_empty():
			process_node(option.next_node_id)
		else:
			_end_dialogue()
	else:
		# 兼容旧格式
		if choice_data.has("next_node"):
			process_node(choice_data["next_node"])
		else:
			_end_dialogue()

# 【新增】执行动作列表的辅助方法
func _execute_actions(actions: Array[GameAction], activator: Node) -> void:
	for action in actions:
		if action:
			# GameAction的execute需要initiator和target
			# 对话系统中，initiator通常是Player，target是null
			action.execute(activator, null)
			
			# 为了兼容旧系统，仍然发出action_triggered信号
			# 但我们可以从Resource中提取信息（如果需要）
			# 这里暂时跳过，因为新系统直接执行GameAction

## 处理对话结束
func _end_dialogue() -> void:
	is_active = false # 标记对话结束
	current_node = null
	print("Dialogue Ended.")
	dialogue_finished.emit()
