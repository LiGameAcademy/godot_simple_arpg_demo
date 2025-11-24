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

func emit_game_event(type: String, data: Dictionary) -> void:
	game_event_occurred.emit(type, data)

## 注册Item资源
## [param item_id] Item的唯一ID
## [param item_resource] Item资源
func register_item_resource(item_id: String, item_resource: Item) -> void:
	if not is_instance_valid(item_resource) or item_resource.id.is_empty():
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
