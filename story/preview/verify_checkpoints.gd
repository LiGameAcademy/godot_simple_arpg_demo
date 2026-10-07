extends Node
const MAIN: PackedScene = preload("res://scenes/main.tscn")
const Game = preload("res://scenes/main.gd")
var _accepted: int = 0
var _game: Game
var _path: String

func _ready() -> void:
	QuestManager.quest_accepted.connect(_on_accepted)
	call_deferred("_run")

func _run() -> void:
	_path = "user://verify_checkpoint_%d.json" % Time.get_ticks_usec()
	QuestManager.active_quests.clear()
	QuestManager.completed_quest_ids.clear()
	DialogueManager.transcript.entries.clear()
	GameState.quest_database.clear()
	_game = MAIN.instantiate() as Game
	get_tree().root.add_child(_game)
	_game.get_node("DialogueUI").typing_sound_enabled = false
	_game.checkpoint_store.file_path = _path
	await get_tree().process_frame
	assert(OS.get_keycode_string(InputMap.action_get_events("save_story_checkpoint")[0].physical_keycode) == "F5")
	assert(OS.get_keycode_string(InputMap.action_get_events("load_story_checkpoint")[0].physical_keycode) == "F9")
	assert(not _game.load_checkpoint(), "Missing file was treated as success")
	assert(_game.save_checkpoint())
	var before_intro: Dictionary = _game.checkpoint_store.load_snapshot()
	assert(before_intro["checkpoint"] == "before_intro")
	await _game.transition_to_room(_game.boss_room, _game.encounter.arrival.global_position)
	await _wait_intro()
	var retained: String = FileAccess.get_file_as_string(_path)
	assert(not _game.save_checkpoint(), "Saved during intro")
	assert(FileAccess.get_file_as_string(_path) == retained)
	assert(_game.load_checkpoint(), "Could not interrupt intro to restore")
	assert(not _game._intro_seen and not _game.encounter.boss.is_combat_active())
	assert(QuestManager.get_quest_status("defeat_clone") == QuestManager.QuestStatus.CAN_ACCEPT)
	assert(not DialogueManager.is_active)
	await _wait_intro()
	_game.narrative.skip()
	assert(_accepted == 1)
	DialogueManager.transcript.record("checkpoint_test_line", "回响", "我见过你。")
	assert(_game.save_checkpoint())
	var before_battle: Dictionary = _game.checkpoint_store.load_snapshot()
	assert(before_battle["checkpoint"] == "before_battle")
	_game.encounter.boss.take_damage(2)
	_game.player.take_damage(3)
	DialogueManager.transcript.record("later_test_line", "回响", "不该留在旧节点的台词")
	assert(_game.load_checkpoint())
	assert(_game.encounter.boss.get_health() == _game.encounter.boss.profile.max_health)
	assert(_game.player.health == _game.player.combat_profile.max_health)
	assert(DialogueManager.transcript.entries == before_battle["history"])
	assert(_game.player.can_control() and _game.camera.is_current())
	assert(_game.encounter.boss.is_combat_active() and _accepted == 1)
	assert(_game.quest_log.quest_entries.size() == QuestManager.active_quests.size())
	assert(_game.encounter.boss.actor.animation_tree.active)
	var original: Quest = GameState.quest_database["defeat_clone"]
	assert((original.objectives[0] as ObjectiveKill).current_amount == 0)
	var clone: Quest = QuestManager.active_quests.back()
	assert(clone != original and clone.objectives[0] != original.objectives[0])
	print("PASS: before-intro interruption, before-battle reset, quest/UI/resource isolation and key bindings")
	_game.encounter.boss.take_damage(999)
	for frame_index: int in range(60):
		await get_tree().process_frame
		if _game._active_story == &"boss_resolution":
			break
	_game.narrative.skip()
	assert(_game._resolution_seen)
	assert(_game.save_checkpoint())
	var after_boss: Dictionary = _game.checkpoint_store.load_snapshot()
	assert(after_boss["checkpoint"] == "after_boss")
	_game.player.take_damage(999)
	assert(_game.load_checkpoint())
	assert(_game.player.can_control() and _game._resolution_seen)
	assert(_game.encounter.boss.get_health() == 0 and not _game.encounter.boss.is_combat_active())
	assert(not _game.encounter.boss.actor.animation_tree.active)
	assert(QuestManager.get_quest_status("defeat_clone") == QuestManager.QuestStatus.READY_TO_TURN_IN)
	assert(_accepted == 1)
	for frame_index: int in range(10):
		await get_tree().process_frame
	assert(not _game.narrative.is_playing())
	assert(_game.player.global_position.y > -1.0)
	assert(_game.checkpoint_store.save_snapshot(before_battle))
	assert(_game.load_checkpoint())
	assert(_game.encounter.boss.get_health() > 0 and _game.encounter.boss.actor.animation_tree.active)
	print("PASS: after-boss restore, death recovery, no replay, rewind from corpse to living combat")
	for defect: String in ["schema", "id", "amount", "story"]:
		var broken: Dictionary = before_battle.duplicate(true)
		match defect:
			"schema": broken["schema_version"] = 999
			"id": broken["quests"]["active"][0]["id"] = "unknown"
			"amount": broken["quests"]["active"][0]["goals"][0]["amount"] = -1
			"story": broken["story"]["boss_defeated"] = true
		assert(_game.checkpoint_store.save_snapshot(broken))
		var running_quest: Quest = QuestManager.active_quests[0]
		var health: int = _game.player.health
		assert(not _game.load_checkpoint())
		assert(QuestManager.active_quests[0] == running_quest and _game.player.health == health)
		assert(_game.encounter.boss.is_combat_active())
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	assert(not _game.load_checkpoint())
	assert(_game.checkpoint_store.save_snapshot(before_battle))
	retained = FileAccess.get_file_as_string(_path)
	var temp_dir: String = ProjectSettings.globalize_path(_path + ".tmp")
	assert(DirAccess.make_dir_absolute(temp_dir) == OK)
	assert(not _game.save_checkpoint(), "Failed temp write replaced valid snapshot")
	assert(FileAccess.get_file_as_string(_path) == retained)
	assert(DirAccess.remove_absolute(temp_dir) == OK)
	print("PASS: malformed JSON/schema/quest/progress/story rejected without mutation; failed write preserves old file")
	assert(_game.checkpoint_store.save_snapshot(after_boss))
	_game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_game = MAIN.instantiate() as Game
	get_tree().root.add_child(_game)
	_game.get_node("DialogueUI").typing_sound_enabled = false
	_game.checkpoint_store.file_path = _path
	await get_tree().process_frame
	assert(_game.load_checkpoint())
	assert(_game._intro_seen and _game._boss_defeated and _game._resolution_seen)
	assert(_game.encounter.boss.get_health() == 0 and _accepted == 1)
	print("PASS: checkpoint survives scene destruction and fresh main instance")
	_game.queue_free()
	await get_tree().process_frame
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(_path)) == OK)
	get_tree().quit()

func _wait_intro() -> void:
	for frame_index: int in range(60):
		await get_tree().process_frame
		if _game.narrative.is_playing():
			return
	assert(false, "Intro did not start")

func _on_accepted(quest: Quest) -> void:
	if quest.id == "defeat_clone":
		_accepted += 1
