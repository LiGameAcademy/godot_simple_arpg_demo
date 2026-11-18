extends GE_ApplyDamage
## Heals the caster from the damage drained from the chosen target.

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	if not is_instance_valid(instigator) or target == instigator:
		return

	var target_health: HealthVital = _get_health(target)
	if target_health == null:
		return
	var available: float = target_health.current_value
	context["final_damage"] = 0.0
	super(target, instigator, context)

	var caster_health: HealthVital = _get_health(instigator)
	if caster_health == null:
		return
	var drained: float = minf(available, context.get("final_damage", 0.0))
	var restored: float = caster_health.apply_healing(drained)
	if restored > 0.0:
		AbilityEventBus.trigger_game_event(&"healing_applied", {
			"target": instigator,
			"instigator": instigator,
			"amount": restored,
		})

func _get_health(entity: Node) -> HealthVital:
	var attributes: GameplayVitalAttributeComponent = GameplayAbilitySystem.get_component_by_interface(
		entity, vital_comp_name, false
	) as GameplayVitalAttributeComponent
	return attributes.get_vital(vital_id) as HealthVital if attributes != null else null
