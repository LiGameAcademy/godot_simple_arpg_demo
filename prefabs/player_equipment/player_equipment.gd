extends Node
class_name PlayerEquipment

## 宿主装备效果：属性、技能与模型；背包规则不依赖这些节点。
var _attributes: GameplayVitalAttributeComponent
var _abilities: GameplayAbilityComponent
var _source: Node
var _attachments: Dictionary[StringName, BoneAttachment3D] = {}
var _modifiers: Dictionary[StringName, Array] = {}
var _models: Dictionary[StringName, Node3D] = {}
var _ability_ids: Dictionary[StringName, Array] = {}
var _base_ability_ids: Array[StringName] = []


func initialize(attributes: GameplayVitalAttributeComponent, abilities: GameplayAbilityComponent, source: Node, attachments: Dictionary[StringName, BoneAttachment3D]) -> void:
	_attributes = attributes
	_abilities = abilities
	_source = source
	_attachments = attachments.duplicate()
	_base_ability_ids.assign(abilities.get_all_ability_instances().keys())


func apply_equipment(slot_id: StringName, instance: GameplayEquipInstance) -> void:
	_clear_slot(slot_id)
	if not is_instance_valid(instance) or not instance.item_config is ArpgEquip:
		return
	var config: ArpgEquip = instance.item_config as ArpgEquip
	var modifiers: Array[GameplayAttributeModifier] = []
	for name: String in config.attributes:
		if not _attributes.has_attribute(StringName(name)):
			continue
		var modifier: GameplayAttributeModifier = GameplayAttributeModifier.new()
		modifier.attribute_id = StringName(name)
		modifier.value = config.attributes[name]
		modifier.modifier_type = GameplayAttributeModifier.ModifierType.ADD
		modifier.source_id = StringName("equipment_%d_%s" % [_source.get_instance_id(), slot_id])
		_attributes.add_modifier(modifier)
		modifiers.append(modifier)
	_modifiers[slot_id] = modifiers
	var ids: Array[StringName] = []
	for definition: GameplayAbilityDefinition in config.abilities:
		if is_instance_valid(definition):
			if not _abilities.get_all_ability_instances().has(definition.ability_id):
				_abilities.learn_ability(definition)
			ids.append(definition.ability_id)
	_ability_ids[slot_id] = ids
	var attachment: BoneAttachment3D = _attachments.get(config.attachment_point, null)
	if is_instance_valid(attachment) and is_instance_valid(config.equip_model_scene):
		var model: Node3D = config.equip_model_scene.instantiate() as Node3D
		if is_instance_valid(model):
			attachment.add_child(model)
			_models[slot_id] = model


func _clear_slot(slot_id: StringName) -> void:
	var modifiers: Array = _modifiers.get(slot_id, [])
	for modifier: GameplayAttributeModifier in modifiers:
		if is_instance_valid(_attributes):
			_attributes.remove_modifier(modifier)
	_modifiers.erase(slot_id)
	var ids: Array = _ability_ids.get(slot_id, [])
	_ability_ids.erase(slot_id)
	for id: StringName in ids:
		if _base_ability_ids.has(id) or _another_slot_provides(id):
			continue
		if is_instance_valid(_abilities) and _abilities.get_all_ability_instances().has(id):
			_abilities.forget_ability(id)
	var model: Node3D = _models.get(slot_id, null)
	if is_instance_valid(model):
		model.queue_free()
	_models.erase(slot_id)


func _another_slot_provides(id: StringName) -> bool:
	for ids: Array in _ability_ids.values():
		if ids.has(id):
			return true
	return false
