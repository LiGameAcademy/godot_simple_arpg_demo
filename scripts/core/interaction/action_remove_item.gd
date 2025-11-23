extends GameAction
class_name ActionRemoveItem 

@export var item_name: String = ""
@export var amount: int = 1

func execute(initiator: Node, _target: Node) -> void:
    if item_name.is_empty():
        print("移除物品名称不能为空！")
        return
    var inventory : C_Inventory = initiator.get_inventory() if initiator.has_method("get_inventory") else null
    if not is_instance_valid(inventory):
        print("交互组件没有找到背包组件！")
        return
    inventory.remove_item_by_name(item_name, amount)