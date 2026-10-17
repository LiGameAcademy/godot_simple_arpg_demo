extends Node3D

const Actor = preload("res://prefabs/boss_actor/boss_actor.gd")
const Player = preload("res://prefabs/player.gd")
const Narrative = preload("res://scenes/arpg_narrative_controller/arpg_narrative_controller.gd")
const Executor = preload("res://addons/laoli_dialogue_system/scenes/cutscene_player/cutscene_player.gd")

@onready var boss_actor: Actor = $RoomBoss/BossEncounter/BossActor
@onready var boss_focus: Marker3D = $RoomBoss/BossEncounter/BossFocus
@onready var game_camera: Camera3D = $GameCamera
@onready var player: Player = $Player
@onready var hud: Control = $UILayer/HUD
@onready var narrative: Narrative = $ArpgNarrativeController

var _hud_visible : bool = true

func _ready() -> void:
	game_camera.look_at(Vector3(14, 1.5, 10))
	boss_actor.set_corruption(1.0)
	narrative.finished.connect(_on_finished)
	narrative.corruption_changed.connect(boss_actor.set_corruption)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_cutscene") and not narrative.is_playing():
		_start_demo()
	
func _start_demo() -> void:
	if narrative.start(game_camera, boss_focus.global_position, game_camera.global_transform):
		_hud_visible = hud.visible
		hud.hide()
		player.set_control_lock(&"boss_intro", true)
		boss_actor.set_corruption(0.15)

func _on_finished(_outcome: Executor.Outcome) -> void:
	hud.visible = _hud_visible
	player.set_control_lock(&"boss_intro", false)
