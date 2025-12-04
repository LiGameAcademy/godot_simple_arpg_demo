extends GameAction
class_name ActionRemoveItem 

@export var item_name: String = ""
@export var amount: int = 1

func init_from_data(action_data: Dictionary) -> void:
	item_name = action_data.get("id", "")
	amount = action_data.get("amount", 1)
	if item_name.is_empty():
		push_error("ActionRemoveItem: item_name不能为空")
		return

func _execute_internal(initiator: Node, _target: Node) -> bool:
	if item_name.is_empty():
		print("移除物品名称不能为空！")
		return false
	var inventory : C_Inventory = initiator.get_inventory() if initiator.has_method("get_inventory") else null
	if not is_instance_valid(inventory):
		print("交互组件没有找到背包组件！")
		return false
	inventory.remove_item_by_name(item_name, amount)
	return true
