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
var _original_corruption: float = 1.0

func _ready() -> void:
	_register_dialogue()
	game_camera.look_at(Vector3(14, 1.5, 10))
	boss_actor.set_corruption(1.0)
	narrative.finished.connect(_on_finished)
	narrative.corruption_changed.connect(boss_actor.set_corruption)
	narrative.executor.trace_event.connect(_on_trace)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and narrative.is_playing():
		narrative.cancel("workshop interruption")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("start_cutscene") and not narrative.is_playing():
		_start_demo()

func _exit_tree() -> void:
	if is_instance_valid(narrative):
		narrative.cancel("workshop exiting")
	if is_instance_valid(player):
		DialogueManager.clear_initiator(player)

func _start_demo() -> void:
	_original_corruption = boss_actor.corruptioon_amount
	var targets: Array[Node] = [player, boss_actor]
	if narrative.start(game_camera, boss_focus.global_position, game_camera.global_transform,\
			narrative.definition, targets):
		_hud_visible = hud.visible
		hud.hide()
		player.set_control_lock(&"boss_intro", true)
		boss_actor.set_corruption(0.15)

func _on_finished(outcome: Executor.Outcome) -> void:
	if is_instance_valid(hud):
		hud.visible = _hud_visible
	if is_instance_valid(player):
		player.set_control_lock(&"boss_intro", false)
	if is_instance_valid(boss_actor):
		boss_actor.set_corruption(1.0 if outcome in [Executor.Outcome.COMPLETED, Executor.Outcome.SKIPPED] else _original_corruption)

func _register_dialogue() -> void:
	DialogueManager.set_initiator(player)
	var paths: Array[String] = ["intro_player", "intro_clone", "intro_challenge"]
	for id: String in paths:
		var node : DialogueNode = load("res://data/story/" + id + ".tres") as DialogueNode
		DialogueManager.dialogue_graph[node.node_id] = node

func _on_trace(run_id: int, index: int, event: StringName, detail: String) -> void:
	print("[%d: %d] %s %s " % [run_id, index, event, detail])
