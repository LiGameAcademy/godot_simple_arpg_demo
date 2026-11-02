extends Node
## Exercises the recorded course flow using a separate, disposable checkpoint.

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const MainScript = preload("res://scenes/main.gd")
const Executor = preload("res://addons/laoli_dialogue_system/scenes/cutscene_player/cutscene_player.gd")
const ActorScene: PackedScene = preload("res://prefabs/boss_actor/boss_actor.tscn")
const ActorScript = preload("res://prefabs/boss_actor/boss_actor.gd")

var _main: MainScript
var _failures: int = 0
var _finished_id: StringName = &""
var _outcome: Executor.Outcome = Executor.Outcome.FAILED
var _checkpoint_path: String


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_checkpoint_path = "user://course_closeout_%d.json" % Time.get_ticks_usec()
	_main = MainScene.instantiate() as MainScript
	_main.checkpoint_path = _checkpoint_path
	add_child(_main)
	_main.narrative.executor.finished.connect(_on_finished)
	await get_tree().physics_frame
	await _verify_animations()
	await _verify_material_isolation()
	_expect(_main.save_checkpoint(), "save before intro")
	var before_intro: Dictionary = _main.checkpoint_store.load_snapshot()
	_expect(before_intro.get("checkpoint") == "before_intro", "initial checkpoint phase")
	await _main.transition_to_room(_main.room_boss, _main.encounter.arrival.global_position)
	for frame: int in range(5):
		await get_tree().physics_frame
	_main.encounter.entrance.body_entered.emit(_main.player)
	_expect(_main.narrative.is_playing(), "entry starts intro")
	_main.narrative.cancel("closeout cancellation test")
	_expect(_outcome == Executor.Outcome.CANCELED, "intro cancellation result")
	_expect(not _main._intro_seen and _main.player.can_control(), "cancel restores control without committing")
	_expect(QuestManager.get_quest_status("defeat_clone") == QuestManager.QuestStatus.CAN_ACCEPT,
		"cancel does not accept clone quest")
	_main.encounter.entrance.body_entered.emit(_main.player)
	_expect(_main.narrative.is_playing(), "intro can be retried after cancel")
	_main.narrative.skip()
	_expect(_outcome == Executor.Outcome.SKIPPED and _main._intro_seen, "skip commits intro")
	_expect(_main.player.can_control() and _main.hud.visible, "skip restores player and HUD")
	_expect(_main.save_checkpoint(), "save before resolution")
	var before_resolution: Dictionary = _main.checkpoint_store.load_snapshot()
	_expect(before_resolution.get("checkpoint") == "before_resolution", "middle checkpoint phase")
	_main.encounter.debug_defeat()
	await _finish_story(&"boss_resolution", false)
	_expect(_main._resolution_seen, "normal resolution commits its result")
	_expect(_main.player.can_control() and _main.hud.visible, "normal resolution restores control")
	_expect(_main.save_checkpoint(), "save after boss")
	var after_boss: Dictionary = _main.checkpoint_store.load_snapshot()
	_expect(after_boss.get("checkpoint") == "after_boss", "final checkpoint phase")
	_expect(_main.load_checkpoint() and _main._resolution_seen, "restore final checkpoint")
	_expect(_main.checkpoint_store.save_snapshot(before_resolution), "install middle checkpoint fixture")
	_expect(_main.load_checkpoint() and not _main._boss_defeated, "restore middle checkpoint")
	_main.encounter.debug_defeat()
	await _finish_story(&"boss_resolution", true)
	_expect(_main._resolution_seen, "skipped resolution commits its result")
	_expect(_main.checkpoint_store.save_snapshot(before_intro), "install initial checkpoint fixture")
	_expect(_main.load_checkpoint() and not _main._intro_seen, "restore initial checkpoint")
	_main.encounter.entrance.body_entered.emit(_main.player)
	await _finish_story(&"boss_intro", false)
	_expect(_main._intro_seen, "normal intro commits its result")
	var state_before_bad_load: bool = _main._intro_seen
	_expect(_main.checkpoint_store.save_snapshot({"schema_version": -1}), "install invalid fixture")
	_expect(not _main.load_checkpoint() and _main._intro_seen == state_before_bad_load,
		"invalid checkpoint leaves current state intact")
	_main.queue_free()
	await get_tree().process_frame
	if FileAccess.file_exists(_checkpoint_path):
		_expect(DirAccess.remove_absolute(_checkpoint_path) == OK, "remove disposable checkpoint")
	if _failures == 0:
		print("PASS: course intro/resolution, skip/cancel, three checkpoints, bad save, animation and material isolation")
	get_tree().quit(0 if _failures == 0 else 1)


func _finish_story(expected_id: StringName, skip: bool) -> void:
	_finished_id = &""
	for frame: int in range(2400):
		await get_tree().physics_frame
		if _main.narrative.is_playing():
			if skip:
				_main.narrative.skip()
			elif DialogueManager.is_dialogue_active():
				DialogueManager.process_node("END")
		if not _finished_id.is_empty():
			break
	_expect(_finished_id == expected_id, "selected sequence finishes: " + String(expected_id))
	_expect(_outcome == (Executor.Outcome.SKIPPED if skip else Executor.Outcome.COMPLETED),
		"expected sequence outcome")
	if _main.narrative.is_playing():
		_main.narrative.cancel("test timeout")


func _verify_animations() -> void:
	var animations: AnimationPlayer = _main.player.get_node("Visuals/Barbarian/AnimationPlayer") as AnimationPlayer
	for name: String in ["Idle_B", "Walking_B", "Running_B"]:
		_expect(animations.get_animation("hero/" + name).loop_mode == Animation.LOOP_LINEAR,
			"loop preserved after fresh import: " + name)
	var attack: Animation = animations.get_animation("hero/Melee_1H_Attack_Chop")
	_expect(attack.loop_mode == Animation.LOOP_NONE, "attack remains one shot")
	_main.player.set_physics_process(false)
	var skeleton: Skeleton3D = _main.player.get_node("Visuals/Barbarian/Rig_Medium/Skeleton3D") as Skeleton3D
	for speed: float in [0.0, 2.0, 5.0]:
		_main.player.animation_tree.set("parameters/StateMachine/movement/blend_position", speed)
		for frame: int in range(300):
			await get_tree().physics_frame
		var before: Array[Quaternion] = _sample_pose(skeleton)
		var changed: bool = false
		for frame: int in range(30):
			await get_tree().physics_frame
			var after: Array[Quaternion] = _sample_pose(skeleton)
			for bone: int in range(before.size()):
				changed = changed or before[bone].angle_to(after[bone]) > 0.01
		_expect(changed, "movement keeps animating after two cycles at speed %s" % speed)
	_main.player.animation_state_machine.travel(&"attack")
	for frame: int in range(90):
		await get_tree().physics_frame
	_expect(_main.player.animation_state_machine.get_current_node() == &"movement", "attack returns to movement")
	_main.player.set_physics_process(true)


func _sample_pose(skeleton: Skeleton3D) -> Array[Quaternion]:
	var result: Array[Quaternion] = []
	for bone: int in range(skeleton.get_bone_count()):
		result.append(skeleton.get_bone_pose_rotation(bone))
	return result


func _verify_material_isolation() -> void:
	var other: ActorScript = ActorScene.instantiate() as ActorScript
	add_child(other)
	var actor: ActorScript = _main.encounter.actor
	var original: float = other.corruptioon_amount
	actor.set_corruption(0.7)
	_expect(other.corruptioon_amount == original, "actor state is independent")
	_expect(not actor._materials.is_empty() and not other._materials.is_empty(), "both actors have materials")
	if not actor._materials.is_empty() and not other._materials.is_empty():
		_expect(actor._materials[0] != other._materials[0], "actor materials are independent")
		_expect(is_equal_approx(float(other._materials[0].get_shader_parameter("corruption_amount")), original),
			"changing actor A leaves material B intact")
	actor.set_corruption(0.15)
	other.queue_free()
	await get_tree().process_frame


func _on_finished(_run_id: int, sequence_id: StringName, outcome: Executor.Outcome) -> void:
	_finished_id = sequence_id
	_outcome = outcome


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)
