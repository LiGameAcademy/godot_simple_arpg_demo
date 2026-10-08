extends Node
const MAIN: PackedScene = preload("res://scenes/main.tscn")
const Game = preload("res://scenes/main.gd")
const Config = preload("res://ui/cinematic_presentation/presentation_config.gd")
var _session: int = -1
var _interactions: int = 0
func _ready() -> void:
	DialogueManager.dialogue_session_started.connect(_on_session)
	call_deferred("_run")
func _run() -> void:
	for speed: float in [0.5, 1.0, 2.0]:
		QuestManager.active_quests.clear()
		QuestManager.completed_quest_ids.clear()
		GameState.quest_database.clear()
		var game: Game = MAIN.instantiate() as Game
		get_tree().root.add_child(game)
		game.get_node("DialogueUI").typing_sound_enabled = false
		var original: Config = game.narrative.presentation.config
		var durations: Dictionary[StringName, float] = original.durations.duplicate()
		var local: Config = original.duplicate(true) as Config
		for clip: StringName in local.durations:
			local.durations[clip] /= speed
		game.narrative.presentation.config = local
		await game.transition_to_room(game.boss_room, game.encounter.arrival.global_position)
		for frame_index: int in range(60):
			await get_tree().process_frame
			if game.narrative.is_playing():
				break
		assert(game.narrative.is_playing())
		var interaction: InteractionComponent = game.get_node("RoomLobby/Teleporter/InteractionComponent") as InteractionComponent
		interaction.interacted.connect(_on_interacted)
		game.player.current_interactable = interaction
		var start: Vector3 = game.player.global_position
		var inventory_visible: bool = game.inventory_ui.visible
		for action: StringName in [&"move_up", &"attack", &"interact", &"toggle_inventory"]:
			_action(action, true)
		for frame_index: int in range(12):
			await get_tree().physics_frame
		assert(Vector2(game.player.global_position.x - start.x, game.player.global_position.z - start.z).length() < 0.01)
		assert(_interactions == 0 and not game.player.sword_hitbox.monitoring)
		assert(game.inventory_ui.visible == inventory_visible and not game._transitioning)
		assert(not game.encounter.boss.is_combat_active())
		for action: StringName in [&"move_up", &"attack", &"interact", &"toggle_inventory"]:
			_action(action, false)
		for frame_index: int in range(2200):
			await get_tree().process_frame
			if DialogueManager.current_node != null:
				DialogueManager.advance_dialogue_session(_session)
			if game._intro_seen:
				break
		assert(game._intro_seen and game.encounter.boss.is_combat_active() and game.player.can_control())
		assert(QuestManager.get_quest_status("defeat_clone") == QuestManager.QuestStatus.IN_PROGRESS)
		assert(is_equal_approx(game.encounter.boss.actor.corruption_amount, 1.0))
		assert(original.durations == durations, "Shared presentation config changed")
		print("PASS: input isolation and identical intro rules at ", speed, "x presentation pacing")
		game.queue_free()
		await get_tree().process_frame
	get_tree().quit()
func _action(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
func _on_session(session_id: int) -> void:
	_session = session_id
func _on_interacted(_initiator: Node) -> void:
	_interactions += 1
