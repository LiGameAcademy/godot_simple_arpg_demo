extends Node

const Actor = preload("res://prefabs/boss_actor/boss_actor.gd")
const Presentation = preload("res://ui/cinematic_presentation/cinematic_presentation.gd")
const Player = preload("res://prefabs/player.gd")

@onready var boss_actor: Actor = $RoomBoss/BossEncounter/BossActor
@onready var boss_focus: Marker3D = $RoomBoss/BossEncounter/BossFocus
@onready var game_camera: Camera3D = $GameCamera
@onready var player: Player = $Player
@onready var hud: Control = $UILayer/HUD
@onready var presentation: Presentation = $CinematicPresentation

var _busy : bool = false

func _ready() -> void:
	game_camera.look_at(Vector3(14, 1.5, 10))
	boss_actor.set_corruption(1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_cutscene") and not _busy:
		_play_demo()

func _play_demo() -> void:
	_busy = true
	var was_visible : bool = hud.visible
	player.set_control_lock(&"boss_intro", true)
	hud.hide()
	boss_actor.set_corruption(0.15)
	presentation.prepare(game_camera, boss_focus.global_position, game_camera.global_transform)
	if not presentation.corruption_changed.is_connected(boss_actor.set_corruption):
		presentation.corruption_changed.connect(boss_actor.set_corruption)
	var clips : Array[String] = [&"establish", &"corrupt", &"return", &"title"]
	for index: int in range(clips.size()):
		if not presentation.play_clip(1, index, clips[index]):
			break
		await presentation.clip_finished
	presentation.cleanup()
	player.set_control_lock(&"boss_intro", false)
	hud.visible = was_visible
	_busy = false
