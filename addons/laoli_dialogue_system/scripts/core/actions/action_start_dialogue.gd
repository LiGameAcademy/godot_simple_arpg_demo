extends GameAction
class_name ActionStartDialogue

@export var dialogue_node_id: String

func init_from_data(data: Dictionary) -> void:
	dialogue_node_id = data.get("id", "")

func execute(_initiator: Node, _target: Node) -> void:
	DialogueManager.start_dialogue(dialogue_node_id)
