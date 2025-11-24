extends GameAction
class_name ActionTurnInQuest

@export var quest_id: String = ""

func init_from_data(action_data: Dictionary) -> void:
	# JSON中通常使用 "id" 字段
	quest_id = action_data.get("id", action_data.get("quest_id", ""))

func execute(_initiator: Node, _target: Node) -> void:
	if quest_id.is_empty():
		push_error("ActionTurnInQuest: quest_id为空")
		return
	
	QuestManager.turn_in_quest(quest_id)
	print("任务交付：", quest_id)
