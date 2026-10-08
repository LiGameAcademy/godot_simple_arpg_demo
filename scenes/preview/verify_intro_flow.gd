extends Node
const MAIN: PackedScene = preload("res://scenes/main.tscn")
const Executor = preload("res://addons/laoli_dialogue_system/scenes/cutscene_player/cutscene_player.gd")
var _session_id: int = -1
var _outcome: int = -1

func _ready() -> void:
	DialogueManager.dialogue_session_started.connect(_on_session)
	call_deferred("_run")

func _run() -> void:
	for scenario: String in ["complete", "skip_dialogue", "cancel", "skip_early", "hold_skip", "hidden_hud"]:
		QuestManager.active_quests.clear()
		QuestManager.completed_quest_ids.clear()
		GameState.quest_database.clear()
		_outcome = -1
		var game: Node3D = MAIN.instantiate() as Node3D
		get_tree().root.add_child(game)
		get_tree().current_scene = game
		# 加速规则验证不启动真实音频；声音在渲染预览中验证。
		game.get_node("DialogueUI").typing_sound_enabled = false
		game.narrative.finished.connect(_on_finished)
		await get_tree().process_frame
		if scenario == "complete":
			DialogueManager.start_dialogue("village_chief_start")
			await get_tree().process_frame
			await get_tree().process_frame
			var ordinary_ui: CanvasLayer = game.get_node("DialogueUI") as CanvasLayer
			assert(ordinary_ui.choices_container.get_child_count() >= 1)
			var accept_button: Button = ordinary_ui.choices_container.get_child(0) as Button
			accept_button.pressed.emit()
			assert(QuestManager.get_quest_status("chief_forest_quest") == QuestManager.QuestStatus.IN_PROGRESS)
			DialogueManager.advance_dialogue_session(_session_id)
			assert(not DialogueManager.is_active and game.player.can_control())
			print("PASS: ordinary NPC choices and quest acceptance preserved")
		if scenario == "hidden_hud":
			game.hud.hide()
			game.quest_log.hide()
		await game.transition_to_room(game.boss_room, game.encounter.arrival.global_position)
		for frame_index: int in range(60):
			await get_tree().process_frame
			if game.narrative.is_playing():
				break
		assert(game.narrative.is_playing(), "Entrance did not start intro")
		assert(not game.player.can_control(), "Player control leaked into intro")
		assert(not game.encounter.boss.is_combat_active(), "Boss activated too early")
		if scenario in ["skip_early", "hidden_hud"]:
			game.narrative.skip()
		elif scenario == "cancel":
			game.narrative.cancel("test interruption")
		else:
			var hold_sent: bool = false
			for frame_index: int in range(1200):
				await get_tree().process_frame
				if DialogueManager.is_active and DialogueManager.current_node != null:
					if scenario == "skip_dialogue":
						game.narrative.skip()
					elif scenario == "hold_skip":
						if not hold_sent:
							var hold: InputEventAction = InputEventAction.new()
							hold.action = &"skip_cutscene"
							hold.pressed = true
							Input.parse_input_event(hold)
							hold_sent = true
					else:
						DialogueManager.advance_dialogue_session(_session_id)
				if _outcome >= 0:
					break
			if hold_sent:
				var release: InputEventAction = InputEventAction.new()
				release.action = &"skip_cutscene"
				Input.parse_input_event(release)
		assert(_outcome >= 0, "Intro failed to terminate")
		assert(game.player.can_control(), "Player lock was not released")
		assert(game.player.global_position.y > -1.0, "Player arrival is not on a safe floor")
		assert(not DialogueManager.is_active, "Dialogue remained active")
		assert(game.camera.is_current(), "Game camera was not restored")
		assert(game.narrative.presentation.overlay.bars.visible == false)
		assert(game.get_node("DialogueUI").typing_timer.is_stopped())
		if scenario == "hidden_hud":
			assert(not game.hud.visible and not game.quest_log.visible, "Hidden HUD was unconditionally shown")
		if scenario == "cancel":
			assert(_outcome == Executor.Outcome.CANCELED)
			assert(not game.encounter.boss.is_combat_active())
			assert(QuestManager.get_quest_status("defeat_clone") == QuestManager.QuestStatus.CAN_ACCEPT)
		else:
			assert(_outcome == (Executor.Outcome.COMPLETED if scenario == "complete" else Executor.Outcome.SKIPPED))
			assert(game.encounter.boss.is_combat_active())
			assert(QuestManager.get_quest_status("defeat_clone") == QuestManager.QuestStatus.IN_PROGRESS)
			if scenario == "complete":
				var original_health: int = game.encounter.boss.get_health()
				game.player.global_position = game.encounter.boss.global_position + Vector3(0, 0, 1.5)
				game.player.face_point(game.encounter.boss.global_position)
				await get_tree().physics_frame
				var attack: InputEventAction = InputEventAction.new()
				attack.action = &"attack"
				attack.pressed = true
				Input.parse_input_event(attack)
				for physics_index: int in range(180):
					await get_tree().physics_frame
				assert(game.encounter.boss.get_health() < original_health, "Player sword cannot damage clone")
				assert(game.player.health < game.player.combat_profile.max_health, "Clone cannot damage player")
			game.encounter.boss.take_damage(999)
			game.encounter.boss.take_damage(999)
			assert(QuestManager.get_quest_status("defeat_clone") == QuestManager.QuestStatus.READY_TO_TURN_IN)
		print("PASS: ", scenario, " — entry, locks, dialogue, camera, task and combat cleanup")
		game.queue_free()
		await get_tree().process_frame
	print("PASS: all intro integration scenarios")
	get_tree().quit()

func _on_session(session_id: int) -> void:
	_session_id = session_id

func _on_finished(outcome: int) -> void:
	_outcome = outcome
