extends Node
## Checks a real projectile cast and the existing multicast talent integration.
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
		print("PASS: spell integration fireball, multicast, arcane missiles and sacrifice")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://spell_integration_checkpoint.json"))
	get_tree().quit.call_deferred(0 if _failed == 0 else 1)
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed += 1
		push_error("FAIL: " + message)
