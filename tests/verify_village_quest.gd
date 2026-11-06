extends Node
## Exercises village dialogue, skeleton drops, physical pickup and quest turn-in.

const Main = preload("res://scenes/main.gd")
const Loot = preload("res://prefabs/loot_item.gd")
const Snapshot = preload("res://scripts/core/story_snapshot.gd")
const QUEST_ID: String = "chief_forest_quest"
const POTION_ID: StringName = &"potion_health_small"

var _failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_child(main)
	await get_tree().process_frame
	var dialogue: CanvasLayer = main.get_node("DialogueUI") as CanvasLayer
	var panel: Control = dialogue.get_node("Panel") as Control
	var choices: VBoxContainer = dialogue.get_node("%ChoicesContainer") as VBoxContainer
	var hud_layer: CanvasLayer = main.get_node("UILayer") as CanvasLayer
	DialogueManager.start_dialogue("village_chief_start")
	for frame: int in range(3):
		await get_tree().process_frame
	_check(panel.is_visible_in_tree() and dialogue.layer > hud_layer.layer, "dialogue draws above the skill HUD")
	_check(choices.get_child_count() >= 2, "village greeting offers choices")
	for child: Node in choices.get_children():
		var button: Button = child as Button
		_check(panel.get_global_rect().encloses(button.get_global_rect()) and
				get_viewport().get_visible_rect().encloses(button.get_global_rect()),
				"dialogue choice is fully inside panel and viewport")
	if choices.get_child_count() > 0:
		_click_choice(choices.get_child(0) as Button)
	DialogueManager.process_node("END")
	_check(QuestManager.get_quest_status(QUEST_ID) == QuestManager.QuestStatus.IN_PROGRESS,
			"accept quest through dialogue choice")
	var quest: Quest = QuestManager.active_quests[0] if not QuestManager.active_quests.is_empty() else null
	if quest == null:
		get_tree().quit(1)
		return
	var objective: ObjectiveCollect = quest.objectives[1] as ObjectiveCollect
	var inventory: InventoryComponent = main.player.get_inventory()
	_check(objective.current_amount == 0, "starting potions do not count as newly collected")
	var entry: InteractionComponent = main.room_lobby.get_node("Teleporter/InteractionComponent") as InteractionComponent
	entry.interact(main.player)
	await get_tree().create_timer(2.0).timeout
	_check(main.player.get_parent() == main.room_dungeon, "accepted quest unlocks dungeon entrance")
	var initial_potions: int = inventory.get_item_count(POTION_ID)
	var enemies: Array[Node] = main.room_dungeon.enemies_container.get_children()
	for index: int in range(enemies.size()):
		var enemy: Enemy = enemies[index] as Enemy
		enemy.take_damage(100000)
		if index >= 3:
			continue
		var loot: RigidBody3D = _find_potion(main)
		_check(loot != null, "defeated skeleton drops a potion")
		if loot == null:
			continue
		for frame: int in range(20):
			if not is_instance_valid(loot):
				break
			main.player.global_position = loot.global_position
			await get_tree().physics_frame
		_check(not is_instance_valid(loot), "walking into potion collects it")
		_check(objective.current_amount == index + 1, "pickup advances collect objective once")
	_check(inventory.get_item_count(POTION_ID) == initial_potions + 3, "picked potions are added to the existing stack")
	_check(QuestManager.get_quest_status(QUEST_ID) == QuestManager.QuestStatus.READY_TO_TURN_IN,
			"five defeats and three pickups make quest ready")
	_verify_legacy_checkpoint()
	var exit: InteractionComponent = main.room_dungeon.get_node("Teleporter/InteractionComponent") as InteractionComponent
	exit.interact(main.player)
	await get_tree().create_timer(2.0).timeout
	_check(main.player.get_parent() == main.room_lobby, "ready quest unlocks the return portal")
	DialogueManager.start_dialogue("village_chief_start")
	await get_tree().process_frame
	if choices.get_child_count() > 0:
		(choices.get_child(0) as Button).pressed.emit()
	DialogueManager.process_node("END")
	_check(QuestManager.get_quest_status(QUEST_ID) == QuestManager.QuestStatus.FINISHED and
			inventory.get_item_count(&"badge_of_courage") == 1, "village chief completes quest and grants reward")
	main.queue_free()
	await get_tree().process_frame
	if _failures == 0:
		print("PASS: village dialogue layering, potion pickup and quest turn-in")
	get_tree().quit(0 if _failures == 0 else 1)

func _verify_legacy_checkpoint() -> void:
	var quest_data: Dictionary = Snapshot.Quests.capture(QuestManager.active_quests, QuestManager.completed_quest_ids)
	quest_data["active"][0]["goals"][1]["key"] = "collect:小红药水:3"
	var legacy: Dictionary = {
		"schema_version": Snapshot.VERSION,
		"checkpoint": "before_intro",
		"story": {"intro_seen": false, "boss_defeated": false, "resolution_seen": false},
		"quests": quest_data,
		"history": DialogueHistoryManager.capture_checkpoint()
	}
	var snapshot: Snapshot = Snapshot.new()
	if not snapshot.validate(legacy, GameState.quest_database):
		_check(false, "legacy village checkpoint validates: " + snapshot.last_error)
		return
	var restored: ObjectiveCollect = snapshot.quests.prepared_quests[0].objectives[1] as ObjectiveCollect
	_check(restored.target_item_id == String(POTION_ID) and restored.current_amount == 3,
			"legacy checkpoint restores potion progress using the current item ID")

func _click_choice(button: Button) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = button.get_global_rect().get_center()
	press.global_position = press.position
	press.pressed = true
	get_viewport().push_input(press, true)
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	get_viewport().push_input(release, true)

func _find_potion(main: Main) -> RigidBody3D:
	for child: Node in main.get_children():
		if child.get_script() == Loot and not child.is_queued_for_deletion():
			return child as RigidBody3D
	return null

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error("Village quest: " + description)
