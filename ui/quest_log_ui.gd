extends CanvasLayer
class_name QuestLogUI

@onready var quest_container: VBoxContainer = %QuestContainer

func _ready() -> void:
	# 订阅GameState的任务更新方法
	GameState.quest_log_updated.connect(_on_game_state_quest_log_updated)
	_update_display()

func _update_display() -> void:
	for qc in quest_container.get_children():
		qc.queue_free()
	for quest_id in GameState.player_quests:
		if GameState.player_quests[quest_id] == "active":
			var quest_lable : Button = Button.new()
			quest_lable.text = GameState.quest_database[quest_id].get("title", "未知任务")
			quest_lable.tooltip_text = GameState.quest_database[quest_id].get("description", "未知任务")
			quest_container.add_child(quest_lable)

func _on_game_state_quest_log_updated() -> void:
	_update_display()
