extends GameAction
class_name ActionTeleport
## Requests a local transition; the teleporter and level coordinate via signals.
func init_from_data(_data: Dictionary) -> void:
	pass
func _execute_internal(initiator: Node, target: Node) -> bool:
	var interaction: InteractionComponent = target as InteractionComponent
	if not is_instance_valid(interaction) or not is_instance_valid(initiator):
		return false
	interaction.request_teleport(initiator)
	return true
