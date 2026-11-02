extends CharacterBase
class_name Enemy
## Owns enemy life-cycle presentation; the room forwards kill and loot events.
signal defeated(enemy_id: String)
signal loot_requested(scene: PackedScene, position: Vector3, impulse: Vector3)
const Profile = preload("res://scripts/core/combat_profile.gd")
const HEALTH = preload("res://data/combat/combat_health_vital.tres")
const MAX_HEALTH = preload("res://data/attributes/max_health.tres")
@export var profile: Profile = preload("res://data/combat/enemy_profile.tres")
@export var loot_scene: PackedScene
@export var enemy_id: String = "skeleton"
var _awake: bool = false
func _ready() -> void:
	super()
	died.connect(_on_defeated)
	hide()
func awaken() -> void:
	if _awake or _is_dead:
		return
	_awake = true
	show()
	_visual_adapter.play_animation(&"awaken")
func _init_components() -> void:
	var stats: GameplayAttributeSet = GameplayAttributeSet.new()
	stats.attributes[MAX_HEALTH] = float(profile.max_health)
	attribute_component.initialize([stats], [HEALTH])
func take_damage(amount: int) -> void:
	var health: HealthVital = attribute_component.get_vital(&"health") as HealthVital
	if health != null and amount > 0:
		var damage: DamageInfo = DamageInfo.new()
		damage.final_damage = float(amount)
		health.apply_damage(damage, self)
func _on_defeated(_entity: CharacterBase) -> void:
	defeated.emit(enemy_id)
	if loot_scene != null:
		var impulse: Vector3 = Vector3(randf_range(-2, 2), 2, randf_range(-2, 2)).normalized() * 5
		loot_requested.emit(loot_scene, global_position + Vector3.UP, impulse)
	collision_layer = 0
	collision_mask = 0
