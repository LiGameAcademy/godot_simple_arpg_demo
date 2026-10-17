extends Node

const Transcript = preload("../save/dialogue_transcript.gd")

enum DialogueEndReason {
	COMPLETED,
	CANCELED,
	FAILED
}

var transcript: Transcript = Transcript.new()
var _session_id: int = -1
var _next_session_id: int = 0
var _initiator: Node

# 【重构】从Dictionary改为Resource图
var dialogue_graph: Dictionary[String, DialogueNode] = {}
var current_node: DialogueNode = null  # 当前对话节点
var is_active: bool = false 			## 标记对话系统是否正在运行

var action_factory: ActionFactory = ActionFactory.new()
var condition_factory: ConditionFactory = ConditionFactory.new()
var dialogue_parser: DialogueParser = DialogueParser.new(action_factory, condition_factory)

signal text_updated(character_name: String, text: String)		## 文本更新信号
signal dialogue_started											## 对话开始信号
signal dialogue_finished										## 对话结束信号
signal choices_updated(choices: Array)							## 选项更新信号
signal dialogue_session_started(session_id: int)
signal dialogue_session_finished(session_id: int, reason: DialogueEndReason)

func _exit_tree() -> void:
	_end_dialogue(DialogueEndReason.CANCELED)

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

func has_registered_action(action_type: String) -> bool:
	return action_factory.action_type_map.has(action_type)

func has_registered_condition(condition_type: String) -> bool:
	return condition_factory.condition_type_map.has(condition_type)

func set_initiator(initiator: Node) -> bool:
	if is_active and _initiator != initiator:
		return false
	_initiator = initiator
	return true

func clear_initiator(initiator: Node) -> void:
	if _initiator != initiator:
		return
	if is_active:
		_end_dialogue(DialogueEndReason.CANCELED)
	if _initiator == initiator:
		_initiator = null

## 对外提供一个开始对话的接口
## [param node_id] 当前需要处理的节点ID
func start_dialogue(node_id: String) -> void:
	if not dialogue_graph.has(node_id):
		push_error("DialogueManager: 对话节点不存在 ‘%s’" % node_id)
		return
	start_dialogue_session(node_id)

## 处理单个对话节点
## [param node_id] 当前需要处理的节点ID
func process_node(node_id: String) -> void:
	if not is_active:
		return
	if node_id == "END":
		_end_dialogue()
		return
	
	if not dialogue_graph.has(node_id):
		push_error("DialogueManager: 节点不存在 '%s'" %node_id)
		_end_dialogue(DialogueEndReason.FAILED)
		return
	
	current_node = dialogue_graph[node_id]
	var session_id: int = _session_id
	
	# 发出文本更新信号
	var speaker : String = current_node.get_character_name()
	var text: String = current_node.get_text()
	transcript.record(node_id, speaker, text)
	text_updated.emit(speaker, text)
	if not is_active or session_id != _session_id:
		return
	
	# 执行节点动作
	var player : Node = _initiator if is_instance_valid(_initiator) else null
	_execute_actions(current_node.actions, player)
	if not is_active or session_id != _session_id:
		return
	
	# 处理选项或下一节点
	if current_node.has_choices():
		# 获取可用的选项（过滤条件不满足的）
		var available_options : Array[DialogueOption] = current_node.get_available_options(player)
		
		# 格式化选项数据（保持与UI的兼容）
		var formatted_choices: Array[Dictionary] = []
		for option: DialogueOption in available_options:
			var choice_data: Dictionary = {
				"text": option.get_display_text(null),
				"next_node": option.next_node_id,
				"option_resource": option # 保存Resource引用，方便后续使用
			}
			formatted_choices.append(choice_data)
		
		choices_updated.emit(formatted_choices)
	
	elif not current_node.next_node_id.is_empty():
		# 单线对话，等待UI继续（不自动跳转）
		pass
	else:
		_end_dialogue()
	

## 供UI调用，告诉我们玩家做了哪个选择
## [param choice_data] 玩家选择的选项数据
func make_choice(choice_data: Dictionary) -> void:
	if not is_active: return
	var session_id : int = _session_id
	
	# 如果choice_data包含option_resource，使用它
	if choice_data.has("option_resource"):
		var candidata: Variant = choice_data["option_resource"]
		if not candidata is DialogueOption or current_node == null:
			return
		
		var option: DialogueOption = choice_data["option_resource"]
		if not current_node.get_available_options(_initiator).has(option):
			return
		
		# 执行选项动作
		_execute_actions(option.actions, _initiator if is_instance_valid(_initiator) else null)
		if not is_active or session_id != _session_id:
			return
		
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

func start_dialogue_session(node_id: String) -> int:
	if is_active or not dialogue_graph.has(node_id):
		return -1
	_next_session_id += 1
	_session_id = _next_session_id
	is_active = true
	call_deferred("_begin_session", _session_id, node_id)
	return _session_id

func is_session_current(session_id: int) -> bool:
	return is_active and session_id == _session_id

func is_dialogue_active() -> bool:
	return is_active

func advance_dialogue_session(session_id: int) -> void:
	if session_id != _session_id or not is_active or current_node == null or current_node.has_choices():
		return
	process_node(current_node.next_node_id if not current_node.next_node_id.is_empty() else "END")

func cancel_dialogue_session(session_id: int) -> void:
	if session_id == _session_id and is_active:
		_end_dialogue(DialogueEndReason.CANCELED)

func make_session_choice(session_id: int, choice_data: Dictionary) -> void:
	if is_active and session_id == _session_id:
		make_choice(choice_data)

func _begin_session(session_id: int, node_id: String) -> void:
	if session_id != _session_id or not is_active:
		return
	dialogue_session_started.emit(session_id)
	if session_id != _session_id or not is_active:
		return
	dialogue_started.emit()
	if session_id == _session_id and is_active:
		process_node(node_id)

# 【新增】执行动作列表的辅助方法
func _execute_actions(actions: Array[GameAction], activator: Node) -> void:
	var session_id : int = _session_id
	for action in actions:
		if not is_active or session_id != _session_id:
			return
		if action:
			# GameAction的execute需要initiator和target
			# 对话系统中，initiator通常是Player，target是null
			action.execute(activator, null)
			
			# 为了兼容旧系统，仍然发出action_triggered信号
			# 但我们可以从Resource中提取信息（如果需要）
			# 这里暂时跳过，因为新系统直接执行GameAction

## 处理对话结束
func _end_dialogue(reason: DialogueEndReason = DialogueEndReason.COMPLETED) -> void:
	if not is_active:
		return
	var ended_id: int = _session_id
	_session_id = -1
	is_active = false # 标记对话结束
	current_node = null
	print("Dialogue Ended.")
	dialogue_finished.emit()
	dialogue_session_finished.emit(ended_id, reason)
