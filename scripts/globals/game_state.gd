extends Node
## Owns host quest configuration and world events; inventory holds runtime item instances.
signal game_event_occurred(type: String, data: Dictionary)
var item_database: Dictionary[String, GameplayItem] = {}
var quest_database: Dictionary[String, Quest] = {}
var npc_affinities: Dictionary[String, int] = {}
func _ready() -> void:
	for path: String in ["bread", "rusty_sword", "badge_of_courage", "potion_health_small", "axe", "staff"]:
		var config: GameplayItem = load("res://data/items/" + path + ".tres") as GameplayItem
		register_item_resource(String(config.item_id), config)
func emit_game_event(type: String, data: Dictionary) -> void:
	game_event_occurred.emit(type, data)
func register_item_resource(item_id: String, config: GameplayItem) -> void:
	if config == null or config.item_id.is_empty():
		return
	item_database[item_id] = config
	if not ItemManager.item_configs.has(config.item_id):
		ItemManager.register_item_config(config)
func get_item_resource(item_id: String) -> GameplayItem:
	if item_id == "小红药水":
		item_id = "potion_health_small"
	return item_database.get(item_id) as GameplayItem
func register_quest(quest: Quest) -> void:
	if quest != null and not quest.id.is_empty():
		quest_database[quest.id] = quest
func change_npc_affinity(npc_id: String, value: int) -> void:
	npc_affinities[npc_id] = npc_affinities.get(npc_id, 0) + value
func handle_change_affinity_action(action: Dictionary) -> void:
	change_npc_affinity(String(action.get("npc_id", "")), int(action.get("value", 0)))
func handle_give_reward_action(action: Dictionary, recipient: Node = null) -> bool:
	var config: GameplayItem = get_item_resource(String(action.get("id", "")))
	if config == null or not is_instance_valid(recipient) or not recipient.has_method("get_inventory"):
		return false
	var inventory: InventoryComponent = recipient.get_inventory()
	return inventory.add_item(GameplayItemInstance.new(config))
func start_quest(quest_id: String) -> void:
	if quest_database.has(quest_id):
		QuestManager.accept_quest(quest_database[quest_id])
