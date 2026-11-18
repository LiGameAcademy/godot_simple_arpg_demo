extends Node
## Checks every shipped skill definition and the player and axe combo references.

const ABILITY_DIRECTORY: String = "res://data/abilities/"
var _failed: int = 0

func _ready() -> void:
	var abilities: Dictionary[StringName, GameplayAbilityDefinition] = {}
	for filename: String in DirAccess.get_files_at(ABILITY_DIRECTORY):
		if not filename.ends_with(".tres"):
			continue
		var path: String = ABILITY_DIRECTORY + filename
		var ability: GameplayAbilityDefinition = ResourceLoader.load(path) as GameplayAbilityDefinition
		if ability == null:
			_fail("Could not load an ability definition from " + path)
			continue
		if ability.ability_id.is_empty() or abilities.has(ability.ability_id):
			_fail("Empty or duplicate ability ID in " + path)
			continue
		abilities[ability.ability_id] = ability

	var combo: ComboAbilityDefinition = abilities.get(&"combo_attack") as ComboAbilityDefinition
	var basic: ActiveAbilityDefinition = abilities.get(&"basic_attack") as ActiveAbilityDefinition
	var heavy: ActiveAbilityDefinition = abilities.get(&"heavy_attack") as ActiveAbilityDefinition
	if combo == null or basic == null or heavy == null or combo.combo_steps != [basic, basic, heavy]:
		_fail("The playable combo must resolve basic attack, basic attack, and heavy attack in order.")

	var player: PlayerData = load("res://data/player_data/barbarian.tres") as PlayerData
	var axe: ArpgEquip = load("res://data/items/axe.tres") as ArpgEquip
	if combo == null or player == null or axe == null or not player.initial_abilities.has(combo) or not axe.abilities.has(combo):
		_fail("The player and axe must reference the playable combo resource.")

	if _failed == 0:
		print("PASS: all ability assets (%d) and playable combo references" % abilities.size())
	get_tree().quit.call_deferred(0 if _failed == 0 else 1)

func _fail(message: String) -> void:
	_failed += 1
	push_error("FAIL: " + message)
