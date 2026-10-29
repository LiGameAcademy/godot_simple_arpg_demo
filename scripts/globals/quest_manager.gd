extends Node

## --- 任务状态枚举 ---
enum QuestStatus { 
	CAN_ACCEPT,      	## 可以接取（在数据库中，但未接取）
	IN_PROGRESS,     	## 进行中（已接取，但未完成）
	READY_TO_TURN_IN, 	## 已完成，可以交任务
	FINISHED,         	## 已完成并已交任务
	UNAVAILABLE,        ## 不可接受（不在数据库中）
}

# --- 数据存储 ---
# 存储所有正在进行中的任务实例 (Quest Resource 实例)
var active_quests: Array[Quest] = [] ## 正在进行中的任务实例

# 存储已完成的任务ID (用于防止重复接取，或作为前置条件检查)
var completed_quest_ids: Array[String] = [] ## 已完成的任务ID

# --- 信号 ---
# UI系统会监听这些信号来更新界面
signal quest_accepted(quest : Quest)
signal quest_completed(quest : Quest)  # 任务完成（所有目标达成，但未交付）
signal quest_ready_to_turn_in(quest : Quest)  # 任务可以交付（新增）
signal quest_turned_in(quest : Quest)  # 任务已交付（新增）
signal quest_updated(quest : Quest) # 进度更新时（比如杀怪 1/5 -> 2/5）
signal quests_loaded()

func _ready() -> void:
	# 核心：连接全局事件总线
	# 只要游戏里发生任何大事小情，QuestManager 都要知道
	GameState.game_event_occurred.connect(_on_game_event)

# --- 核心：事件分发 ---
func _on_game_event(type: String, data: Dictionary) -> void:
	# 遍历所有活跃任务
	# 注意：即使任务已完成，也继续处理事件（虽然通常不会触发，但为了安全）
	for quest in active_quests:
		# 只处理未完成的任务（已完成的任务不再需要更新进度）
		if not quest.is_completed:
			# 把事件传给任务，让任务自己去判断是否符合目标
			quest.notify_event(type, data)

# --- 公共接口：接取任务 ---
func accept_quest(quest_res: Quest) -> void:
	if has_quest(quest_res.id) or is_quest_completed(quest_res.id):
		print("任务已存在或已完成，无法接取：", quest_res.title)
		return
	
	var new_quest = quest_res.duplicate(true)
	
	new_quest.start()
	# 监听这个新任务实例的信号，以便转发给 UI
	new_quest.quest_updated.connect(_on_quest_updated_by_id.bind(new_quest.id))
	new_quest.quest_completed.connect(_on_quest_completed_by_id)
	
	active_quests.append(new_quest)
	quest_accepted.emit(new_quest)
	print("任务接取成功：", new_quest.title)

func install_checkpoint(quests: Array[Quest], completed: Array[String]) -> void:
	active_quests = quests.duplicate()
	completed_quest_ids = completed.duplicate()
	for quest: Quest in active_quests:
		quest.start()
		quest.quest_updated.connect(_on_quest_updated_by_id.bind(quest.id))
		quest.quest_completed.connect(_on_quest_completed_by_id)
	quests_loaded.emit()

## 交付任务（玩家与NPC对话后选择"交任务"）
## [param quest_id] 任务ID
## [return] 是否成功交付
func turn_in_quest(quest_id: String) -> bool:
	if quest_id.is_empty():
		push_error("QuestManager: turn_in_quest quest_id为空")
		return false
	
	# 查找任务实例
	var quest: Quest = null
	for q in active_quests:
		if q.id == quest_id:
			quest = q
			break
	
	if not quest:
		push_error("QuestManager: 找不到任务 '%s'，无法交付" % quest_id)
		return false
	
	# 检查任务是否已完成（所有目标都达成）
	if not quest.is_completed:
		push_warning("QuestManager: 任务 '%s' 尚未完成，无法交付" % quest_id)
		return false
	
	# 移出活跃列表
	active_quests.erase(quest)
	# 加入历史记录（标记为已交付）
	completed_quest_ids.append(quest.id)
	
	# 发出信号通知 UI 任务已交付
	quest_turned_in.emit(quest)
	print("任务已交付：", quest.title)
	
	# 这里可以触发后续逻辑，比如发放奖励 (RewardManager)
	# 或者自动接取下一个任务
	
	return true

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
	if quest_id.is_empty():
		return QuestStatus.UNAVAILABLE
	
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
	
	return QuestStatus.UNAVAILABLE  # 默认返回不可接取

# --- 内部逻辑：任务完成（所有目标达成，但未交付）---
func _on_quest_completed(quest: Quest) -> void:
	print("任务目标全部完成，可以交付：", quest.title)
	
	# 【关键修改】任务完成时，不要立即移出 active_quests
	# 而是保持在列表中，等待玩家交付
	# 这样 get_quest_status 才能正确返回 READY_TO_TURN_IN
	
	# 发出信号通知 UI 任务已完成，可以交付
	quest_completed.emit(quest)
	quest_ready_to_turn_in.emit(quest)
	
	# 注意：此时任务仍在 active_quests 中，状态为 READY_TO_TURN_IN
	# 只有当玩家交付任务后，才会移出 active_quests 并加入 completed_quest_ids

func _on_quest_updated_by_id(quest_id: String) -> void:
	for quest: Quest in active_quests:
		if quest.id == quest_id:
			quest_updated.emit(quest)
			return

func _on_quest_completed_by_id(quest_id: String) -> void:
	for quest: Quest in active_quests:
		if quest.id == quest_id:
			_on_quest_completed(quest)
			return
