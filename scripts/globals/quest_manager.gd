extends Node

## --- 任务状态枚举 ---
enum QuestStatus { 
	CAN_ACCEPT,      	## 可以接取（在数据库中，但未接取）
	IN_PROGRESS,     	## 进行中（已接取，但未完成）
	READY_TO_TURN_IN, 	## 已完成，可以交任务
	FINISHED         	## 已完成并已交任务
}

# --- 数据存储 ---
# 存储所有正在进行中的任务实例 (Quest Resource 实例)
var active_quests: Array[Quest] = [] ## 正在进行中的任务实例

# 存储已完成的任务ID (用于防止重复接取，或作为前置条件检查)
var completed_quest_ids: Array[String] = [] ## 已完成的任务ID

# --- 信号 ---
# UI系统会监听这些信号来更新界面
signal quest_accepted(quest : Quest)
signal quest_completed(quest : Quest)
signal quest_updated(quest : Quest) # 进度更新时（比如杀怪 1/5 -> 2/5）

func _ready() -> void:
	# 核心：连接全局事件总线
	# 只要游戏里发生任何大事小情，QuestManager 都要知道
	GameState.game_event_occurred.connect(_on_game_event)

# --- 核心：事件分发 ---
func _on_game_event(type: String, data: Dictionary) -> void:
	# 遍历所有活跃任务
	for quest in active_quests:
		if not quest.is_completed:
			# 把事件传给任务，让任务自己去判断是否符合目标
			quest.notify_event(type, data)

# --- 公共接口：接取任务 ---
func accept_quest(quest_res: Quest) -> void:
	# 1. 检查是否已经接过或已完成
	if has_quest(quest_res.id) or is_quest_completed(quest_res.id):
		print("任务已存在或已完成，无法接取：", quest_res.title)
		return
	
	# 2. 【关键】实例化资源 (Deep Duplicate)
	# 资源文件在磁盘上是只读模板，我们必须复制一份独立的实例来记录进度
	var new_quest = quest_res.duplicate(true)
	
	# 3. 初始化并连接内部信号
	new_quest.start()
	# 监听这个新任务实例的信号，以便转发给 UI
	new_quest.quest_updated.connect(func() -> void: quest_updated.emit(new_quest))
	new_quest.quest_completed.connect(func(_id: String) -> void: _on_quest_completed(new_quest))
	
	# 4. 加入列表
	active_quests.append(new_quest)
	quest_accepted.emit(new_quest)
	print("任务接取成功：", new_quest.title)

# --- 辅助查询接口 ---
func has_quest(quest_id: String) -> bool:
	for q in active_quests:
		if q.id == quest_id:
			return true
	return false

func is_quest_completed(quest_id: String) -> bool:
	return completed_quest_ids.has(quest_id)

## 获取任务当前状态
## [param quest_id] 任务ID
## [return] QuestStatus 枚举值
func get_quest_status(quest_id: String) -> QuestStatus:
	if is_quest_completed(quest_id):
		return QuestStatus.FINISHED
	
	if has_quest(quest_id):
		# 查找任务实例，检查是否所有目标都完成
		for q in active_quests:
			if q.id == quest_id:
				if q.is_completed:
					return QuestStatus.READY_TO_TURN_IN
				else:
					return QuestStatus.IN_PROGRESS
	
	# 任务未接取，检查是否在数据库中（可以接取）
	if GameState.quest_database.has(quest_id):
		return QuestStatus.CAN_ACCEPT
	
	return QuestStatus.CAN_ACCEPT  # 默认返回可接取

# --- 内部逻辑：任务完成 ---
func _on_quest_completed(quest: Quest) -> void:
	print("任务流程结束：", quest.title)
	
	# 移出活跃列表
	active_quests.erase(quest)
	# 加入历史记录
	completed_quest_ids.append(quest.id)
	
	# 发出信号通知 UI 移除任务追踪
	quest_completed.emit(quest)
	
	# 这里可以触发后续逻辑，比如自动接取下一个任务
	# 或者发放奖励 (RewardManager)
