extends GameAction
class_name ActionGiveReward

@export var reward_id: String = ""

func init_from_data(action_data: Dictionary) -> void:
	reward_id = action_data.get("id", "")
	if reward_id.is_empty():
		push_error("ActionGiveReward: reward_id为空")
		return

func execute(initiator: Node, _target: Node) -> void:
	if reward_id.is_empty():
		push_error("ActionGiveReward: reward_id为空")
		return
	
	# 调用GameState的奖励处理逻辑
	GameState.handle_give_reward_action({"id": reward_id})
	print("获得奖励：", reward_id)
