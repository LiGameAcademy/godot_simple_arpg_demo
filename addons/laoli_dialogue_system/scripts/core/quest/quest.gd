extends Resource
class_name Quest 

@export var id: String ## 任务ID
@export var title: String ## 任务标题
@export_multiline var description: String ## 任务描述

@export var objectives: Array[QuestObjective] = [] ## 任务目标

var is_completed: bool = false ## 任务是否完成

signal quest_completed(quest_id: String) ## 任务完成信号
signal quest_updated ## 任务更新信号

# --- 初始化 ---
# 任务接取时，我们需要激活所有目标
func start() -> void:
	for obj : QuestObjective in objectives:
		obj.completed.connect(_on_objective_completed)
		obj.updated.connect(_on_objective_updated)
	#print("任务开始：", title)

func complete() -> void:
	if is_completed: return
	is_completed = true
	#print("任务达成！！！ ", title)
	quest_completed.emit(id)

# --- 事件分发 ---
# QuestManager 会调用这个函数
func notify_event(event_type: String, data: Dictionary) -> void:
	if is_completed: return
	
	# 把事件分发给每一个小目标
	for obj in objectives:
		if not obj.is_completed:
			obj.on_game_event(event_type, data)

## 检查任务是否完成
func _check_completion() -> void:
	var all_done: bool = true
	for obj in objectives:
		if not obj.is_completed:
			all_done = false
			break
	
	if all_done:
		complete()

func _on_objective_completed(desc: String) -> void: 
	#print("目标完成：", desc)
	_check_completion()
	
func _on_objective_updated(curr: int, req: int) -> void: 
	#print("目标更新：", curr, "/", req)
	quest_updated.emit()
