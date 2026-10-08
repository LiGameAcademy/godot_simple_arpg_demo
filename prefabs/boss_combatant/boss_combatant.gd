extends CharacterBody3D
const Profile = preload("res://scripts/core/combat_profile.gd")
const Actor = preload("res://prefabs/boss_actor/boss_actor.gd")
signal health_changed(current: int, maximum: int)
signal attack_requested(amount: int)
signal defeated()
@export var profile: Profile
@onready var actor: Actor = $BossActor
@onready var hurtbox: Area3D = $Hurtbox
var _target: Node3D
var _health: int = 0
var _active: bool = false
var _cooldown: float = 0.0
var _windup: float = -1.0
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

func _ready() -> void:
	_health = profile.max_health
	hurtbox.damage_requested.connect(take_damage)

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
	if _health <= 0 or not is_instance_valid(target):
		return
	_target = target
	_active = true
	_cooldown = profile.attack_interval
	health_changed.emit(_health, profile.max_health)

func stop_combat() -> void:
	_active = false
	_windup = -1.0
	velocity = Vector3.ZERO

func take_damage(amount: int) -> void:
	if not _active or amount <= 0 or _health <= 0:
		return
	_health = maxi(_health - amount, 0)
	health_changed.emit(_health, profile.max_health)
	if _health == 0:
		stop_combat()
		actor.play_pose(&"death")
		defeated.emit()

func is_combat_active() -> bool:
	return _active

func get_health() -> int:
	return _health

func face_point(point: Vector3) -> void:
	var offset: Vector3 = point - global_position
	actor.rotation.y = atan2(offset.x, offset.z)

func restore_checkpoint(defeated: bool) -> void:
	stop_combat()
	_target = null
	_health = 0 if defeated else profile.max_health
	_cooldown = profile.attack_interval
	actor.restore_checkpoint(defeated)
