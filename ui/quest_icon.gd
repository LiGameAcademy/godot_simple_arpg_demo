extends Sprite3D

const AVAILABLE_QUEST = preload("uid://cbcdvlrys34b4") # 黄色叹号
const GRAY_QUEST = preload("uid://dax77swwc7kum") # 灰色叹号
const QUEST_IN_PROGRESS = preload("uid://b62536qlgp5xc") # 灰色问号
const READY_TO_TURN_IN = preload("uid://dm2gkvc73art2") # 金色问号

const QuestStatus = QuestManager.QuestStatus

@export var associated_quests: Array[String] = []

func _ready() -> void:
	# 监听信号，或者简单点，每隔 0.5秒检查一次 (对于非高频UI可以接受)
	_update_icon()

func _update_icon() -> void:
	var final_status = _get_highest_priority_status()

	# 根据最终计算出的状态显示图标
	match final_status:
		QuestStatus.CAN_ACCEPT:
			texture = AVAILABLE_QUEST
			visible = true
		QuestStatus.IN_PROGRESS:
			texture = QUEST_IN_PROGRESS
			visible = true
		QuestStatus.READY_TO_TURN_IN:
			texture = READY_TO_TURN_IN
			visible = true
		_:
			visible = false # 其他情况隐藏

## 计算最高优先级的任务状态
func _get_highest_priority_status() -> QuestStatus:
	var final_status = QuestStatus.UNAVAILABLE
	# 遍历所有关联任务，计算最高优先级的状态
	for quest_id in associated_quests:
		var status = QuestManager.get_quest_status(quest_id)
		
		# 优先级 1: 可交付 (Yellow ?)
		if status == QuestStatus.READY_TO_TURN_IN:
			final_status = status
			break # 找到最高优先级，直接跳出循环
		
		# 优先级 2: 可接取 (Yellow !)
		# 只有当前没有"可交付"任务时，才显示"可接取"
		if status == QuestStatus.CAN_ACCEPT:
			if final_status != QuestStatus.READY_TO_TURN_IN:
				final_status = status
		
		# 优先级 3: 进行中 (Gray ?)
		# 只有既没"可交付"也没"可接取"时，才显示"进行中"
		if status == QuestStatus.IN_PROGRESS:
			if final_status == QuestStatus.UNAVAILABLE:
				final_status = status

	return final_status

func _on_timer_timeout() -> void:
	_update_icon()
