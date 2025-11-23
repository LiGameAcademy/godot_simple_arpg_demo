extends GameCondition
class_name ConditionHasItem

@export var item_name: String = ""  # 需要检查的物品名称
@export var amount: int = 1 # 需要的数量

func init_from_data(condition_data: Dictionary) -> void:
	var data = condition_data.get("has_item", {})
	if typeof(data) != TYPE_DICTIONARY:
		item_name = data
		return
	item_name = data.get("id", "")
	amount = data.get("amount", 1)
	if item_name.is_empty():
		push_error("ConditionHasItem: item_name不能为空")

func is_met(activator: Node, _target: Node) -> bool:
	if item_name.is_empty(): return true # 没配置物品，默认放行
	
	# 获取玩家身上的背包组件
	# 注意：我们在番外篇给 Player 挂载了 "InventoryComponent"
	var inventory : C_Inventory = activator.get_inventory() if activator.has_method("get_inventory") else null
	
	if is_instance_valid(inventory):
		# 使用插件提供的 API 检查物品数量
		# 假设插件有 get_item_count 方法 (如果没有，我们需要去插件里补一个，或者遍历items)
		var count = inventory.get_item_count_by_name(item_name)
		
		if count >= amount:
			return true
			
	return false

func get_failure_message() -> String:
	return "需要物品: " + item_name
