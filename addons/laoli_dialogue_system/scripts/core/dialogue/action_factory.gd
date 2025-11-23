class_name ActionFactory

# --- 动作类型映射表 ---
# Key: JSON中的type字符串，Value: 对应的GameAction类
var action_type_map: Dictionary[String, GameAction] = {
	"debug_print": ActionDebugPrint.new(),
	"play_sound": ActionPlaySound.new(),
	"start_quest": ActionStartQuest.new(),  # 这个我们稍后实现
	"start_dialogue": ActionStartDialogue.new(),
}

# --- 核心方法：从JSON数据创建GameAction实例 ---
func create_action_from_data(action_data: Dictionary) -> GameAction:
	if not action_data.has("type"):
		push_error("ActionFactory: action_data缺少'type'字段")
		return null
	
	var action_type: String = action_data["type"]
	
	# 查找对应的类
	if not action_type_map.has(action_type):
		push_error("ActionFactory: 未知的动作类型 '%s'" % action_type)
		return null
	
	# 创建资源实例
	var action_instance: GameAction = action_type_map[action_type].duplicate(true)
	action_instance.init_from_data(action_data)
	return action_instance

# --- 批量创建动作列表 ---
func create_actions_from_data(actions_data: Array) -> Array[GameAction]:
	var actions: Array[GameAction] = []
	for action_dict in actions_data:
		var action = create_action_from_data(action_dict)
		if action:
			actions.append(action)
	return actions

func register_action(action_type: String, action: GameAction) -> void:
	if action_type_map.has(action_type):
		push_error("ActionFactory: 动作类型 '%s' 已存在" % action.type)
		return
	action_type_map[action_type] = action
