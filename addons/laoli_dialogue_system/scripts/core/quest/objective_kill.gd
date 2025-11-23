extends QuestObjective
class_name ObjectiveKill 

# --- 导出特定数据 ---
@export var target_enemy_id: String = "skeleton" # 怪物ID
@export var required_amount: int = 5             # 需要杀多少个

# 运行时状态
var current_amount: int = 0

# --- 覆写基类接口 (多态的核心) ---
func on_game_event(event_type: String, data: Dictionary) -> void:
	# 1. 如果已经完成了，就不再处理
	if is_completed: return
	
	# 2. 筛选事件：我只关心 "enemy_died"
	if event_type == "enemy_died":
		# 3. 筛选目标：死的怪物是任务要求的吗？
		if data.get("enemy_id") == target_enemy_id:
			_update_progress(1)

func _update_progress(amount: int) -> void:
	current_amount += amount
	print("任务进度更新: ", description, " ", current_amount, "/", required_amount)
	
	# 发出基类定义的信号，通知 UI 更新
	updated.emit(current_amount, required_amount)
	
	if current_amount >= required_amount:
		finish() # 调用自定义的完成逻辑

func finish() -> void:
	is_completed = true
	completed.emit(description)
