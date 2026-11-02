extends Node
## Verifies real combat joins the narrative and inventory state, without debug defeat.
const Main = preload("res://scenes/main.gd")
var _failed: int = 0
var _received: int = 0
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	main.checkpoint_path = "user://feature_integration_checkpoint.json"
	add_child(main)
	await get_tree().physics_frame
	var player: Player = main.player
	var inventory: InventoryComponent = player.get_inventory()
	inventory.items_received.connect(_on_received)
	var potion: GameplayItem = inventory.get_item(0).item_config
	_check(inventory.add_item(GameplayItemInstance.new(potion, 2)), "merge acquisition succeeds")
	_check(_received == 2 and inventory.get_item(0).quantity == 5, "merged stack reports full acquisition")
	var saved: Dictionary = InventorySnapshot.capture(inventory, player.equipment_component)
	_check(InventorySnapshot.restore(saved, inventory, player.equipment_component), "restore inventory")
	_check(_received == 2, "restore does not report new quest acquisition")
	_check(inventory.use_item(1, player), "equip axe for real combat")
	TalentManager.add_points(10)
	var cooldown_talent: TalentData = load("res://data/talents/talent_cooldown_reduction.tres") as TalentData
	_check(TalentManager.learn_talent(player, cooldown_talent), "cooldown talent learns")
	var dash_start: Vector3 = player.global_position
	player.face_point(dash_start + Vector3(5, 0, 0))
	player.try_activate_ability(&"dash", {"target_position": dash_start + Vector3(5, 0, 0)})
	for frame: int in range(3):
		await get_tree().process_frame
	_check(player.global_position.distance_to(dash_start) > 0.5, "dash actually moves player")
	var dash: GameplayAbilityInstance = player.ability_component.get_ability_instance(&"dash")
	var cooldown: CooldownFeature = dash.get_feature("CooldownFeature") as CooldownFeature
	_check(cooldown.get_cooldown_remaining(dash) > 1.0 and cooldown.get_cooldown_remaining(dash) < 1.7, "talent reduces actual cooldown")
	await main.transition_to_room(main.room_boss, main.encounter.arrival.global_position)
	main.encounter.entrance.body_entered.emit(player)
	_check(main.narrative.is_playing() and not player.can_control(), "intro locks combat input")
	player.try_activate_ability(&"combo_attack")
	_check(player.ability_component.get_current_casting_ability() == null, "story blocks ability activation")
	main.narrative.skip()
	_check(main.save_checkpoint(), "save playable boss checkpoint")
	var boss: CharacterBody3D = main.encounter.get_node("BossCombatant") as CharacterBody3D
	boss.set_physics_process(false)
	var boss_attributes: GameplayVitalAttributeComponent = boss.get_node("GameplayAttributeComponent") as GameplayVitalAttributeComponent
	boss_attributes.set_base_value(&"max_health", 999.0)
	var boss_health: HealthVital = boss_attributes.get_vital(&"health") as HealthVital
	boss_health.current_value = 999.0
	var damage: GE_ApplyDamage = GE_ApplyDamage.new()
	damage.apply(boss, player, {"base_damage": 10.0})
	_check(is_equal_approx(boss_health.current_value, 989.0), "baseline damage applies exactly once")
	var damage_talent: TalentData = load("res://data/talents/talent_damage_boost.tres") as TalentData
	_check(TalentManager.learn_talent(player, damage_talent), "damage talent learns")
	damage.apply(boss, player, {"base_damage": 10.0})
	_check(is_equal_approx(boss_health.current_value, 974.0), "damage talent increases real damage by fifty percent")
	_check(damage_talent.ability_modifiers[0].source.is_empty(), "talent config remains immutable")
	boss_attributes.set_base_value(&"max_health", 12.0)
	boss_health.initialize(boss_attributes)

	player.global_position = boss.global_position + Vector3(0, 0, -1.5)
	player.face_point(boss.global_position)
	await get_tree().physics_frame
	player.try_activate_ability(&"combo_attack", {"target_position": boss.global_position})
	for frame: int in range(180):
		await get_tree().process_frame
		if main._boss_defeated:
			break
	for frame: int in range(180):
		await get_tree().process_frame
		if main.narrative.is_playing():
			break
	_check(main._boss_defeated, "real ability damage defeats boss")
	_check(main.narrative.is_playing(), "real boss death starts resolution")
	main.narrative.skip()
	_check(main._resolution_seen, "resolution commits quest and story result")
	_check(main.load_checkpoint(), "reload active boss checkpoint")
	_check(not main._boss_defeated and boss.call("get_health") > 0, "boss health restored from checkpoint")
	player.take_damage(100000)
	_check(not player.can_control(), "dead player cannot control")
	_check(main.load_checkpoint() and player.can_control(), "checkpoint revives player")
	main.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://feature_integration_checkpoint.json"))
	if _failed == 0:
		print("PASS: feature integration acquisition, real combat, story locks, boss resolution and death restore")
	get_tree().quit.call_deferred(0 if _failed == 0 else 1)
func _on_received(_item_id: StringName, quantity: int) -> void:
	_received += quantity
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed += 1
		push_error("FAIL: " + message)
