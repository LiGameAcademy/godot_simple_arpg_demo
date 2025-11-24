extends Button
class_name QuestEntry

func update_display(titile: String, description: String) -> void:
	text = titile
	tooltip_text = description
