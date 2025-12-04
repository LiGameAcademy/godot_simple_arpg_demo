extends Area3D
class_name InteractionComponent

## 前置条件列表 (必须全部满足)
@export var conditions: Array[GameCondition] = []
## 【核心】策略模式：持有一个动作列表
@export var actions: Array[GameAction] = []
## 这里可以扩展：如果失败了，执行另一组动作（比如播放“锁住”的音效）
@export var failure_actions: Array[GameAction] = []
## 交互提示标签
@export var interaction_label : Label3D = null
## 可以在这里加一个交互提示文本，比如 "按 E 打开"
@export var prompt_text: String = "E: Interact"

signal interacted(initiator: Node)

func _ready() -> void:
	_setup_label()

#这是统一的入口，由 Player 调用
func interact(initiator: Node) -> void:
	if actions.is_empty():
		print("交互组件没有配置任何动作！")
		return
		
	print("开始执行交互动作...")

	# 1. 安检环节
	for condition in conditions:
		if condition and not condition.is_met(initiator, self):
			print("交互失败：", condition.get_failure_message())
			
			# 执行失败反馈 (比如播放 '咣当' 的撞门声)
			_execute_actions(failure_actions, initiator)
			return

	# 2. 通过安检，执行正常逻辑
	print("交互成功！")

	# 遍历并执行所有配置好的动作
	_execute_actions(actions, initiator)

	interacted.emit(initiator)

# 当玩家注视此物体时调用
func focused() -> void:
	if is_instance_valid(interaction_label): interaction_label.visible = true

# 当玩家移开视线时调用
func unfocused() -> void:
	if is_instance_valid(interaction_label): interaction_label.visible = false

func _setup_label() -> void:
	if not is_instance_valid(interaction_label):
		push_error("interaction label is invalid!")
		return
	interaction_label.text = prompt_text
	interaction_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interaction_label.no_depth_test = true
	interaction_label.hide()
	
# 封装一个执行函数，复用代码
# 支持按顺序尝试执行动作，如果某个动作返回 false（跳过），继续尝试下一个
func _execute_actions(action_list: Array[GameAction], initiator: Node) -> void:
	for action in action_list:
		if action:
			# 尝试执行动作，如果返回 true 表示成功执行，停止尝试后续动作
			if action.execute(initiator, self):
				return  # 成功执行，停止尝试后续动作
			# 如果返回 false，继续尝试下一个动作（用于回退机制）
