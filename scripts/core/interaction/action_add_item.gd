extends GameAction
class_name ActionAddItem

# 引用背包插件的 Item 资源
@export var item: Item 
@export var amount: int = 1

func execute(initiator: Node, _target: Node) -> void:
	if item == null: return
	
	# 检查发起者(玩家)身上是否有背包组件
	# 假设我们给 Player 挂载的组件名叫 "InventoryComponent"
	var inventory = initiator.get_inventory() if initiator.has_method("get_inventory") else null
	
	if is_instance_valid(inventory):
		for i in range(amount):
			inventory.add_item(item.duplicate())
		print("获得物品：", item.name, " x", amount)
		
		# 可选：在这里触发一个 UI 弹窗提示
