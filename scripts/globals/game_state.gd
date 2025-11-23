extends Node

# 1. 创建一个道具“数据库”，用ID作为Key
var item_database = {
	"sword_rust": { "name": "生锈的剑" },
	"bread": { "name": "面包" },
	"badge_of_courage": { "name": "勇气徽章" }
}

# 运行时查找表 (ID -> Quest Resource)
var quest_database: Dictionary = {}
# 2. 玩家的背包现在存储的是道具ID，而不是名称
#var inventory = ["sword_rust", "bread"]
var inventory = ["sword_rust", "bread", "badge_of_courage"]

# 新增：用于存储NPC好感度的字典
# Key是NPC的唯一ID，Value是好感度数值
var npc_affinities: Dictionary = {
	"village_chief": 50 # 比如村长，初始好感度是50
}

signal game_event_occurred(type: String, data: Dictionary)

func _ready() -> void:
	# 连接信号的代码保持不变
	DialogueManager.action_triggered.connect(_on_action_triggered)

func emit_game_event(type: String, data: Dictionary) -> void:
	game_event_occurred.emit(type, data)

func register_quest(quest: Quest) -> void:
	if not is_instance_valid(quest) or quest.id.is_empty():
		push_error("警告：任务 ID 为空 -> ", quest)
		return
	if quest_database.has(quest.id):
		push_error("警告：任务 ID 重复 -> ", quest.id)
	else:
		quest_database[quest.id] = quest

# 3. has_item和add_item现在都使用ID
func has_item(item_id: String) -> bool:
	return inventory.has(item_id)

func add_item(item_id: String):
	if not inventory.has(item_id):
		inventory.append(item_id)

# 4. 用于通过ID获取道具的显示名称
func get_item_name(item_id: String) -> String:
	if item_database.has(item_id):
		# 在这里，我们可以为未来的本地化做准备，直接使用tr()
		return tr(item_database[item_id]["name"])
	return "[物品ID不存在]"

## 处理给于道具动作
func handle_give_item_action(action_data: Dictionary):
	var item_id = action_data.get("id", "")
	if not item_id.is_empty():
		add_item(item_id)
		var item_name = get_item_name(item_id)
		print("[GameState] Player received item: %s (ID: %s)" % [item_name, item_id])

## 处理奖励动作
func handle_give_reward_action(action_data: Dictionary):
	var reward_id = action_data.get("id", "")
	if reward_id == "QUEST_1_REWARD":
		add_item("gold_coin_pouch")
		add_item("letter_of_recommendation")
		print("[GameState] Player received rewards for: ", reward_id)

# 未来可以扩展更多接口
# func has_completed_quest(quest_id: String) -> bool: ...

## 处理接收到的结构化动作事件
func _on_action_triggered(action_data: Dictionary) -> void:
	# 检查传入的是否是字典，保证代码健壮性
	if not action_data is Dictionary or not action_data.has("type"):
		return

	print("[GameState] Received action: ", action_data) # 打印日志，方便调试
	
	# 使用match语句，根据动作类型来分发逻辑
	match action_data["type"]:
		"give_item":
			var item_id = action_data.get("id", "")
			var amount = action_data.get("amount", 1) # 获取数量，默认为1
			if not item_id.is_empty():
				add_item(item_id) # add_item现在也只接收ID
				var item_name = get_item_name(item_id)
				print("[GameState] Player received %d x %s (ID: %s)" % [amount, item_name, item_id])
		
		"give_reward":
			var reward_id = action_data.get("id", "")
			if reward_id == "QUEST_1_REWARD":
				add_item("gold_coin_pouch") # 给予ID为gold_coin_pouch的物品
				add_item("letter_of_recommendation")
				print("[GameState] Player received rewards for: ", reward_id)
		
		"play_sound":
			# 未来可以轻松扩展，比如让AudioManager来处理
			var sound_id = action_data.get("id", "")
			print("[GameState] Action 'play_sound' triggered for sound: ", sound_id)

# 新增：一个用来修改好感度的函数
func change_npc_affinity(npc_id: String, value: int) -> void:
	if not npc_affinities.has(npc_id):
		npc_affinities[npc_id] = 0 # 如果是新NPC，从0开始
	
	npc_affinities[npc_id] += value
	print("Affinity with %s changed to: %s" % [npc_id, npc_affinities[npc_id]])

func handle_change_affinity_action(action: Dictionary) -> void:
	var npc_id : String = action.get("npc_id", "")
	var value : int = action.get("value", 0)
	change_npc_affinity(npc_id, value)

## 开启任务的函数
func start_quest(quest_id: String) -> void:
	if not quest_database.has(quest_id):
		push_error("警告：任务 ID 不存在 -> ", quest_id)
		return
	var quest = quest_database[quest_id]
	if not is_instance_valid(quest):
		push_error("警告：任务实例不存在 -> ", quest_id)
		return
	QuestManager.accept_quest(quest)
