extends Node
## Runs both three-hit and missed-finisher combos in the actual boss room.

const Main = preload("res://scenes/main.gd")
const Boss = preload("res://prefabs/boss_combatant/boss_combatant.gd")
const COMBO_ID: StringName = &"combo_attack"
const WINDUP_FRAMES: int = 40

var _failed: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_child(main)
	await get_tree().process_frame
	await main.transition_to_room(main.room_boss, main.encounter.arrival.global_position)
	main.encounter.entrance.body_entered.emit(main.player)
	main.narrative.skip()

	var boss: Boss = main.encounter.get_node("BossCombatant") as Boss
	boss.set_physics_process(false)
	main.player.set_physics_process(false)
	# Keep the boss alive across both trials even with the player's starting gear.
	boss.attribute_component.set_base_value(&"max_health", 1000.0)
	var health: HealthVital = boss.attribute_component.get_vital(&"health") as HealthVital
	health.apply_healing(1000.0)

	await _verify_combo(main.player, boss, health, true)
	health.apply_healing(1000.0)
	await _verify_combo(main.player, boss, health, false)

	main.queue_free()
	await get_tree().process_frame
	if _failed == 0:
		print("PASS: melee combo hit, miss and cooldown")
	get_tree().quit.call_deferred(0 if _failed == 0 else 1)

func _verify_combo(player: Player, boss: Boss, health: HealthVital, hit_finisher: bool) -> void:
	var aim: Vector3 = boss.global_position
	player.global_position = aim - Vector3(0.0, 0.0, 1.5)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var ability: GameplayAbilityInstance = player.ability_component.get_ability_instance(COMBO_ID)
	var definition: ComboAbilityDefinition = ability.get_definition() as ComboAbilityDefinition
	var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
	var initial_health: float = health.current_value
	var basic_damage: float = player.attribute_component.get_value(&"attack")
	var hits: Array[float] = []
	var observe: Callable = func(info: DamageInfo, amount: float) -> void:
		if info.instigator == player and amount > 0.0:
			hits.append(amount)
	health.damage_applied.connect(observe)
	for step: int in range(1, 3):
		player.try_activate_ability(COMBO_ID, {"target_position": aim})
		await _wait_frames(WINDUP_FRAMES)
		_check(hits.size() == step and is_equal_approx(health.current_value, initial_health - step * basic_damage),
			"basic combo step %d deals its normal damage exactly once" % step)
		_check(ability.is_active and cooldown.get_cooldown_remaining(ability) == 0.0,
			"cooldown has not started after basic step %d" % step)

	if not hit_finisher:
		boss.global_position = aim + Vector3(6.0, 0.0, 0.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
	var before_heavy: float = health.current_value
	player.try_activate_ability(COMBO_ID, {"target_position": aim})
	await _wait_frames(10)
	_check(ability.is_active and cooldown.get_cooldown_remaining(ability) == 0.0
		and is_equal_approx(health.current_value, before_heavy), "finisher windup does not damage or start cooldown")
	await _wait_frames(WINDUP_FRAMES)

	if hit_finisher:
		var heavy_damage: float = basic_damage * 1.5
		_check(hits.size() == 3 and is_equal_approx(health.current_value, before_heavy - heavy_damage),
			"third step hits once for heavy attack damage")
	else:
		_check(hits.size() == 2 and is_equal_approx(health.current_value, before_heavy),
			"third step misses without damage")
	var remaining: float = cooldown.get_cooldown_remaining(ability)
	_check(not ability.is_active and remaining > 0.0 and remaining <= definition.cooldown_duration
		and not player.ability_component.can_activate_ability(COMBO_ID), "finished combo is locked by its cooldown")

	await _wait_frames(ceili(definition.cooldown_duration * Engine.physics_ticks_per_second) + 4)
	_check(player.ability_component.can_activate_ability(COMBO_ID), "combo becomes available when cooldown expires")
	boss.global_position = aim
	health.damage_applied.disconnect(observe)

func _wait_frames(frames: int) -> void:
	for frame: int in range(frames):
		await get_tree().physics_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed += 1
		push_error("FAIL: " + message)
