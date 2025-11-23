class_name ConditionFactory

# --- 条件类型映射表 ---
var condition_type_map: Dictionary[String, GameCondition] = {
	"quest_status": ConditionQuestStatus.new(),
}

# --- 核心方法：从JSON数据创建GameCondition实例 ---
func create_condition_from_data(condition_data: Dictionary) -> GameCondition:
	if condition_data.is_empty():
		return null  # 没有条件，返回null

	# JSON中的条件可能是这样的：
	# {"has_item": "badge_of_courage"}
	# 或者 {"quest_status": {"id": "quest_01", "status": "completed"}}
	
	# 遍历条件字典，找到第一个有效的条件类型
	for condition_type in condition_data:
		if condition_type_map.has(condition_type):
			var condition_instance: GameCondition = condition_type_map[condition_type].duplicate(true)
			condition_instance.init_from_data(condition_data)
			return condition_instance
	
	# 如果找不到匹配的条件类型，返回null
	push_warning("ConditionFactory: 未知的条件类型，条件数据: %s" % condition_data)
	return null

func register_condition(condition_type: String, condition: GameCondition) -> void:
	if condition_type_map.has(condition_type):
		push_error("ConditionFactory: 条件类型 '%s' 已存在" % condition_type)
		return
	condition_type_map[condition_type] = condition