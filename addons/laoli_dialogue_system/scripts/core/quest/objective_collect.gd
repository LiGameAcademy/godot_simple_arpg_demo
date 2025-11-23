extends QuestObjective
class_name ObjectiveCollect 

@export var target_item_id: String  # 物品名或资源路径
@export var required_amount: int = 3

var current_amount: int = 0

func on_game_event(event_type: String, data: Dictionary) -> void:
	if is_completed: return
	
	# 监听物品获得事件
	if event_type == "item_added":
		var item_id = data.get("item_id", "")
		var amount = data.get("amount", 1) # 默认获得1个
		
		if item_id == target_item_id:
			# 这里可以做的更严谨：去查询 GameState.inventory 的实际总数
			# 为了演示简单，我们先做增量累加
			_update_progress(amount)

func _update_progress(amount: int) -> void:
	current_amount += amount
	updated.emit(current_amount, required_amount)
	
	if current_amount >= required_amount:
		is_completed = true
		completed.emit(description)
