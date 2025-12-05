extends Node

# 1. 创建一个道具“数据库”，用ID作为Key
var item_database : Dictionary[String, Item] = {
	"sword_rust": preload("uid://dc7i3ahfpm68s"),
	"bread": preload("uid://dw4jfkow21e7j"),
	"badge_of_courage": preload("uid://dlh3ar8kfpps0"),
}

# 运行时查找表 (ID -> Quest Resource)
var quest_database: Dictionary[String, Quest] = {}

## 用于存储NPC好感度的字典
## Key是NPC的唯一ID，Value是好感度数值
var npc_affinities: Dictionary[String, int] = {}

signal game_event_occurred(type: String, data: Dictionary)

func _ready() -> void:
	# 注册变量提供者
	VariableManager.register_variable_provider(_provide_game_variables)
	
	# 注册插件依赖（解耦业务层）
	# 1. 注册游戏事件信号到 QuestManager
	QuestManager.register_game_event_signal(game_event_occurred)
	
	# 2. 注册任务数据库查询函数
	QuestManager.register_quest_database_provider(_check_quest_in_database)
	
	# 3. 注册任务资源获取函数（供 ActionStartQuest 使用）
	QuestManager.register_quest_resource_getter(_get_quest_resource)
	
	# 4. 注册玩家节点获取函数（可选，但推荐）
	DialogueManager.register_player_getter(_get_player_node)
	
	# 5. 注册任务资源获取函数（供存档系统使用）
	DialogueManager.register_quest_resource_getter_for_save(_get_quest_resource)

func emit_game_event(type: String, data: Dictionary) -> void:
	game_event_occurred.emit(type, data)

## 注册Item资源
## [param item_id] Item的唯一ID
## [param item_resource] Item资源
func register_item_resource(item_id: String, item_resource: Item) -> void:
	if not is_instance_valid(item_resource) or item_resource.name.is_empty():
		push_error("警告：Item资源为空 -> ", item_resource)
		return
	if item_database.has(item_id):
		push_error("警告：Item ID 重复 -> ", item_id)
		return
	item_database[item_id] = item_resource

## 获取Item资源
## [param item_id] Item的唯一ID
func get_item_resource(item_id: String) -> Item:
	if item_database.has(item_id):
		return item_database[item_id]
	else:
		push_warning("GameState: 找不到Item资源 '%s'，返回null" % item_id)
		return null

func register_quest(quest: Quest) -> void:
	if not is_instance_valid(quest) or quest.id.is_empty():
		push_error("警告：任务 ID 为空 -> ", quest)
		return
	if quest_database.has(quest.id):
		push_error("警告：任务 ID 重复 -> ", quest.id)
	else:
		quest_database[quest.id] = quest

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

func handle_give_reward_action(action: Dictionary) -> void:
	var reward_id : String = action.get("id", "")
	if reward_id.is_empty():
		push_error("警告：奖励 ID 为空 -> ", action)
		return
	var reward = get_item_resource(reward_id)
	if not is_instance_valid(reward):
		push_error("警告：奖励实例不存在 -> ", reward_id)
		return
	var player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player):
		push_error("警告：玩家不存在 -> ", player)
		return
	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not is_instance_valid(inventory):
		push_error("警告：玩家背包不存在 -> ", player)
		return
	inventory.add_item(reward)

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

## 提供游戏变量
## [return] 游戏变量字典
func _provide_game_variables() -> Dictionary:
	var vars = {
		"player_name": _get_player_name(),
		"player_level": _get_player_level(),
		"gold_amount": _get_gold_amount(),
		"quest_count": _get_quest_count(),
		"completed_quest_count": _get_completed_quest_count(),
	}
	
	return vars

## 获取玩家名称
func _get_player_name() -> String:
	# 从玩家数据中获取，或使用默认值
	return "冒险者"

## 获取玩家等级
func _get_player_level() -> int:
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("get_level"):
		return player.get_level()
	return 5  # 默认等级改为5，方便测试表达式

## 获取金币数量
func _get_gold_amount() -> int:
	# 从背包或玩家数据中获取
	return 100  # 默认100金币，方便测试

## 获取任务数量
func _get_quest_count() -> int:
	return QuestManager.active_quests.size()

## 获取已完成任务数量
func _get_completed_quest_count() -> int:
	return QuestManager.completed_quest_ids.size()

## 检查任务是否在数据库中（供 QuestManager 使用）
## [param quest_id] 任务ID
## [return] 是否在数据库中
func _check_quest_in_database(quest_id: String) -> bool:
	return quest_database.has(quest_id)

## 获取任务资源（供 QuestManager 使用）
## [param quest_id] 任务ID
## [return] Quest 资源或 null
func _get_quest_resource(quest_id: String) -> Quest:
	if quest_database.has(quest_id):
		return quest_database[quest_id]
	return null

## 获取玩家节点（供 DialogueManager 使用）
## [return] 玩家节点或 null
func _get_player_node() -> Node:
	return get_tree().get_first_node_in_group("Player")

## 序列化背包数据（供游戏存档系统使用）
## [return] 背包数据字典
func _serialize_inventory() -> Dictionary:
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not player.has_method("get_inventory"):
		return {}
	
	var inventory = player.get_inventory()
	if not inventory or not inventory.has_method("serialize"):
		return {}
	
	return inventory.serialize()

## 反序列化背包数据（供游戏存档系统使用）
## [param data] 背包数据字典
func _deserialize_inventory(data: Dictionary) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not player.has_method("get_inventory"):
		push_warning("GameState: 无法获取玩家或背包，无法加载背包数据")
		return
	
	var inventory = player.get_inventory()
	if not inventory or not inventory.has_method("deserialize"):
		push_warning("GameState: 背包没有反序列化方法，无法加载背包数据")
		return
	
	inventory.deserialize(data)

## 序列化游戏状态（供游戏存档系统使用）
## [return] 游戏状态数据字典
func _serialize_game_state() -> Dictionary:
	return {
		"npc_affinities": npc_affinities,
		"gold_amount": _get_gold_amount(),
		"player_level": _get_player_level(),
		"player_name": _get_player_name()
	}

## 反序列化游戏状态（供游戏存档系统使用）
## [param data] 游戏状态数据字典
func _deserialize_game_state(data: Dictionary) -> void:
	npc_affinities = data.get("npc_affinities", {})
	# 注意：gold_amount、player_level、player_name 等可能需要通过其他方式恢复
	# 这里只恢复 npc_affinities，其他数据可能需要通过玩家节点或背包系统恢复
