extends RefCounted

var last_error : String = ""
var prepared_quests: Array[Quest] = []
var prepared_completed : Array[String] = []

static func capture(active: Array[Quest], completed: Array[String]) -> Dictionary:
	var entries: Array[Dictionary] = []
	for quest: Quest in active:
		var goals: Array[Dictionary] = []
		for objective: QuestObjective in quest.objectives:
			goals.append({"key": _key(objective), "amount": _amount(objective), "completed": objective.is_completed})
		entries.append({"id": quest.id, "completed": quest.is_completed, "goals": goals})
	return {"active": entries, "completed":  completed.duplicate()}

func prepare(data: Dictionary, database: Dictionary[String, Quest]) -> bool:
	last_error = ""
	prepared_quests.clear()
	prepared_completed.clear()
	if not data.get("active") is Array or not data.get("completed") is Array:
		return _reject("任务集合无效！")
	for value: Variant in data["completed"]:
		if not value is String or not database.has(value) or prepared_completed.has(value):
			return _reject("已交付任务 ID 无效或重复")
		prepared_completed.append(String(value))
	var visited: Array[String] = prepared_completed.duplicate()
	for value: Variant in data["active"]:
		if not value is Dictionary:
			return _reject("任务条目无效")
		var entry: Dictionary = value as Dictionary
		if not entry.get("id") is String or not entry.get("completed") is bool or not entry.get("goals") is Array:
			return _reject("任务字段类型无效")
		var id: String = String(entry["id"])
		if not database.has(id) or visited.has(id):
			return _reject("任务 ID 不存在或重复！")
		visited.append(id)
		var quest : Quest = database[id].duplicate(true) as Quest
		var goals: Array = entry["goals"]
		if goals.size() != quest.objectives.size() or goals.is_empty():
			return _reject("任务目标数量已变化")
		var all_done: bool = true
		for index: int in range(goals.size()):
			var objective: QuestObjective = quest.objectives[index]
			if not goals[index] is Dictionary:
				return _reject("任务目标条目无效")
			var goal: Dictionary = goals[index]
			if _key(objective).is_empty() or goal.get("key") != _key(objective) or \
				not goal.get("completed") is bool or not is_integer(goal.get("amount")):
					return _reject("任务目标配置或进度无效")
			var amount : int = int(goal["amount"])
			var required: int = _required(objective)
			if amount < 0 or bool(goal["completed"]) != (amount >= required):
				return _reject("目标完成标记与数量不一致")
			_set_amount(objective, amount)
			objective.is_completed = bool(goal["completed"])
			all_done = all_done and objective.is_completed
		if bool(entry["completed"]) != all_done:
			return _reject("任务完成标记与目标不一致")
		quest.is_completed = all_done
		prepared_quests.append(quest)
	return true
	
func _reject(message: String) -> bool:
	last_error = message
	prepared_quests.clear()
	prepared_completed.clear()
	return false

static func _key(objective: QuestObjective) -> String:
	if objective is ObjectiveKill:
		var kill : ObjectiveKill = objective as ObjectiveKill
		return "kill:%s:%d" %[kill.target_enemy_id, kill.required_amount]
	if objective is ObjectiveCollect:
		var collect : ObjectiveCollect = objective as ObjectiveCollect
		return "collect:%s:%d" %[collect.target_item_id, collect.required_amount]
	return ""

static func _amount(objective: QuestObjective) -> int:
	if objective is ObjectiveKill:
		var kill : ObjectiveKill = objective as ObjectiveKill
		return kill.current_amount
	if objective is ObjectiveCollect:
		var collect : ObjectiveCollect = objective as ObjectiveCollect
		return collect.current_amount
	return 0

static func _required(objective: QuestObjective) -> int:
	if objective is ObjectiveKill:
		var kill : ObjectiveKill = objective as ObjectiveKill
		return kill.required_amount
	if objective is ObjectiveCollect:
		var collect : ObjectiveCollect = objective as ObjectiveCollect
		return collect.required_amount
	return 0

static func _set_amount(objective: QuestObjective, amount: int) -> void:
	if objective is ObjectiveKill:
		var kill : ObjectiveKill = objective as ObjectiveKill
		kill.current_amount = amount
	if objective is ObjectiveCollect:
		var collect : ObjectiveCollect = objective as ObjectiveCollect
		collect.current_amount = amount

static func is_integer(value: Variant) -> bool:
	return (value is int or value is float ) and is_finite(float(value)) and \
		float(value) == floorf(float(value)) and absf(float(value)) <= 1000000000.0
