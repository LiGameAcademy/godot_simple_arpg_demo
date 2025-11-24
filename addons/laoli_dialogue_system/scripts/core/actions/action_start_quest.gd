extends GameAction
class_name ActionStartQuest

@export var quest_id: String = ""

func init_from_data(action_data: Dictionary) -> void:
	quest_id = action_data.get("id", "")

func execute(initiator: Node, _target: Node) -> void:
	if quest_id.is_empty():
		push_error("ActionStartQuest: quest_id为空")
		return
	
	GameState.start_quest(quest_id)
	print("任务接取：", quest_id)
