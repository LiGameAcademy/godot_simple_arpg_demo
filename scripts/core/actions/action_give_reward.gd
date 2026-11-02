extends GameAction
class_name ActionGiveReward
## Delegates configured reward policy to the host game state.
@export var reward_id: String = ""
func init_from_data(data: Dictionary) -> void:
	reward_id = String(data.get("id", ""))
func _execute_internal(_initiator: Node, _target: Node) -> bool:
	if reward_id.is_empty():
		return false
	return GameState.handle_give_reward_action({"id": reward_id}, _initiator)
