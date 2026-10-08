extends Node3D
const PlayerActor = preload("res://prefabs/player.gd")
const Narrative = preload("res://scenes/arpg_narrative_controller/arpg_narrative_controller.gd")
const Encounter = preload("res://prefabs/boss_encounter/boss_encounter.gd")
const Executor = preload("res://addons/laoli_dialogue_system/scenes/cutscene_player/cutscene_player.gd")
const Definition = preload("res://addons/laoli_dialogue_system/scripts/core/cutscene/cutscene_definition.gd")
const RESOLUTION: Definition = preload("res://data/story/boss_resolution.tres")
const Snapshot = preload("res://scripts/core/story_snapshot.gd")
const Store = preload("res://addons/laoli_dialogue_system/scripts/core/save/checkpoint_store.gd")
const QuestCodec = preload("res://addons/laoli_dialogue_system/scripts/core/save/quest_snapshot.gd")
const CheckpointUI = preload("res://ui/checkpoint_controls/checkpoint_controls.gd")
const TRANSITION_TIME: float = 1.5
const DIALOGUE_PATH: String = "res://data/dialogues/dialogue.json"
const CLONE_QUEST: Quest = preload("res://data/story/clone_quest.tres")
const INTRO_LINES: Array[DialogueNode] = [preload("res://data/story/intro_player.tres"), preload("res://data/story/intro_clone.tres"), preload("res://data/story/intro_challenge.tres"), preload("res://data/story/clone_last_words.tres")]
@export var checkpoint_path: String = "user://story_checkpoint.json"
@export var registered_quests: Array[Quest] = []
@onready var player: PlayerActor = $RoomLobby/Player
@onready var inventory_ui: MarginContainer = $UILayer/HUD/inventory
@onready var hud: Control = $UILayer/HUD
@onready var quest_log: CanvasLayer = $QuestLogUI
@onready var camera: Camera3D = $Camera3D
@onready var lobby: DungeonRoom = $RoomLobby
@onready var dungeon: DungeonRoom = $RoomDungeon
@onready var boss_room: DungeonRoom = $RoomBoss
@onready var encounter: Encounter = $RoomBoss/BossEncounter
@onready var narrative: Narrative = $ArpgNarrativeController
@onready var checkpoint_ui: CheckpointUI = $CheckpointControls
var checkpoint_store: Store
var _checkpoint_loading: bool = false
var _transitioning: bool = false
var _room: DungeonRoom
var _intro_seen: bool = false
var _boss_defeated: bool = false
var _resolution_pending: bool = false
var _resolution_seen: bool = false
var _active_story: StringName = &""
var _hud_visible: bool = true
var _quest_log_visible: bool = true
var _player_visual_pose: Transform3D
var _transition_tween: Tween

func _ready() -> void:
	checkpoint_store = Store.new(checkpoint_path)
	checkpoint_ui.save_requested.connect(save_checkpoint)
	checkpoint_ui.load_requested.connect(load_checkpoint)
	if not DialogueManager.set_initiator(player):
		push_error("对话服务仍被旧场景占用。")
	_register_services()
	_room = lobby
	camera.global_position = lobby.camera_marker.global_position
	inventory_ui.initialize(player.get_inventory())
	_register_intro_dialogue()
	encounter.initialize(player)
	encounter.intro_requested.connect(_request_intro)
	encounter.health_changed.connect(_on_boss_health)
	encounter.attack_requested.connect(player.take_damage)
	encounter.defeated.connect(_on_boss_defeated)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health)
	narrative.finished.connect(_on_intro_finished)
	narrative.corruption_changed.connect(encounter.boss.actor.set_corruption)
	narrative.actor_cue.connect(_on_actor_cue)
	dungeon.room_exit_requested.connect(_on_passage.bind(boss_room, encounter.arrival))
	boss_room.room_exit_requested.connect(_on_passage.bind(dungeon, $RoomDungeon/ReturnArrival))
	if "--boss-demo" in OS.get_cmdline_user_args():
		call_deferred("transition_to_room", boss_room, encounter.arrival.global_position)

func _process(_delta: float) -> void:
	checkpoint_ui.set_available(_can_save_checkpoint(), not _checkpoint_loading and not _transitioning and is_instance_valid(narrative))
	if _checkpoint_loading or not is_instance_valid(narrative):
		return
	if _resolution_pending and not _transitioning and _room == boss_room and not narrative.is_playing() and is_instance_valid(player) and player.is_ready_for_cutscene():
		_resolution_pending = false
		_begin_story(RESOLUTION)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_story_checkpoint"):
		save_checkpoint()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("load_story_checkpoint"):
		load_checkpoint()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_inventory") and player.can_control() and not _transitioning:
		if inventory_ui.visible:
			inventory_ui.hide()
		else:
			inventory_ui.open()
	if event.is_action_pressed("retry_story") and player.health <= 0:
		get_tree().reload_current_scene()

func transition_to_room(target_room: DungeonRoom, target_position: Vector3) -> void:
	if _transitioning or narrative.is_playing() or player.health <= 0:
		return
	_transitioning = true
	encounter.stop_combat()
	player.set_control_lock(&"room_transition", true)
	player.set_physics_process(false)
	player.hide()
	_transition_tween = create_tween()
	_transition_tween.tween_property(camera, "global_position", target_room.camera_marker.global_position, TRANSITION_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _transition_tween.finished
	player.reparent(target_room)
	player.global_position = target_position
	player.velocity = Vector3.ZERO
	_room = target_room
	player.show()
	player.set_physics_process(true)
	player.set_control_lock(&"room_transition", false)
	_transitioning = false
	# 进入通知在玩家安置完成后发出，防止入口与镜头争抢。
	target_room.on_player_enter()
	if target_room == boss_room:
		encounter.check_entry()

func _request_intro() -> void:
	if _transitioning or _room != boss_room or narrative.is_playing() or not player.is_ready_for_cutscene():
		return
	if _intro_seen and _boss_defeated:
		_resolution_pending = not _resolution_seen
		return
	if _intro_seen:
		encounter.apply_end_pose()
		encounter.start_combat()
		return
	if _begin_story(narrative.definition):
		encounter.prepare_intro()

func _begin_story(sequence: Definition) -> bool:
	_hud_visible = hud.visible
	_quest_log_visible = quest_log.visible
	_player_visual_pose = player.visuals.transform
	var room_view: Transform3D = camera.global_transform
	room_view.origin = boss_room.camera_marker.global_position
	var targets: Array[Node] = [player, encounter.boss, encounter.boss.actor]
	if not narrative.start(camera, encounter.focus.global_position, room_view, sequence, targets):
		narrative.presentation.overlay.show_combat_status("无法开始演出：" + narrative.last_error)
		return false
	_active_story = sequence.cutscene_id
	player.set_control_lock(&"boss_intro", true)
	hud.hide()
	quest_log.hide()
	return true

func _on_intro_finished(outcome: Executor.Outcome) -> void:
	# 单次消费终结事件；宿主退出时无需访问正在释放的兄弟节点。
	var ended_story: StringName = _active_story
	_active_story = &""
	if ended_story == &"" or not is_inside_tree() or is_queued_for_deletion():
		return
	var player_available: bool = is_instance_valid(player) and player.is_inside_tree() and not player.is_queued_for_deletion()
	var encounter_available: bool = is_instance_valid(encounter.boss) and is_instance_valid(encounter.boss.actor)
	var success: bool = outcome in [Executor.Outcome.COMPLETED, Executor.Outcome.SKIPPED] and player_available and player.health > 0 and encounter_available
	if ended_story == &"boss_intro":
		if success:
			success = _commit_intro()
		if encounter_available:
			if success:
				encounter.apply_end_pose()
			else:
				encounter.cancel_intro()
	elif ended_story == &"boss_resolution":
		if success:
			_resolution_seen = true
			encounter.boss.actor.set_corruption(0.2)
			narrative.presentation.overlay.show_combat_status("封印已解除 · 带着回响继续前行")
		elif encounter_available:
			encounter.boss.actor.set_corruption(1.0)
	if player_available:
		if is_instance_valid(player.visuals):
			player.visuals.transform = _player_visual_pose
		player.set_control_lock(&"boss_intro", false)
	if is_instance_valid(hud):
		hud.visible = _hud_visible
	if is_instance_valid(quest_log):
		quest_log.visible = _quest_log_visible
	if success and ended_story == &"boss_intro":
		camera.global_position = boss_room.camera_marker.global_position
		encounter.start_combat()

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

func _on_actor_cue(cue: StringName) -> void:
	match cue:
		&"seal_release":
			encounter.boss.actor.set_corruption(0.2)
		&"mirror_player":
			player.face_point(encounter.boss.global_position + Vector3(2, 0, 0))
		&"mirror_clone":
			encounter.boss.face_point(player.global_position + Vector3(-2, 0, 0))
		&"break_sync":
			encounter.boss.face_point(player.global_position)

func _on_passage(body: CharacterBody3D, room: DungeonRoom, arrival: Marker3D) -> void:
	if body == player:
		transition_to_room(room, arrival.global_position)

func _on_boss_health(current: int, maximum: int) -> void:
	narrative.presentation.overlay.show_boss_health(current, maximum)
	narrative.presentation.overlay.show_combat_status("异化回响 %d / %d   ·   玩家 %d / %d" % [current, maximum, player.health, player.combat_profile.max_health])

func _on_player_health(_current: int, _maximum: int) -> void:
	_on_boss_health(encounter.boss.get_health(), encounter.boss.profile.max_health)

func _on_boss_defeated() -> void:
	if _boss_defeated:
		return
	_boss_defeated = true
	_resolution_pending = true
	GameState.emit_game_event("enemy_died", {"enemy_id": "异化回响"})
	narrative.presentation.overlay.show_combat_status("异化回响已击败 · 任务目标完成")

func _on_player_died() -> void:
	narrative.cancel("玩家死亡")
	encounter.stop_combat()
	narrative.presentation.overlay.show_combat_status("你倒下了 · 按 R 重新开始")

func _register_intro_dialogue() -> void:
	for node: DialogueNode in INTRO_LINES:
		DialogueManager.dialogue_graph[node.node_id] = node

func _register_services() -> void:
	for quest: Quest in registered_quests:
		if not GameState.quest_database.has(quest.id):
			GameState.register_quest(quest)
	if not GameState.quest_database.has(CLONE_QUEST.id):
		GameState.register_quest(CLONE_QUEST)
	var actions: Dictionary[String, GameAction] = {
		"give_item": ActionAddItem.new(), "remove_item": ActionRemoveItem.new(),
		"give_reward": ActionGiveReward.new(), "affinity_change": ActionChangeAffinity.new()
	}
	for action_id: String in actions:
		if not DialogueManager.has_registered_action(action_id):
			DialogueManager.register_action(action_id, actions[action_id])
	if not DialogueManager.has_registered_condition("has_item"):
		DialogueManager.register_condition("has_item", ConditionHasItem.new())
	DialogueManager.load_dialogue_file(DIALOGUE_PATH)

func _exit_tree() -> void:
	_active_story = &""
	if is_instance_valid(narrative):
		narrative.cancel("宿主退出")
	if is_instance_valid(player):
		DialogueManager.clear_initiator(player)
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()

## 只在稳定时刻保存；不会写入动画游标、瞬时生命或背包。
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

## 先完整校验、构建任务副本，再中断当前演出并安装；坏档不改变当前局。
func load_checkpoint() -> bool:
	if _checkpoint_loading or _transitioning:
		checkpoint_ui.show_message("切房或恢复中，请稍后读取检查点")
		return false
	if not is_instance_valid(player) or not is_instance_valid(camera) or not is_instance_valid(narrative) or not is_instance_valid(narrative.presentation) or not is_instance_valid(narrative.presentation.overlay) or not is_instance_valid(encounter.boss) or not is_instance_valid(encounter.boss.actor):
		checkpoint_ui.show_message("场景对象已失效，请重新进入关卡")
		return false
	var snapshot: Dictionary = checkpoint_store.load_snapshot()
	if snapshot.is_empty():
		checkpoint_ui.show_message("读取失败：" + checkpoint_store.last_error)
		return false
	var validator: Snapshot = Snapshot.new()
	if not validator.validate(snapshot, GameState.quest_database):
		checkpoint_ui.show_message("读取失败：" + validator.last_error)
		return false
	_checkpoint_loading = true
	narrative.cancel("读取叙事检查点")
	DialogueManager.clear_initiator(player)
	encounter.stop_combat()
	player.set_control_lock(&"checkpoint", true)
	player.reparent(boss_room)
	player.global_position = encounter.arrival.global_position
	player.restore_checkpoint()
	_room = boss_room
	camera.global_position = boss_room.camera_marker.global_position
	camera.make_current()
	var story: Dictionary = snapshot["story"]
	_intro_seen = bool(story["intro_seen"])
	_boss_defeated = bool(story["boss_defeated"])
	_resolution_seen = bool(story["resolution_seen"])
	_resolution_pending = _boss_defeated and not _resolution_seen
	QuestManager.install_checkpoint(validator.quests.prepared_quests, validator.quests.prepared_completed)
	DialogueManager.transcript.replace(snapshot["history"])
	DialogueManager.set_initiator(player)
	encounter.restore_checkpoint(_intro_seen, _boss_defeated, _resolution_seen)
	player.face_point(encounter.boss.global_position)
	player.show()
	player.set_physics_process(true)
	player.set_control_lock(&"checkpoint", false)
	_checkpoint_loading = false
	if _intro_seen and not _boss_defeated:
		encounter.start_combat()
	if _boss_defeated:
		narrative.presentation.overlay.boss_health.hide()
		narrative.presentation.overlay.show_combat_status("封印已解除" if _resolution_seen else "异化回响已击败")
	elif not _intro_seen:
		narrative.presentation.overlay.boss_health.hide()
		narrative.presentation.overlay.show_combat_status("")
	checkpoint_ui.show_message("已恢复叙事检查点 · " + _checkpoint_label(String(snapshot["checkpoint"])))
	return true

func _checkpoint_label(phase: String) -> String:
	match phase:
		"before_intro": return "初遇之前"
		"before_battle": return "开战之前（双方生命重置）"
		"after_boss": return "击败克隆体之后"
	return "未知节点"

func _can_save_checkpoint() -> bool:
	return not _checkpoint_loading and not _transitioning and is_instance_valid(narrative) and is_instance_valid(player) and not narrative.is_playing() and not DialogueManager.is_active and player.health > 0
