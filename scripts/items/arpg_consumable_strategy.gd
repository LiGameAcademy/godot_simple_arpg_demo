extends ConsumableUseStrategy
class_name ArpgConsumableStrategy

func _use_item(item: GameplayItemInstance, user: Node) -> bool:
	var character: CharacterBase = user as CharacterBase
	var config: ArpgConsumableItem = item.item_config as ArpgConsumableItem
	if not is_instance_valid(character) or not is_instance_valid(config):
		return false
	var attributes: GameplayVitalAttributeComponent = character.get_attribute_component()
	return is_instance_valid(attributes) and attributes.modify_vital(&"health", config.heal_amount)
