extends Node3D
const Combatant = preload("res://prefabs/boss_combatant/boss_combatant.gd")
signal intro_requested()
signal health_changed(current: int, maximum: int)
signal attack_requested(amount: int)
signal defeated()
@onready var boss: Combatant = $BossCombatant
@onready var arrival: Marker3D = $PlayerArrival
@onready var focus: Marker3D = $BossFocus
@onready var entrance: Area3D = $Entrance
var _player: CharacterBody3D
var _pending: bool = false
var _original_boss_pose: Transform3D
var _original_actor_pose: Transform3D
var _original_corruption: float = 0.15

func _ready() -> void:
	entrance.body_entered.connect(_on_body_entered)
	entrance.body_exited.connect(_on_body_exited)
	boss.health_changed.connect(func(current: int, maximum: int) -> void: health_changed.emit(current, maximum))
	boss.attack_requested.connect(func(amount: int) -> void: attack_requested.emit(amount))
	boss.defeated.connect(_on_defeated)
	boss.actor.set_corruption(0.15)

func _physics_process(_delta: float) -> void:
	check_entry()

func initialize(player: CharacterBody3D) -> void:
	_player = player

func check_entry() -> void:
	if _pending and boss.get_health() > 0:
		intro_requested.emit()

func prepare_intro() -> void:
	_pending = false
	_original_boss_pose = boss.transform
	_original_actor_pose = boss.actor.transform
	_original_corruption = boss.actor.corruption_amount
	boss.stop_combat()
	boss.actor.set_corruption(0.15)
	boss.face_point(_player.global_position)

func apply_end_pose() -> void:
	boss.position = Vector3(14, 0.35, 8)
	boss.actor.set_corruption(1.0)
	boss.face_point(_player.global_position)

func start_combat() -> void:
	_pending = false
	if boss.get_health() > 0:
		boss.start_combat(_player)

func cancel_intro() -> void:
	boss.stop_combat()
	boss.transform = _original_boss_pose
	boss.actor.transform = _original_actor_pose
	boss.actor.set_corruption(_original_corruption)
	_pending = false

func stop_combat() -> void:
	boss.stop_combat()

func _on_body_entered(body: Node3D) -> void:
	if body != _player or boss.get_health() <= 0:
		return
	_pending = true
	check_entry()

func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_pending = false

func _on_defeated() -> void:
	_pending = false
	defeated.emit()

func restore_checkpoint(intro_seen: bool, defeated: bool, resolution_seen: bool) -> void:
	boss.restore_checkpoint(defeated)
	boss.position = Vector3(14, 0.35, 8)
	boss.actor.set_corruption(0.2 if resolution_seen else (1.0 if intro_seen else 0.15))
	boss.face_point(_player.global_position)
	_pending = not intro_seen
