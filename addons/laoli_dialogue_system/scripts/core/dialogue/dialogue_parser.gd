class_name DialogueParser

var action_factory: ActionFactory
var condition_factory: ConditionFactory

func _init(p_action_factory: ActionFactory = null, p_condition_factory: ConditionFactory = null) -> void:
	action_factory = p_action_factory
	condition_factory = p_condition_factory

# --- 核心方法：解析JSON文件，返回节点资源图 ---
func parse_dialogue_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("DialogueParser: 无法打开文件 '%s'" % file_path)
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	var parse_result = JSON.parse_string(content)
	if not parse_result or not parse_result is Dictionary:
		push_error("DialogueParser: JSON解析失败 '%s'" % file_path)
		return {}
	
	# 开始转换
	var node_graph: Dictionary = {}
	
	for node_id in parse_result:
		var node_data = parse_result[node_id]
		var dialogue_node = _parse_node(node_id, node_data)
		if dialogue_node:
			node_graph[node_id] = dialogue_node
	
	print("DialogueParser: 成功解析 %d 个对话节点" % node_graph.size())
	return node_graph

# --- 解析单个节点 ---
func _parse_node(node_id: String, node_data: Dictionary) -> DialogueNode:
	var node = DialogueNode.new()
	node.node_id = node_id
	
	# 解析角色名
	if node_data.has("character"):
		var character = node_data["character"]
		if character is String:
			node.character_key = character
		elif character is Dictionary:
			# 多语言格式，暂时取第一个（后续可以改进）
			var keys = character.keys()
			if keys.size() > 0:
				node.character_key = character[keys[0]]
	
	# 解析文本
	if node_data.has("text"):
		var text = node_data["text"]
		if text is String:
			node.text_key = text
		elif text is Dictionary:
			# 多语言格式
			var keys = text.keys()
			if keys.size() > 0:
				node.text_key = text[keys[0]]
	
	# 解析选项
	if node_data.has("choices"):
		var choices_data = node_data["choices"]
		if choices_data is Array:
			for choice_data in choices_data:
				var option = _parse_option(choice_data)
				if option:
					node.options.append(option)
	
	# 解析动作（单个或数组）
	if node_data.has("action"):
		var action = action_factory.create_action_from_data(node_data["action"])
		if action:
			node.actions.append(action)
	elif node_data.has("actions"):
		var actions = action_factory.create_actions_from_data(node_data["actions"])
		node.actions.append_array(actions)
	
	# 解析下一节点
	if node_data.has("next_node"):
		node.next_node_id = node_data["next_node"]
	
	# 解析元数据（如果有）
	if node_data.has("metadata"):
		node.metadata = node_data["metadata"]
	
	return node

# --- 解析单个选项 ---
func _parse_option(option_data: Dictionary) -> DialogueOption:
	var option = DialogueOption.new()
	
	# 解析选项文本
	if option_data.has("text"):
		var text = option_data["text"]
		if text is String:
			option.text_key = text
		elif text is Dictionary:
			# 多语言格式
			var keys = text.keys()
			if keys.size() > 0:
				option.text_key = text[keys[0]]
	
	# 解析下一节点
	if option_data.has("next_node"):
		option.next_node_id = option_data["next_node"]
	
	# 解析条件
	if option_data.has("condition"):
		option.condition = condition_factory.create_condition_from_data(option_data["condition"])
	
	# 解析选项动作（如果有）
	if option_data.has("action"):
		var action = action_factory.create_action_from_data(option_data["action"])
		if action:
			option.actions.append(action)
	elif option_data.has("actions"):
		var actions = action_factory.create_actions_from_data(option_data["actions"])
		option.actions.append_array(actions)
	
	# 解析显示选项
	if option_data.has("display_condition_prefix"):
		option.display_condition_prefix = option_data["display_condition_prefix"]
	
	return option