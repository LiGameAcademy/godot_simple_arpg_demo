extends CanvasLayer
class_name QuestLogUI

@onready var quest_container: VBoxContainer = %QuestContainer

func _ready() -> void:
	# 订阅GameState的任务更新方法
	QuestManager.quest_updated.connect(
		func() -> void: _update_display()
	)
	QuestManager.quest_completed.connect(
		func() -> void: _update_display()
	)
	_update_display()

func _update_display() -> void:
	for qc in quest_container.get_children():
		qc.queue_free()
	for quest: Quest in QuestManager.active_quests:
		var quest_lable : Button = Button.new()
		quest_lable.text = quest.title
		quest_lable.tooltip_text = quest.description
		quest_container.add_child(quest_lable)
