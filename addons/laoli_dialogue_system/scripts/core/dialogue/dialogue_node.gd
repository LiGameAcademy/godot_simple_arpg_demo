extends Resource
class_name DialogueNode

# --- 基础信息 ---
@export var node_id: String = ""  # 节点唯一标识
@export var character_key: String = ""  # 角色名称的本地化键（如 "CHARACTER_VILLAGE_CHIEF"）
@export_multiline var text_key: String = ""  # 对话文本的本地化键

# --- 选项列表 ---
@export var options: Array[DialogueOption] = []

# --- 动作列表（当节点被处理时执行）---
@export var actions: Array[GameAction] = []

# --- 流程控制 ---
@export var next_node_id: String = ""  # 单线对话的下一节点（如果没有选项）

# --- 元数据（可选，用于扩展）---
@export var metadata: Dictionary = {}  # 可以存储音效、动画、表情等额外信息

# --- 便捷方法：获取本地化后的文本 ---
func get_character_name() -> String:
	return tr(character_key) if not character_key.is_empty() else ""

func get_text() -> String:
	return tr(text_key) if not text_key.is_empty() else ""

# --- 检查是否有选项 ---
func has_choices() -> bool:
	return not options.is_empty()

# --- 获取可用的选项（过滤掉条件不满足的）---
func get_available_options(activator: Node) -> Array[DialogueOption]:
	var available: Array[DialogueOption] = []
	for option in options:
		if option.is_available(activator):
			available.append(option)
	return available
