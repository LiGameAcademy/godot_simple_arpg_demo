extends CharacterBase
## Owns boss combat timing; shared vital state determines damage and defeat.
const Profile = preload("res://scripts/core/combat_profile.gd")
const Actor = preload("res://prefabs/boss_actor/boss_actor.gd")
const HEALTH = preload("res://data/combat/combat_health_vital.tres")
const MAX_HEALTH = preload("res://data/attributes/max_health.tres")
signal health_changed(current: int, maximum: int)
signal attack_requested(amount: int)
signal defeated()
@export var profile: Profile
@onready var actor: Actor = $BossActor
@onready var hurtbox: Area3D = $Hurtbox
var _target: Node3D
var _active: bool = false
var _cooldown: float = 0.0
var _windup: float = -1.0
var _spawn: Transform3D
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
func _ready() -> void:
	super()
	_spawn = transform
	hurtbox.damage_requested.connect(take_damage)
	died.connect(_on_defeated)
	var health: HealthVital = attribute_component.get_vital(&"health") as HealthVital
	health.damage_received.connect(_on_damage_received)
	health.value_changed.connect(_on_health_value_changed)
func _init_components() -> void:
	var stats: GameplayAttributeSet = GameplayAttributeSet.new()
	stats.attributes[MAX_HEALTH] = float(profile.max_health)
	attribute_component.initialize([stats], [HEALTH])
func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(_target):
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var offset: Vector3 = _target.global_position - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	_cooldown = maxf(_cooldown - delta, 0.0)
	velocity.x = 0.0
	velocity.z = 0.0
	if _windup >= 0.0:
		_windup -= delta
		if _windup < 0.0 and distance <= profile.attack_range:
			attack_requested.emit(profile.attack_damage)
	elif distance > profile.attack_range:
		var direction: Vector3 = offset.normalized()
		velocity.x = direction.x * profile.move_speed
		velocity.z = direction.z * profile.move_speed
	elif _cooldown <= 0.0:
		_windup = profile.attack_windup
		_cooldown = profile.attack_interval
		actor.play_pose(&"attack")
	if distance > 0.01:
		actor.rotation.y = atan2(offset.x, offset.z)
	actor.set_movement_speed(Vector2(velocity.x, velocity.z).length())
	move_and_slide()
func start_combat(target: Node3D) -> void:
	if get_health() <= 0 or not is_instance_valid(target):
		return
	_target = target
	_active = true
	_cooldown = profile.attack_interval
	health_changed.emit(get_health(), profile.max_health)
func stop_combat() -> void:
	_active = false
	_windup = -1.0
	velocity = Vector3.ZERO
func take_damage(amount: int) -> void:
	if not _active or amount <= 0:
		return
	var health: HealthVital = attribute_component.get_vital(&"health") as HealthVital
	var damage: DamageInfo = DamageInfo.new()
	damage.final_damage = float(amount)
	health.apply_damage(damage, self)
func is_combat_active() -> bool:
	return _active
func get_health() -> int:
	return int(attribute_component.get_vital_value(&"health"))
func face_point(point: Vector3) -> void:
	var offset: Vector3 = point - global_position
	actor.rotation.y = atan2(offset.x, offset.z)
func restore_checkpoint(defeated: bool) -> void:
	stop_combat()
	_target = null
	transform = _spawn
	var health: HealthVital = attribute_component.get_vital(&"health") as HealthVital
	health.initialize(attribute_component)
	_is_dead = defeated
	if defeated:
		health.current_value = 0.0
	else:
		remove_from_group("death")
	actor.restore_checkpoint(defeated)
func _play_death_animation() -> void:
	_is_dead = true
	actor.play_pose(&"death")
func _on_defeated(_entity: CharacterBase) -> void:
	stop_combat()
	defeated.emit()

func _on_damage_received(damage: DamageInfo) -> void:
	if not _active:
		damage.final_damage = 0.0

func _on_health_value_changed(current: float, maximum: float, _percent: float, _regen: bool) -> void:
	health_changed.emit(int(current), int(maximum))
