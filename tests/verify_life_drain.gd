extends Node
## Exercises the actual life drain resource, its Vital effects and its beam scene.

## Load this fixture with the script to keep Godot 4.7.2 script loading order stable.
const LIFE_DRAIN = preload("res://data/abilities/life_drain.tres")

class Combatant extends Node3D:
	var attributes: GameplayVitalAttributeComponent

	func get_gameplay_attribute_component() -> GameplayAttributeComponent:
		return attributes

	func get_gameplay_vital_attribute_component() -> GameplayVitalAttributeComponent:
		return attributes

	func get_attachment_point(_name: StringName) -> Node3D:
		return self

var _failed: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var definition: ChannelingAbilityDefinition = LIFE_DRAIN as ChannelingAbilityDefinition
	_check(definition != null and definition.channeling_cue != null, "load life drain and its beam Cue")
	if definition == null:
		get_tree().quit(1)
		return

	var caster: Combatant = _make_combatant(Vector3.ZERO, 30.0)
	var target: Combatant = _make_combatant(Vector3(0, 0, 3), 30.0)
	caster.attributes.modify_vital(&"health", -20.0)
	var ability_component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	caster.add_child(ability_component)
	ability_component.set_process(false)
	ability_component.learn_ability(definition)
	var ability: GameplayAbilityInstance = ability_component.get_ability_instance(&"life_drain")
	_check(ability_component.try_activate_ability(&"life_drain", {"target_unit": target}), "accept life drain")
	ability.update(0.01)
	var beam: LifeDrainBeam
	for child: Node in caster.get_children():
		if child is LifeDrainBeam:
			beam = child as LifeDrainBeam
	_check(ability.is_active and is_instance_valid(beam), "start channel and create a real beam")
	_check(_health(caster) == 15.0 and _health(target) == 25.0, "first tick damages target and heals caster")
	_check(not ability_component.can_activate_ability(&"life_drain"), "first tick starts cooldown")
	target.position = Vector3(0, 0, 5)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_instance_valid(beam) and beam.global_position.is_equal_approx(Vector3(0, 0, 2.5)),
		"beam follows moving target")

	ability.update(0.5)
	_check(_health(caster) == 20.0 and _health(target) == 20.0, "second tick drains again")
	ability.set_blackboard_var("event_input_released", true)
	ability.update(0.5)
	await get_tree().process_frame
	_check(not ability.is_active and ability.channel_end_reason == &"released", "release ends the channel")
	_check(not is_instance_valid(beam), "ending frees the beam")
	_check(_health(caster) == 20.0 and _health(target) == 20.0, "release prevents a due extra tick")
	var ability_ref: WeakRef = weakref(ability)
	ability = null
	caster.queue_free()
	target.queue_free()
	await get_tree().process_frame
	_check(not is_instance_valid(caster) and not is_instance_valid(target), "teardown frees both combatants")
	_check(ability_ref.get_ref() == null, "freeing the caster releases its learned ability")
	if _failed == 0:
		print("PASS: life drain channel and beam")
	get_tree().quit(0 if _failed == 0 else 1)

func _make_combatant(location: Vector3, max_health: float) -> Combatant:
	var entity: Combatant = Combatant.new()
	entity.position = location
	entity.attributes = GameplayVitalAttributeComponent.new()
	entity.add_child(entity.attributes)
	add_child(entity)
	var maximum: GameplayAttribute = GameplayAttribute.new()
	maximum.attribute_id = &"max_health"
	var intelligence: GameplayAttribute = GameplayAttribute.new()
	intelligence.attribute_id = &"intelligence"
	var attributes: GameplayAttributeSet = GameplayAttributeSet.new()
	attributes.attributes[maximum] = max_health
	attributes.attributes[intelligence] = 10.0
	entity.attributes.initialize([attributes], [HealthVital.new()])
	return entity

func _health(entity: Combatant) -> float:
	return entity.attributes.get_vital_value(&"health")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed += 1
		push_error("FAIL: " + message)
