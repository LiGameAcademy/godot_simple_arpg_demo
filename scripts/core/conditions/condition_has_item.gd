extends GameCondition
class_name ConditionHasItem
## Checks a configured inventory ID, accepting the recorded course's potion alias.
@export var item_name: String = ""
@export var amount: int = 1
func init_from_data(data: Dictionary) -> void:
	var raw: Variant = data.get("has_item", {})
	if raw is String:
		item_name = raw
	elif raw is Dictionary:
		item_name = String(raw.get("id", ""))
		amount = int(raw.get("amount", 1))
func is_met(activator: Node, _target: Node) -> bool:
	if item_name.is_empty():
		return true
	if not is_instance_valid(activator) or not activator.has_method("get_inventory"):
		return false
	var inventory: InventoryComponent = activator.get_inventory()
	var config: GameplayItem = GameState.get_item_resource(item_name)
	return inventory != null and config != null and inventory.has_item(config.item_id, amount)
func get_failure_message() -> String:
	return "需要物品: " + item_name
