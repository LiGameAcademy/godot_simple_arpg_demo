extends GameAction
class_name ActionAddItem
## Adds an independent item instance to the host initiator's inventory.
@export var item: GameplayItem
@export var amount: int = 1
func init_from_data(data: Dictionary) -> void:
	item = GameState.get_item_resource(String(data.get("id", "")))
	amount = int(data.get("amount", 1))
func _execute_internal(initiator: Node, _target: Node) -> bool:
	if item == null or amount <= 0 or not is_instance_valid(initiator):
		return false
	var inventory: InventoryComponent = initiator.get_inventory() if initiator.has_method("get_inventory") else null
	if not is_instance_valid(inventory):
		return false
	return inventory.add_item(GameplayItemInstance.new(item, amount))
