extends GameAction
class_name ActionChangeAffinity

## 改变好感度

@export var npc_id: String = ""
@export var value: int = 0

func init_from_data(action_data: Dictionary) -> void:
	npc_id = action_data.get("npc_id", "")
	value = action_data.get("value", 0)
	if npc_id.is_empty():
		push_error("ActionChangeAffinity: npc_id为空")
		return
	if value == 0:
		push_error("ActionChangeAffinity: value为0")
		return

func execute(_initiator: Node, _target: Node) -> void:
	if npc_id.is_empty():
		push_error("ActionChangeAffinity: npc_id为空")
		return
	
	GameState.change_npc_affinity(npc_id, value)
	print("好感度变化：%s +%d" % [npc_id, value])
