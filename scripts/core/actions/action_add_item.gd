extends GameAction
class_name ActionAddItem

# 引用背包插件的 Item 资源
@export var item: Item 
@export var amount: int = 1

func init_from_data(action_data: Dictionary) -> void:
	# ActionAddItem需要item和amount
	# 但JSON里只有id，我们需要从GameState的item_database查找
	var item_id = action_data.get("id", "")
	amount = action_data.get("amount", 1)
	
	# 这里需要根据item_id获取Item资源
	# 假设GameState有get_item_resource方法
	var item_resource = GameState.get_item_resource(item_id)
	if item_resource:
		item = item_resource
	else:
		push_error("ActionAddItem: 找不到物品资源 '%s'" % item_id)

func execute(initiator: Node, _target: Node) -> void:
	if item == null: return
	
	# 检查发起者(玩家)身上是否有背包组件
	# 假设我们给 Player 挂载的组件名叫 "InventoryComponent"
	var inventory : C_Inventory = initiator.get_inventory() if initiator.has_method("get_inventory") else null
	if is_instance_valid(inventory):
		var final_item : Item = item.duplicate()
		final_item.quantity = amount
		inventory.add_item(final_item)
		print("获得物品：", item.name, " x", amount)
		
		# 可选：在这里触发一个 UI 弹窗提示
