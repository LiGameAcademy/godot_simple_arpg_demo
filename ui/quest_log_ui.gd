extends CanvasLayer
class_name QuestLogUI

const QuestStatus = QuestManager.QuestStatus
const QUEST_ENTRY = preload("uid://buxpglhrujy2")
@onready var quest_container: VBoxContainer = %QuestContainer

var quest_entries: Dictionary[Quest, QuestEntry] = {}

func _ready() -> void:
	# 核心：连接 QuestManager 的信号
	QuestManager.quest_accepted.connect(_on_quest_accepted)
	QuestManager.quest_updated.connect(_on_quest_updated)
	QuestManager.quest_completed.connect(_on_quest_completed)

func _get_quest_text(quest: Quest) -> String:
	var txt = quest.title + " " + _get_quest_status_text(quest) + "\n"
	for obj in quest.objectives:
		txt += "- " + obj.get_progress_text() + "\n"
	return txt

func _get_quest_status_text(quest: Quest) -> String:
	var status = QuestManager.get_quest_status(quest.id)
	match status:
		QuestStatus.UNAVAILABLE:
			return "未接取"
		QuestStatus.IN_PROGRESS:
			return "进行中"
		QuestStatus.READY_TO_TURN_IN:
			return "可交付"
		QuestStatus.FINISHED:
			return "已完成"
	return ""

func _on_quest_accepted(quest: Quest) -> void:
	var entry : QuestEntry = QUEST_ENTRY.instantiate()
	quest_container.add_child(entry)
	entry.update_display(_get_quest_text(quest), quest.description)
	quest_entries[quest] = entry

func _on_quest_updated(quest: Quest) -> void:
	var entry : QuestEntry = quest_entries.get(quest, null)
	if entry:
		entry.update_display(_get_quest_text(quest), quest.description)

func _on_quest_completed(quest: Quest) -> void:
	var entry : QuestEntry = quest_entries.get(quest, null)
	if entry:
		entry.update_display(_get_quest_text(quest), quest.description)
	entry.disabled = true
