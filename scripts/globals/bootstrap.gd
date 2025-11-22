extends Node

func _ready() -> void:
	# --- 开始履行契约，向DialogueManager注入功能 ---
		
	# 1. 注入条件检查器
	# 将GameState的has_item函数，注册为"has_item"条件的处理器
	DialogueManager.register_condition_checker("has_item", GameState.has_item)
	
	# 2. 注入动作处理器
	DialogueManager.register_action_handler("give_item", GameState.handle_give_item_action)
	DialogueManager.register_action_handler("give_reward", GameState.handle_give_reward_action)
	DialogueManager.register_action_handler("affinity_change", GameState.handle_change_affinity_action)
	DialogueManager.register_action_handler("start_quest", _handle_start_quest)

func _handle_start_quest(action: Dictionary) -> void:
	var quest_id : String = action.get("id", "")
	GameState.start_quest(quest_id)
