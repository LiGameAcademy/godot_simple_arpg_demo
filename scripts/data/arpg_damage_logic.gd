extends DamageLogicStrategy
class_name ARPGDamageLogic
## Resolves physical damage from the supplied base damage and target defense.
@export var attack_attribute: StringName = &"attack"
@export var defense_attribute: StringName = &"defense"
func calculate(info: DamageInfo, target: Node, _instigator: Node, context: Dictionary) -> float:
	var attributes: GameplayVitalAttributeComponent = GameplayAbilitySystem.get_component_by_interface(target, "GameplayVitalAttributeComponent") as GameplayVitalAttributeComponent
	var defense: float = attributes.get_value(defense_attribute, 0.0) if attributes != null else 0.0
	var multiplier: float = float(context.get("damage_multiplier", 1.0)) * float(context.get("damage_multiplier_modifier", 1.0))
	return maxf(1.0, (info.base_damage - defense) * multiplier)
