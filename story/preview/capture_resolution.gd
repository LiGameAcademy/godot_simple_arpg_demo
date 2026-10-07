extends Node
const MAIN: PackedScene = preload("res://scenes/main.tscn")
const Game = preload("res://scenes/main.gd")
var _session: int = -1

func _ready() -> void:
	DialogueManager.dialogue_session_started.connect(_on_session)
	call_deferred("_run")

func _run() -> void:
	var game: Game = MAIN.instantiate() as Game
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await game.transition_to_room(game.boss_room, game.encounter.arrival.global_position)
	for frame_index: int in range(60):
		await get_tree().process_frame
		if game.narrative.is_playing():
			break
	game.narrative.skip()
	game.encounter.boss.take_damage(999)
	var captured: bool = false
	for frame_index: int in range(900):
		await get_tree().process_frame
		if game._active_story == &"boss_resolution" and game.narrative.presentation.overlay.title_label.visible and not captured:
			for settle_frame: int in range(40):
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			assert(image.save_png("res://story/preview/captures/boss_resolution.png") == OK)
			captured = true
		if DialogueManager.current_node != null and game.get_node("DialogueUI").typing_timer.is_stopped():
			DialogueManager.advance_dialogue_session(_session)
		if game._resolution_seen:
			break
	assert(captured and game._resolution_seen)
	game.queue_free()
	await get_tree().process_frame
	print("PASS: resolution rendered and completed")
	get_tree().quit()

func _on_session(session_id: int) -> void:
	_session = session_id
