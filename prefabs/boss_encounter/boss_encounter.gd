extends Node3D

const Combatant = preload("res://prefabs/boss_combatant/boss_combatant.gd")
const Actor = preload("res://prefabs/boss_actor/boss_actor.gd")

signal intro_requested()
signal defeated()
signal boss_health_changed(current: int, maximum: int)
signal player_damage_requested(amount: int)

@onready var combatant: Combatant = $BossCombatant
@onready var actor: Actor = $BossCombatant/BossActor
@onready var arrival: Marker3D = $PlayerArrival
@onready var focus: Marker3D = $BossFocus
@onready var entrance: Area3D = $Entrance

var _player : CharacterBody3D
var _pending : bool = false
var _can_resolve : bool = false
var _defeated: bool = false
var _initial_actor_pose : Transform3D
var _original_actor_pose: Transform3D
var _original_corruption: float = 0.15

func _ready() -> void:
	combatant.health_changed.connect(_on_health_changed)
	combatant.defeated.connect(_on_combatant_defeated)
	combatant.attack_requested.connect(_on_attack_requested)
	_initial_actor_pose = actor.transform
	entrance.body_entered.connect(_on_body_entered)
	entrance.body_exited.connect(_on_body_exited)
	actor.set_corruption(0.15)

func _physics_process(_delta: float) -> void:
	check_entry()

func initialize(player: CharacterBody3D) -> void:
	_player = player

func check_entry() -> void:
	if _pending and not _can_resolve and not _defeated:
		intro_requested.emit()

func prepare_intro() -> void:
	_pending = false
	_original_actor_pose = actor.transform
	_original_corruption = actor.corruptioon_amount
	actor.set_corruption(0.15)
	face_actor_point(_player.global_position)

func commit_intro() -> void:
	if _defeated:
		return
	_pending = false
	_can_resolve = true
	combatant.start_combat(_player)
	actor.transform = _initial_actor_pose
	actor.set_corruption(1.0)
	face_actor_point(_player.global_position)

func cancel_intro() -> void:
	combatant.stop_combat()
	_can_resolve = false
	_pending = false
	actor.transform = _original_actor_pose
	actor.set_corruption(_original_corruption)

func debug_defeat() -> void:
	if _can_resolve and not _defeated:
		combatant.take_damage(combatant.profile.max_health)

func _on_combatant_defeated() -> void:
	if _defeated:
		return
	_can_resolve = false
	_defeated = true
	defeated.emit()

func _on_attack_requested(amount: int) -> void:
	player_damage_requested.emit(amount)

func stop_combat() -> void:
	combatant.stop_combat()

func face_actor_point(point: Vector3) -> void:
	var offset: Vector3 = point - actor.global_position
	actor.rotation.y = atan2(offset.x, offset.z)

func restore_checkpoint(intro_seen: bool, defeated: bool, resolution_seen: bool) -> void:
	_defeated = defeated
	_can_resolve = intro_seen and not defeated
	_pending = not intro_seen
	actor.transform = _initial_actor_pose
	combatant.restore_checkpoint(defeated)
	if intro_seen and not defeated:
		combatant.start_combat(_player)
	actor.set_corruption(0.2 if resolution_seen else (1.0 if intro_seen else 0.15))
	face_actor_point(_player.global_position)

func _on_body_entered(body: Node3D) -> void:
	if body != _player or _can_resolve or _defeated:
		return
	_pending = true
	check_entry()

func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_pending = false











	
	
	
	
	

func _on_health_changed(current: int, maximum: int) -> void:
	boss_health_changed.emit(current, maximum)
