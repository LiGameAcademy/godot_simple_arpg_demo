extends Node

var _passed: int = 0
var _failed: int = 0
const SAVE_PATH: String = "res://tests/inventory_pilot_state.tmp"

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var main: Node3D = scene.instantiate() as Node3D
	add_child(main)
	await get_tree().process_frame
	var player: Player = main.get_node("RoomLobby/Player") as Player
	var inventory: InventoryComponent = player.get_inventory()
	var equipment: EquipmentComponent = player.equipment_component
	var attributes: GameplayVitalAttributeComponent = player.attribute_component
	attributes.set_process(false)
	_check(inventory.get_item(0).quantity == 3, "seeded potions")
	_check(inventory.get_item(1).item_config.item_id == &"axe", "seeded axe")
	_check(inventory.get_item(2).item_config.item_id == &"staff", "seeded staff")
	_check((inventory.get_item(1).item_config as ArpgEquip).abilities.size() == 2, "axe skills loaded")
	_check((inventory.get_item(2).item_config as ArpgEquip).abilities.size() == 2, "staff skills loaded")
	var health: float = attributes.get_vital_value(&"health")
	_check(health >= 20.0, "health initialized")
	_check(attributes.modify_vital(&"health", -20.0), "take damage")
	_check(inventory.use_item(0, player), "use potion")
	_check(is_equal_approx(attributes.get_vital_value(&"health"), health), "heal exactly 20")
	_check(inventory.get_item(0).quantity == 2, "consume exactly one")
	var attack: float = attributes.get_value(&"attack")
	var intelligence: float = attributes.get_value(&"intelligence")
	_check(inventory.use_item(1, player), "equip axe")
	_check(equipment.get_equip(&"weapon").item_config.item_id == &"axe", "axe equipped")
	_check(is_equal_approx(attributes.get_value(&"attack"), attack + 50.0), "axe plus strength-derived attack")
	_check(inventory.use_item(2, player), "replace axe with staff")
	_check(inventory.get_item(2).item_config.item_id == &"axe", "old axe returned to source slot")
	_check(is_equal_approx(attributes.get_value(&"attack"), attack), "old modifiers removed")
	_check(is_equal_approx(attributes.get_value(&"intelligence"), intelligence + 15.0), "staff modifier")
	var staff: GameplayEquipInstance = equipment.get_equip(&"weapon")
	staff.enhancement_level = 2
	staff.current_durability = 17.0
	staff.enchantments.append(&"fire")
	_check(player.inventory_binding.save_state(SAVE_PATH), "save to disk")
	var snapshot: String = JSON.stringify(InventorySnapshot.capture(inventory, equipment))
	_check(equipment.unequip_item(&"weapon", inventory), "unequip staff")
	_check(is_equal_approx(attributes.get_value(&"intelligence"), intelligence), "unequip removes modifier")
	_check(player.inventory_binding.load_state(SAVE_PATH), "load from disk")
	_check(JSON.stringify(InventorySnapshot.capture(inventory, equipment)) == snapshot, "snapshot round trip")
	_check(equipment.get_equip(&"weapon") != staff, "restored instance is independent")
	_check(is_equal_approx(attributes.get_value(&"intelligence"), intelligence + 15.0), "load reapplies equipment effects")
	_check(player.ability_component.get_all_ability_instances().has(&"fireball"), "base skill retained")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 999}")
	file.close()
	_check(not player.inventory_binding.load_state(SAVE_PATH), "bad save rejected")
	_check(JSON.stringify(InventorySnapshot.capture(inventory, equipment)) == snapshot, "bad save preserves state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	# 换一套场景后重建快照，确认配置共享而状态独立。
	var data: Dictionary = JSON.parse_string(snapshot) as Dictionary
	main.queue_free()
	await get_tree().process_frame
	main = scene.instantiate() as Node3D
	add_child(main)
	await get_tree().process_frame
	player = main.get_node("RoomLobby/Player") as Player
	_check(InventorySnapshot.restore(data, player.get_inventory(), player.equipment_component), "restore into new scene")
	_check(player.get_inventory().get_item(0).quantity == 2, "new scene has saved quantity")
	_check(player.equipment_component.get_equip(&"weapon").enhancement_level == 2, "new scene has saved enhancement")
	var loot_scene: PackedScene = load("res://prefabs/loot_potion.tscn") as PackedScene
	var loot: RigidBody3D = loot_scene.instantiate() as RigidBody3D
	loot.position = Vector3(10000, 10000, 10000)
	loot.freeze = true
	add_child(loot)
	var small_inventory: InventoryComponent = InventoryComponent.new()
	small_inventory.max_slot_count = 1
	add_child(small_inventory)
	var potion: GameplayItem = player.get_inventory().get_item(0).item_config
	small_inventory.add_item(GameplayItemInstance.new(potion, potion.max_stack))
	loot.call("collect", small_inventory)
	_check(not loot.is_queued_for_deletion(), "full bag preserves ground loot")
	_check(small_inventory.get_item_count(potion.item_id) == potion.max_stack, "failed pickup preserves quantity")
	small_inventory.remove_item(0)
	loot.call("collect", small_inventory)
	_check(loot.is_queued_for_deletion(), "successful pickup removes ground loot")
	_check(small_inventory.get_item_count(potion.item_id) == 1, "pickup creates exactly one item")
	small_inventory.queue_free()
	main.queue_free()
	await get_tree().process_frame
	print("ARPG inventory pilot: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error("ARPG inventory pilot: " + message)
