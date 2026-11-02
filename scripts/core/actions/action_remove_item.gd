extends GameAction
class_name ActionRemoveItem
## Removes host inventory items and reports the actual operation result.
@export var item_name: String = ""
@export var amount: int = 1
func init_from_data(data: Dictionary) -> void:
	item_name = String(data.get("id", ""))
	amount = int(data.get("amount", 1))
func _execute_internal(initiator: Node, _target: Node) -> bool:
	if item_name.is_empty() or amount <= 0 or not is_instance_valid(initiator):
		return false
	var inventory: C_Inventory = initiator.get_inventory() if initiator.has_method("get_inventory") else null
	return inventory.remove_item_by_name(item_name, amount) if is_instance_valid(inventory) else false
