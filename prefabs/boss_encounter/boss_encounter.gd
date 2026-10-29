extends Node3D

const Actor = preload("res://prefabs/boss_actor/boss_actor.gd")

signal intro_requested()
signal defeated()

@onready var actor: Actor = $BossActor
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
	actor.transform = _initial_actor_pose
	actor.set_corruption(1.0)
	face_actor_point(_player.global_position)

func cancel_intro() -> void:
	_can_resolve = false
	_pending = false
	actor.transform = _original_actor_pose
	actor.set_corruption(_original_corruption)

func debug_defeat() -> void:
	if not _can_resolve or _defeated:
		return
	_can_resolve = false
	_defeated = true
	actor.play_pose(&"death")
	defeated.emit()

func face_actor_point(point: Vector3) -> void:
	var offset: Vector3 = point - actor.global_position
	actor.rotation.y = atan2(offset.x, offset.z)

func _on_body_entered(body: Node3D) -> void:
	if body != _player or _can_resolve or _defeated:
		return
	_pending = true
	check_entry()

func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_pending = false











	
	
	
	
	
