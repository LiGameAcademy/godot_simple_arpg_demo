extends Node

const DIALOGUE_FILE_PATH = "res://addons/laoli_dialogue_system/dialogue.json"

var dialogue_data: Dictionary = {}		## 存储解析后的对话数据
var current_node_id: String = "" 		## 追踪当前对话节点的ID
var is_active: bool = false 			## 标记对话系统是否正在运行

# 创建字典，作为我们所有外部逻辑函数的“注册表”
var condition_checkers: Dictionary = {} ## 用于条件检查
var action_handlers: Dictionary = {}    ## 用于动作处理

## 当有新的对话内容需要显示时，发出此信号
## [param character_name] 对话角色名称
## [param text] 对话文本
signal text_updated(character_name: String, text: String)
## 当对话流程结束时，发出此信号
signal dialogue_finished
## 当需要向玩家展示选项时，发出此信号
## [param choices] 选项数组
signal choices_updated(choices: Array)
signal action_triggered(action: Dictionary)

## 游戏启动时，自动加载并解析JSON文件
func _ready() -> void:
	load_dialogue_file(DIALOGUE_FILE_PATH)

## 加载并解析指定的JSON文件
## [param path] JSON文件的路径
func load_dialogue_file(path: String) -> void:
	# 使用FileAccess安全地打开文件
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("Error: Failed to open dialogue file at path: ", path)
		return

	# 读取文件全部内容
	var content = file.get_as_text()
	# 使用JSON类来解析文本内容
	var parse_result = JSON.parse_string(content)
	
	# 解析失败会返回null，需要检查
	if parse_result:
		dialogue_data = parse_result
		print("Dialogue file loaded and parsed successfully!")
		# 打印出来看看，确认数据正确
		# print(dialogue_data)
	else:
		print("Error: Failed to parse JSON file. Check for syntax errors in: ", path)

## 对外提供一个开始对话的接口
## [param node_id] 当前需要处理的节点ID
func start_dialogue(node_id: String) -> void:
	if is_active:
		return
	is_active = true # 标记对话开始
	if dialogue_data.has(node_id):
		process_node(node_id)
	else:
		print("Error: Dialogue node not found: ", node_id)
		_end_dialogue()

## 供UI调用，告诉我们玩家做了哪个选择
## [param choice_data] 玩家选择的选项数据
func make_choice(choice_data: Dictionary) -> void:
	if choice_data.has("next_node"):
		# 根据玩家的选择，处理下一个节点
		process_node(choice_data["next_node"])
	else:
		# 如果选择数据有问题，直接结束对话
		_end_dialogue()

## 提供公开的注册函数（“插座”），让外部系统可以把“检查器”“插”进来
func register_condition_checker(condition_type: String, checker_callable: Callable) -> void:
	condition_checkers[condition_type] = checker_callable
	print("Condition checker registered for type: '%s'" % condition_type)

## 提供公开的注册函数（“插座”），让外部系统可以把“动作处理器”“插”进来
func register_action_handler(action_type: String, handler_callable: Callable) -> void:
	action_handlers[action_type] = handler_callable
	print("Action handler registered for type: '%s'" % action_type)

## 处理单个对话节点
## [param node_id] 当前需要处理的节点ID
func process_node(node_id: String) -> void:
	current_node_id = node_id # 更新当前节点ID

	if node_id == "END":
		_end_dialogue()
		return

	var node_data = dialogue_data[node_id]
	
	# 代码变得如此简洁和优雅！
	var character = tr(node_data.get("character", "KEY_ERROR"))
	var text = tr(node_data.get("text", "KEY_ERROR"))
	
	emit_signal("text_updated", character, text)

	# 检查并触发节点自身的动作
	if node_data.has("action"):
		_process_action(node_data.get("action"))
	elif node_data.has("actions"):
		var actions : Array = node_data.get("actions")
		for action_data in actions:
			_process_action(action_data)

	if node_data.has("choices"):
		var available_choices = [] # 创建一个空数组来存放可用选项
		for choice in node_data["choices"]:
			# 检查每个选项的条件
			if _check_condition(choice.get("condition", {})):
				available_choices.append(choice) # 条件满足，才加入可用列表
		
		# 在发出信号前，处理文本的动态生成
		var localized_choices = []
		for choice in available_choices:
			var localized_choice = choice.duplicate() # 复制一份，避免修改原始数据
			# 这里也同样使用 tr()
			var final_text = tr(choice["text"])

			# 动态生成条件前缀的逻辑保持不变，但格式化字符串本身也应该用tr()
			if choice.get("display_condition_prefix", false) and choice.has("condition"):
				var condition = choice["condition"]
				if condition.has("has_item"):
					var item_id = condition["has_item"]
					var item_name = GameState.get_item_name(item_id)
					# "(需要【%s】) %s" 这个key也需要加入到CSV文件中
					final_text = tr("UI_CONDITION_PREFIX_HAS_ITEM") % [item_name, final_text]
			
			if choice.has("action"):
				# 分支选项也支持动作逻辑
				pass
			
			localized_choice["text"] = final_text
			localized_choices.append(localized_choice)

		emit_signal("choices_updated", localized_choices)
	elif node_data.has("next_node"):
		# 如果是单线对话，我们暂时先不自动跳转
		# 等待玩家按键继续，这个逻辑我们放在UI层处理
		pass
	else:
		# 如果既没有选项也没有下一句，就结束对话
		_end_dialogue()

## 检查条件是否满足
func _check_condition(condition_data: Dictionary) -> bool:
	if condition_data.is_empty(): return true
	
	for condition_type in condition_data:
		var condition_value = condition_data[condition_type]
		
		# 在我们的注册表中查找对应的检查函数
		if condition_checkers.has(condition_type):
			var checker_func = condition_checkers[condition_type]
			# 调用注册进来的Callable，并用其返回值作为判断结果
			if not checker_func.call(condition_value):
				return false # 一票否决
		else:
			# 如果找不到对应的检查函数，打印一个警告，并默认当做不满足
			print("Warning: No checker registered for condition type: '%s'" % condition_type)
			return false
	return true

## 处理动作
func _process_action(action_data: Dictionary) -> void:
	if action_data is Dictionary and action_data.has("type"):
		var action_type = action_data["type"]
		# 在注册表中查找对应的动作处理函数
		if action_handlers.has(action_type):
			# 调用注册进来的action处理函数
			action_handlers[action_type].call(action_data)
		else:
			print("Warning: No handler for action type: '%s'" % action_type)

## 处理对话结束
func _end_dialogue() -> void:
	is_active = false # 标记对话结束
	current_node_id = ""
	print("Dialogue Ended.")
	dialogue_finished.emit()
