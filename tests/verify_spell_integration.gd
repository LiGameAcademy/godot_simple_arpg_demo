extends Node
## Checks real spell casts and their effects on the player and boss.
const Main = preload("res://scenes/main.gd")
var _failed: int = 0
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	main.checkpoint_path = "user://spell_integration_checkpoint.json"
	add_child(main)
	await get_tree().process_frame
	await main.transition_to_room(main.room_boss, main.encounter.arrival.global_position)
	main.encounter.entrance.body_entered.emit(main.player)
	main.narrative.skip()
	_check(main.save_checkpoint(), "save spell fixture")
	var boss: Node3D = main.encounter.get_node("BossCombatant") as Node3D
	boss.set_physics_process(false)
	var bar: AbilityBar = main.get_node("UILayer/HUD/AbilityBar") as AbilityBar
	await _verify_cleanse(main.player, boss, bar)
	TalentManager.add_points(10)
	var talent: TalentData = load("res://data/talents/talent_fireball_multicast.tres") as TalentData
	_check(TalentManager.learn_talent(main.player, talent), "multicast talent learns")
	main.player.try_activate_ability(&"fireball", {"target_unit": boss, "target_position": boss.global_position})
	var ability: GameplayAbilityInstance = main.player.ability_component.get_ability_instance(&"fireball")
	var spawned: bool = false
	for frame: int in range(120):
		await get_tree().process_frame
		var projectiles: Variant = ability.get_blackboard_var("spawned_projectiles")
		if projectiles is Array and (projectiles as Array).size() == 3:
			spawned = true
			break
	_check(spawned, "multicast fires three real projectiles")
	for frame: int in range(120):
		await get_tree().process_frame
	_check(int(boss.call("get_health")) < 12, "fireball impact damages real boss")
	_check(main.load_checkpoint(), "restore spell fixture")
	boss.set_physics_process(false)
	main.player.try_activate_ability(&"arcane_missiles", {"target_unit": boss, "target_position": boss.global_position})
	var arcane: GameplayAbilityInstance = main.player.ability_component.get_ability_instance(&"arcane_missiles")
	for frame: int in range(120):
		await get_tree().process_frame
	var missiles: Variant = arcane.get_blackboard_var("spawned_projectiles")
	_check(missiles is Array and (missiles as Array).size() == 3, "arcane missiles spawn three projectiles")
	_check(int(boss.call("get_health")) < 12, "arcane missiles damage boss")
	_check(main.load_checkpoint(), "restore sacrifice fixture")
	boss.set_physics_process(false)
	main.player.global_position = boss.global_position + Vector3(0, 0, -1.5)
	main.player.try_activate_ability(&"sacrifice", {"target_position": boss.global_position})
	for frame: int in range(120):
		await get_tree().process_frame
	_check(int(boss.call("get_health")) < 12, "sacrifice damages nearby boss")
	main.player.ability_component.cancel_ability(&"sacrifice")
	main.queue_free()
	for child: Node in get_children():
		if child is ProjectileBase:
			child.queue_free()
	await get_tree().process_frame
	if _failed == 0:
		print("PASS: spell integration fireball, multicast, arcane missiles, sacrifice and cleanse")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://spell_integration_checkpoint.json"))
	get_tree().quit.call_deferred(0 if _failed == 0 else 1)

func _verify_cleanse(player: Node3D, boss: Node3D, bar: AbilityBar) -> void:
	var definition: ActiveAbilityDefinition = load("res://data/abilities/cleanse.tres") as ActiveAbilityDefinition
	_check(is_instance_valid(definition) and definition.ability_id == &"cleanse", "load the active cleanse resource")
	if not is_instance_valid(definition):
		return

	var abilities: GameplayAbilityComponent = GameplayAbilitySystem.get_component_by_interface(
		player, "GameplayAbilityComponent"
	) as GameplayAbilityComponent
	var player_statuses: GameplayStatusComponent = GameplayAbilitySystem.get_component_by_interface(
		player, "GameplayStatusComponent"
	) as GameplayStatusComponent
	var boss_statuses: GameplayStatusComponent = GameplayAbilitySystem.get_component_by_interface(
		boss, "GameplayStatusComponent"
	) as GameplayStatusComponent
	var debuff: GameplayStatusData = GameplayStatusData.new()
	debuff.status_id = &"cleanse_test_debuff"
	debuff.tags = [&"status.debuff"]
	var buff: GameplayStatusData = GameplayStatusData.new()
	buff.status_id = &"cleanse_test_buff"
	buff.tags = [&"status.buff"]
	player_statuses.apply_status(debuff, boss)
	player_statuses.apply_status(buff, player)
	boss_statuses.apply_status(debuff, player)
	_check(player_statuses.has_status(debuff.status_id) and player_statuses.has_status(buff.status_id)
		and boss_statuses.has_status(debuff.status_id), "cleanse starts with active statuses on both entities")

	_check(not bar.ability_buttons.has(definition.ability_id), "cleanse has no button before learning")
	abilities.learn_ability(definition)
	_check(bar.ability_buttons.has(definition.ability_id), "learning cleanse adds a real ability button")
	_check(abilities.try_activate_ability(definition.ability_id, {"target_unit": boss}), "accept a cleanse cast")
	for frame: int in range(60):
		await get_tree().process_frame
		if not player_statuses.has_status(debuff.status_id):
			break
	_check(not player_statuses.has_status(debuff.status_id) and player_statuses.has_status(buff.status_id)
		and boss_statuses.has_status(debuff.status_id), "cleanse removes only the caster's debuff")
	_check(not abilities.can_activate_ability(definition.ability_id), "cleanse enters cooldown after casting")
	player_statuses.remove_status(buff.status_id)
	boss_statuses.remove_status(debuff.status_id)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed += 1
		push_error("FAIL: " + message)
