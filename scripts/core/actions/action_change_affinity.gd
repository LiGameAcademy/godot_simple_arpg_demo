extends GameAction
class_name ActionChangeAffinity
## Applies configured affinity changes through the host state owner.
@export var npc_id: String = ""
@export var value: int = 0
func init_from_data(data: Dictionary) -> void:
	npc_id = String(data.get("npc_id", ""))
	value = int(data.get("value", 0))
func _execute_internal(_initiator: Node, _target: Node) -> bool:
	if npc_id.is_empty():
		return false
	GameState.change_npc_affinity(npc_id, value)
	return true
