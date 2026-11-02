extends Node
class_name PlayerInventory

## 宿主负责物品注册与磁盘读写；规则快照由插件完成。
const HEAL_STRATEGY: GDScript = preload("res://scripts/items/arpg_consumable_strategy.gd")

var _inventory: InventoryComponent
var _equipment: EquipmentComponent


func initialize(inventory: InventoryComponent, equipment: EquipmentComponent, user: Node) -> void:
	_inventory = inventory
	_equipment = equipment
	# 等类加载完成后读取宿主配置，避免物品/技能/角色循环预加载。
	var potion: ArpgConsumableItem = load("res://data/items/potion_health_small.tres") as ArpgConsumableItem
	var axe: ArpgEquip = load("res://data/items/axe.tres") as ArpgEquip
	var staff: ArpgEquip = load("res://data/items/staff.tres") as ArpgEquip
	inventory.initialize(user, equipment)
	ItemUseStrategyManager.register_strategy(&"arpg_heal", HEAL_STRATEGY)
	if not ItemManager.item_types.has(&"arpg_consumable"):
		ItemManager.register_item_type(GameplayItemType.new(&"arpg_consumable", "药水", null, 1, true, 10, &"arpg_heal"))
	for config: GameplayItem in [potion, axe, staff]:
		if not ItemManager.item_configs.has(config.item_id):
			ItemManager.register_item_config(config)
	inventory.add_item(GameplayItemInstance.new(potion, 3))
	inventory.add_item(GameplayEquipInstance.new(axe))
	inventory.add_item(GameplayEquipInstance.new(staff))


func save_state(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(InventorySnapshot.capture(_inventory, _equipment)))
	file.flush()
	return file.get_error() == OK


func load_state(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return false
	return InventorySnapshot.restore(parser.data as Dictionary, _inventory, _equipment)
