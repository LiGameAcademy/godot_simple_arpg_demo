extends Area3D
class_name InteractionComponent

# 【核心】策略模式：持有一个动作列表
@export var actions: Array[GameAction] = []
@export var interaction_label : Label3D = null

# 可以在这里加一个交互提示文本，比如 "按 E 打开"
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
	
	# 遍历并执行所有配置好的动作
	for action in actions:
		if action:
			action.execute(initiator, self) # 将组件自己作为 target 传进去

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
