extends Node
const MAIN: PackedScene = preload("res://scenes/main.tscn")
const Game = preload("res://scenes/main.gd")
const Executor = preload("res://addons/laoli_dialogue_system/scenes/cutscene_player/cutscene_player.gd")
var _session: int = -1
var _outcomes: Array[int] = []
var _accepted: int = 0

func _ready() -> void:
	DialogueManager.dialogue_session_started.connect(_on_session)
	QuestManager.quest_accepted.connect(_on_accepted)
	call_deferred("_run")

func _run() -> void:
	for index: int in range(9):
		var game: Game = await _new_game()
		await _enter(game)
		await _reach_step(game, index)
		game.narrative.skip()
		game.narrative.skip()
		game._on_intro_finished(Executor.Outcome.SKIPPED)
		assert(_outcomes == [Executor.Outcome.SKIPPED])
		assert(_accepted == 1 and game._intro_seen)
		_assert_restored(game)
		assert(game.encounter.boss.is_combat_active())
		await _dispose(game)
	print("PASS: skipping each of 9 steps commits exactly once and restores camera/UI/control")
	for failure: String in ["missing_dialogue", "actor_removed", "camera_removed", "timeout", "dialogue_canceled", "controller_removed", "presentation_removed", "player_died"]:
		var game: Game = await _new_game()
		await _enter(game)
		await _reach_step(game, 0)
		if failure == "missing_dialogue":
			DialogueManager.dialogue_graph.erase("intro_player")
			await _reach_step(game, 1)
			game.narrative.executor.complete_step(game.narrative._run_id, 1)
		elif failure == "actor_removed":
			game.encounter.boss.actor.queue_free()
		elif failure == "camera_removed":
			game.camera.queue_free()
		elif failure == "timeout":
			game.narrative.presentation.stop_clip()
			game.narrative.executor._time_left = 0.01
		elif failure == "player_died":
			game.player.take_damage(999)
		elif failure == "presentation_removed":
			game.narrative.presentation.queue_free()
		elif failure == "dialogue_canceled":
			await _reach_step(game, 2)
			await get_tree().process_frame
			DialogueManager.cancel_dialogue_session(game.narrative._session_id)
		else:
			game.narrative.queue_free()
		for frame_index: int in range(20):
			await get_tree().process_frame
			if not _outcomes.is_empty():
				break
		assert(_outcomes.size() == 1, failure + " did not terminate once")
		assert(_accepted == 0 and not game._intro_seen, failure + " committed rules")
		assert(not DialogueManager.is_active)
		assert(game.player.can_control() if failure != "player_died" else game.player.health == 0)
		assert(not game.player._control_locks.has(&"boss_intro"))
		assert(game.hud.visible and game.quest_log.visible)
		if failure not in ["controller_removed", "presentation_removed"]:
			assert(not game.narrative.presentation.overlay.bars.visible)
		if failure != "camera_removed":
			assert(game.camera.is_current())
		assert(not game.encounter.boss.is_combat_active())
		await _dispose(game)
		print("PASS: cleanup after ", failure)
	for ending: String in ["complete", "skip", "cancel"]:
		var game: Game = await _new_game()
		await _enter(game)
		game.narrative.skip()
		game.encounter.boss.take_damage(999)
		for frame_index: int in range(60):
			await get_tree().process_frame
			if game._active_story == &"boss_resolution":
				break
		assert(game._active_story == &"boss_resolution", "Second sequence did not start")
		assert(_accepted == 1)
		if ending == "skip":
			game.narrative.skip()
		elif ending == "cancel":
			game.narrative.cancel("cancel resolution")
		else:
			for frame_index: int in range(400):
				await get_tree().process_frame
				if DialogueManager.current_node != null:
					DialogueManager.advance_dialogue_session(_session)
				if not game.narrative.is_playing():
					break
		assert(not game.narrative.is_playing())
		assert(game._resolution_seen == (ending != "cancel"))
		assert(is_equal_approx(game.encounter.boss.actor.corruption_amount, 1.0 if ending == "cancel" else 0.2))
		assert(_accepted == 1 and _outcomes.size() == 2)
		assert(QuestManager.get_quest_status("defeat_clone") == QuestManager.QuestStatus.READY_TO_TURN_IN)
		_assert_restored(game)
		assert(not game.encounter.boss.is_combat_active())
		await _dispose(game)
	print("PASS: second sequence complete/skip/cancel reuses executor without replaying quest or combat")
	var game: Game = await _new_game()
	await _enter(game)
	await _reach_step(game, 2)
	await get_tree().process_frame
	await _dispose(game)
	assert(not DialogueManager.is_active, "Scene exit retained owned dialogue")
	print("PASS: host exit cancels reserved/active dialogue")
	get_tree().quit()

func _new_game() -> Game:
	QuestManager.active_quests.clear()
	QuestManager.completed_quest_ids.clear()
	GameState.quest_database.clear()
	_accepted = 0
	_outcomes.clear()
	var game: Game = MAIN.instantiate() as Game
	get_tree().root.add_child(game)
	game.get_node("DialogueUI").typing_sound_enabled = false
	game.narrative.finished.connect(_on_finished)
	await get_tree().process_frame
	return game

func _enter(game: Game) -> void:
	await game.transition_to_room(game.boss_room, game.encounter.arrival.global_position)
	for frame_index: int in range(60):
		await get_tree().process_frame
		if game.narrative.is_playing():
			return
	assert(false, "Intro did not start")

func _reach_step(game: Game, target: int) -> void:
	for frame_index: int in range(180):
		await get_tree().process_frame
		var index: int = game.narrative.executor.current_step_index()
		if index == target:
			return
		if index >= 0 and index < target:
			if DialogueManager.current_node != null:
				DialogueManager.advance_dialogue_session(_session)
			elif game.narrative._session_id < 0:
				game.narrative.executor.complete_step(game.narrative._run_id, index)
	assert(false, "Did not reach step " + str(target))

func _assert_restored(game: Game) -> void:
	assert(game.player.can_control() and not DialogueManager.is_active)
	assert(game.camera.is_current())
	assert(game.hud.visible and game.quest_log.visible)
	assert(not game.narrative.presentation.overlay.bars.visible)
	assert(game.get_node("DialogueUI").typing_timer.is_stopped())

func _dispose(game: Game) -> void:
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _on_session(session: int) -> void:
	_session = session

func _on_finished(outcome: int) -> void:
	_outcomes.append(outcome)

func _on_accepted(quest: Quest) -> void:
	if quest.id == "defeat_clone":
		_accepted += 1
