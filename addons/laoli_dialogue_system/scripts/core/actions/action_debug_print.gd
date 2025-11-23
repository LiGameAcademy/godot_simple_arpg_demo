extends GameAction
class_name ActionDebugPrint

@export var text_to_print: String = "Default Text"

func init_from_data(action_data: Dictionary) -> void:
	text_to_print = action_data.get("text", "Default Text")

func execute(_initiator: Node, _target: Node) -> void:
	print("交互触发：", text_to_print)
