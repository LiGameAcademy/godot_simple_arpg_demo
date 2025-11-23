extends GameCondition
class_name ConditionQuestStatus

const QuestStatus = QuestManager.QuestStatus

# 任务ID
@export var quest_id: String = ""
# 期望的状态（映射到 QuestManager.QuestStatus）
@export var required_status: QuestStatus = QuestStatus.CAN_ACCEPT

# --- 核心判定 ---
func is_met(_activator: Node, _target: Node) -> bool:
	if quest_id.is_empty():
		push_error("ConditionQuestStatus: quest_id为空")
		return false
	
	# 调用 QuestManager 查询状态
	var current_status = QuestManager.get_quest_status(quest_id)
	
	# 直接比较状态
	return current_status == required_status

func init_from_data(condition_data: Dictionary) -> void:
	# 解析 JSON: {"quest_status": {"id": "quest_01", "status": "started"}}
	var info = condition_data.get("quest_status", {})
	if not info is Dictionary:
		push_error("ConditionQuestStatus: quest_status 必须是字典")
		return
	
	quest_id = info.get("id", "")
	
	# 将字符串状态映射到 QuestManager.QuestStatus 枚举
	var status_str = info.get("status", "can_accept").to_lower()
	match status_str:
		"can_accept", "not_started":
			required_status = QuestStatus.CAN_ACCEPT
		"in_progress", "started":
			required_status = QuestStatus.IN_PROGRESS
		"ready_to_turn_in", "completed":
			required_status = QuestStatus.READY_TO_TURN_IN
		"finished":
			required_status = QuestStatus.FINISHED
		_:
			push_warning("ConditionQuestStatus: 未知的状态 '%s'，默认使用 CAN_ACCEPT" % status_str)
			required_status = QuestStatus.CAN_ACCEPT
	
	if quest_id.is_empty():
		push_error("ConditionQuestStatus: quest_id不能为空")

func get_failure_message() -> String:
	return "任务状态不符：需要 " + str(required_status)