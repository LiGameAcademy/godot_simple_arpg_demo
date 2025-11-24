@abstract
extends Resource
class_name QuestObjective 

# --- 信号 ---
# 当进度变化时发出 (比如 1/5 -> 2/5)
signal updated(current: int, required: int)
# 当这个小目标完成时发出
signal completed(description: String)

# --- 数据 ---
@export var description: String = "任务目标描述"
# 是否已完成？
var is_completed: bool = false

# --- 核心接口 (多态的关键) ---
# 所有的子类都要重写这个函数
# event_type: 发生了什么事？("enemy_died", "item_added", "dialogue_ended")
# data: 详细数据 ({ "id": "skeleton", "amount": 1 })
@abstract func on_game_event(event_type: String, data: Dictionary) -> void
@abstract func get_progress_text() -> String

# 序列化支持 (用于存档)
func serialize() -> Dictionary:
	return { "completed": is_completed }

func deserialize(data: Dictionary) -> void:
	is_completed = data.get("completed", false)
