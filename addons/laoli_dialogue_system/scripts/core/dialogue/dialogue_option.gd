extends Resource
class_name DialogueOption 

# --- 基础信息 ---
@export var text_key: String = ""           ## 选项文本的本地化键
@export var next_node_id: String = ""       ## 选择此选项后跳转的节点

# --- 条件检查（决定选项是否显示）---
@export var condition: GameCondition = null  ## 条件检查

# --- 动作列表（选择此选项时执行）---
@export var actions: Array[GameAction] = []  ## 动作列表

# --- UI 显示选项 ---
@export var display_condition_prefix: bool = false  ## 是否显示条件前缀（如"需要【钥匙】"）

# --- 便捷方法 ---
func get_text() -> String:
	return tr(text_key) if not text_key.is_empty() else ""

# --- 检查选项是否可用 ---
func is_available(activator: Node) -> bool:
	if condition == null:
		return true  # 没有条件，默认可用
	return condition.is_met(activator, null)  # 对话选项没有target，传null

# --- 获取带条件前缀的文本（用于UI显示）---
func get_display_text(activator: Node) -> String:
	var base_text = get_text()
	
	if display_condition_prefix and condition != null:
		# 如果条件不满足，显示前缀提示
		if not condition.is_met(activator, null):
			var prefix = condition.get_failure_message()
			# 这里可以格式化，比如 "(需要【%s】) %s"
			return tr("UI_CONDITION_PREFIX") % [prefix, base_text]
	
	return base_text
