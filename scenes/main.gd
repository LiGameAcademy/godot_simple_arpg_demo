extends Node3D

const Player = preload("res://prefabs/player.gd")
const Narrative = preload("res://scenes/arpg_narrative_controller/arpg_narrative_controller.gd")
const Encounter = preload("res://prefabs/boss_encounter/boss_encounter.gd")
const Executor = preload("res://addons/laoli_dialogue_system/scenes/cutscene_player/cutscene_player.gd")

const Snapshot = preload("res://scripts/core/story_snapshot.gd")
const Store = preload("res://addons/laoli_dialogue_system/scripts/core/save/checkpoint_store.gd")
const QuestCodec = preload("res://addons/laoli_dialogue_system/scripts/core/save/quest_snapshot.gd")
const CheckpointUI = preload("res://ui/checkpoint_controls/checkpoint_controls.gd")

const RESOLUTION : CutsceneDefinition = preload("res://data/story/boss_resolution.tres")
# 运镜时间 (秒)
const TRANSITION_TIME = 1.5 
const DIALOGUE_PATH = "res://data/dialogues/dialogue.json"
const CLONE_QUEST: Quest = preload("res://data/story/clone_quest.tres")
const INTRO_LINES: Array[DialogueNode] = [
	preload("res://data/story/intro_player.tres"),
	preload("res://data/story/intro_clone.tres"),
	preload("res://data/story/intro_challenge.tres"),
	preload("res://data/story/clone_last_words.tres")
]

@export var registered_quests: Array[Quest] = []
@export var checkpoint_path: String = "user://story_checkpoint.json"

@onready var player: Player = $RoomLobby/Player
@onready var inventory_ui: MarginContainer = $UILayer/HUD/inventory
@onready var hud: Control = $UILayer/HUD
@onready var quest_log: QuestLogUI = $QuestLogUI
@onready var camera: Camera3D = $Camera3D
@onready var room_lobby: DungeonRoom = $RoomLobby
@onready var room_dungeon: DungeonRoom = $RoomDungeon
@onready var room_boss: DungeonRoom = $RoomBoss
@onready var encounter: Encounter = $RoomBoss/BossEncounter
@onready var narrative: Narrative = $ArpgNarrativeController
@onready var checkpoint_ui: CheckpointUI = $CheckpointControls

var checkpoint_store: Store

var _transitioning : bool = false
var _room : DungeonRoom
var _intro_seen: bool = false
var _boss_defeated: bool = false
var _resolution_pending: bool = false
var _resolution_seen: bool = false
var _active_story: StringName = &""
var _hud_visible: bool = true
var _quest_log_visible: bool = true
var _player_visual_pose: Transform3D
var _transition_tween: Tween
var _checkpoint_loading: bool = false

func _ready() -> void:
	if not DialogueManager.set_initiator(player):
		push_error("对话服务仍被旧场景占用。")
	_register_actions()
	_register_conditions()
	_register_quests()
	_init_dialogue()
	_room = room_lobby
	#var start_room = $RoomLobby
	camera.global_position = _room.camera_marker.global_position
	var player_inventory : C_Inventory = player.get_inventory() # 确保你在player脚本中实现了这个方法
	inventory_ui.initialize(player_inventory)
	_register_intro_dialogue()
	encounter.initialize(player)
	room_dungeon.room_exit_requested.connect(_on_passage.bind(room_dungeon, room_boss, encounter.arrival))
	room_boss.room_exit_requested.connect(_on_passage.bind(room_boss, room_dungeon, $RoomDungeon/ReturnArrival))
	encounter.intro_requested.connect(_request_intro)
	narrative.corruption_changed.connect(encounter.actor.set_corruption)
	narrative.finished.connect(_on_story_finished)
	narrative.actor_cue.connect(_on_actor_cue)
	encounter.defeated.connect(_on_boss_defeated)
	checkpoint_store = Store.new(checkpoint_path)
	checkpoint_ui.save_requested.connect(save_checkpoint)

func _process(_delta: float) -> void:
	checkpoint_ui.set_available(_can_save_checkpoint(), false)
	if _resolution_pending and not _transitioning and _room == room_boss \
		and not narrative.is_playing() and not DialogueManager.is_dialogue_active() and _player_ready():
		_resolution_pending = false
		_begin_story(RESOLUTION)

func _unhandled_input(event) -> void:
	if event.is_action_pressed("save_story_checkpoint"):
		save_checkpoint()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("debug_defeat_boss"):
		if _can_debug_defeat():
			encounter.debug_defeat()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_inventory") and player.can_control() and not _transitioning:
		if inventory_ui.visible:
			inventory_ui.hide()
		else:
			inventory_ui.open()

func _exit_tree() -> void:
	_active_story = &""
	if is_instance_valid(narrative):
		narrative.cancel("宿主退出")
	if is_instance_valid(player):
		DialogueManager.clear_initiator(player)
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()

func transition_to_room(target_room: DungeonRoom, target_position: Vector3) -> void:
	if _transitioning or narrative.is_playing():
		return
	_transitioning = true
	player.set_control_lock(&"room_transition", true)
	player.set_physics_process(false)
	player.hide()
	_transition_tween = create_tween()
	_transition_tween.tween_property(camera, "global_position", target_room.camera_marker.global_position,
		TRANSITION_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _transition_tween.finished
	player.reparent(target_room)
	player.global_position = target_position
	player.velocity = Vector3.ZERO
	_room = target_room
	player.show()
	player.set_physics_process(true)
	player.set_control_lock(&"room_transition", false)
	_transitioning = false
	target_room.on_player_enter()
	if target_room == room_boss:
		encounter.check_entry()

func save_checkpoint() -> bool:
	if not _can_save_checkpoint():
		checkpoint_ui.show_message("当前无法保存，请结束对话、演出或切房后重试")
		return false
	var snapshot: Dictionary = {
		"schema_version": Snapshot.VERSION,
		"checkpoint": Snapshot.phase(_intro_seen, _boss_defeated),
		"story": {"intro_seen": _intro_seen, "boss_defeated": _boss_defeated, "resolution_seen": _resolution_seen},
		"quests": QuestCodec.capture(QuestManager.active_quests, QuestManager.completed_quest_ids),
		"history": DialogueManager.transcript.entries.duplicate(true)
	}
	var validator: Snapshot = Snapshot.new()
	if not validator.validate(snapshot, GameState.quest_database):
		checkpoint_ui.show_message("保存失败：" + validator.last_error)
		return false
	if not checkpoint_store.save_snapshot(snapshot):
		checkpoint_ui.show_message("保存失败：" + checkpoint_store.last_error)
		return false
	checkpoint_ui.show_message("叙事检查点已保存 · " + _checkpoint_label(String(snapshot["checkpoint"])))
	return true

func _can_save_checkpoint() -> bool:
	return not _checkpoint_loading and not _transitioning \
		and is_instance_valid(narrative) and is_instance_valid(player) and not narrative.is_playing() \
		and not DialogueManager.is_dialogue_active()

func _checkpoint_label(phase: String) -> String:
	match phase:
		"before_intro": return "初遇之前"
		"before_resolution": return "入场已提交 · 按 K 可结算击败"
		"after_boss": return "击败克隆体之后"
	return "未知节点"

func _register_quests() -> void:
	for quest: Quest in registered_quests:
		if not GameState.quest_database.has(quest.id):
			GameState.register_quest(quest)
	if not GameState.quest_database.has(CLONE_QUEST.id):
		GameState.register_quest(CLONE_QUEST)

func _register_actions() -> void:
	if not DialogueManager.has_registered_action("give_item"):
		DialogueManager.register_action("give_item", ActionAddItem.new())
	if not DialogueManager.has_registered_action("remove_item"):
		DialogueManager.register_action("remove_item", ActionRemoveItem.new())
	if not DialogueManager.has_registered_action("give_reward"):
		DialogueManager.register_action("give_reward", ActionGiveReward.new())
	if not DialogueManager.has_registered_action("affinity_change"):
		DialogueManager.register_action("affinity_change", ActionChangeAffinity.new())

func _register_conditions() -> void:
	if not DialogueManager.has_registered_condition("has_item"):
		DialogueManager.register_condition("has_item", ConditionHasItem.new())

func _register_intro_dialogue() -> void:
	for node : DialogueNode in INTRO_LINES:
		DialogueManager.dialogue_graph[node.node_id] = node

func _init_dialogue() -> void:
	DialogueManager.load_dialogue_file(DIALOGUE_PATH)

func _commit_intro() -> bool:
	if _intro_seen:
		return true
	var status: int = QuestManager.get_quest_status(CLONE_QUEST.id)
	if status == QuestManager.QuestStatus.UNAVAILABLE:
		narrative.presentation.overlay.show_combat_status("演出任务未注册，请检查配置。")
		return false
	if status == QuestManager.QuestStatus.CAN_ACCEPT:
		QuestManager.accept_quest(CLONE_QUEST)
	var final_status: int = QuestManager.get_quest_status(CLONE_QUEST.id)
	if final_status not in [QuestManager.QuestStatus.IN_PROGRESS, QuestManager.QuestStatus.READY_TO_TURN_IN, QuestManager.QuestStatus.FINISHED]:
		narrative.presentation.overlay.show_combat_status("演出任务接取失败，请检查任务状态。")
		return false
	_intro_seen = true
	return true

func _begin_story(sequence: CutsceneDefinition) -> bool:
	_hud_visible = hud.visible
	_quest_log_visible = quest_log.visible
	_player_visual_pose = player.visuals.transform
	var room_view: Transform3D = camera.global_transform
	room_view.origin = room_boss.camera_marker.global_position
	var targets: Array[Node] = [player, encounter, encounter.actor]
	if not narrative.start(camera, encounter.focus.global_position, room_view, sequence, targets):
		narrative.presentation.cutscene_overlay.show_combat_status("无法开始演出：" + narrative.last_error)
		return false
	_active_story = sequence.cutscene_id
	player.set_control_lock(&"boss_intro", true)
	hud.hide()
	quest_log.hide()
	return true

func _request_intro() -> void:
	if _intro_seen or _transitioning or _room != room_boss or narrative.is_playing() or not _player_ready():
		return
	if _begin_story(narrative.definition):
		encounter.prepare_intro()

func _player_ready() -> bool:
	return is_instance_valid(player) and player.can_control() \
		and player.animation_state_machine.get_current_node() == &"movement"

func _can_debug_defeat() -> bool:
	return _intro_seen and not _boss_defeated and not _transitioning and _room == room_boss \
		and not narrative.is_playing() and not DialogueManager.is_dialogue_active() and player.can_control()

func _on_passage(body: CharacterBody3D, source_room: DungeonRoom, target_room: DungeonRoom, arrival: Marker3D) -> void:
	if body != player or source_room != _room:
		return
	transition_to_room(target_room, arrival.global_position)

func _on_actor_cue(cue: StringName) -> void:
	match cue:
		&"seal_release":
			encounter.actor.set_corruption(0.2)
		&"mirror_player":
			player.face_point(encounter.actor.global_position + Vector3(2, 0, 0))
		&"mirror_clone":
			encounter.face_actor_point(player.global_position + Vector3(-2, 0, 0))
		&"break_sync":
			encounter.face_actor_point(player.global_position)

func _on_story_finished(outcome: Executor.Outcome) -> void:
	var ended_story: StringName = _active_story
	_active_story = &""
	if ended_story == &"" or not is_inside_tree() or is_queued_for_deletion():
		return
	var player_available: bool = is_instance_valid(player) and player.is_inside_tree() and not player.is_queued_for_deletion()
	var encounter_available: bool = is_instance_valid(encounter) and is_instance_valid(encounter.actor)
	var success: bool = outcome in [Executor.Outcome.COMPLETED, Executor.Outcome.SKIPPED] and player_available and encounter_available
	if ended_story == &"boss_intro":
		if success:
			success = _commit_intro()
		if encounter_available:
			if success:
				encounter.commit_intro()
				narrative.presentation.cutscene_overlay.show_combat_status("按 K 模拟击败异化回响")
			else:
				encounter.cancel_intro()
	elif ended_story == &"boss_resolution":
		if success:
			_resolution_seen = true
			encounter.actor.set_corruption(0.2)
			narrative.presentation.cutscene_overlay.show_combat_status("封印已解除 · 带着回响继续前行")
		elif encounter_available:
			encounter.actor.set_corruption(1.0)
	if player_available:
		if is_instance_valid(player.visuals):
			player.visuals.transform = _player_visual_pose
		player.set_control_lock(&"boss_intro", false)
	if is_instance_valid(hud):
		hud.visible = _hud_visible
	if is_instance_valid(quest_log):
		quest_log.visible = _quest_log_visible

func _on_boss_defeated() -> void:
	if not _intro_seen or _boss_defeated:
		return
	_boss_defeated = true
	GameState.emit_game_event("enemy_died", {"enemy_id": "异化回响"})
	_resolution_pending = true
	narrative.presentation.cutscene_overlay.show_combat_status("异化回响已击败 · 任务标完成")
