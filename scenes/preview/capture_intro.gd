extends Node
const MAIN: PackedScene = preload("res://scenes/main.tscn")
var _game: Node3D
var _player_line_saved: bool = false
var _title_saved: bool = false

func _ready() -> void:
	call_deferred("_capture_run")

func _capture_run() -> void:
	_game = MAIN.instantiate() as Node3D
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	await get_tree().process_frame
	await _game.transition_to_room(_game.boss_room, _game.encounter.arrival.global_position)
	for frame_index: int in range(1800):
		await get_tree().process_frame
		if DialogueManager.is_active and DialogueManager.current_node != null:
			var ui: CanvasLayer = _game.get_node("DialogueUI") as CanvasLayer
			if not ui.typing_timer.is_stopped():
				continue
			if not _player_line_saved:
				await _save("intro_dialogue")
				_player_line_saved = true
			_accept()
		if _game.narrative.presentation.overlay.title_label.visible and not _title_saved:
			await _save("intro_title")
			_title_saved = true
		if _game.encounter.boss.is_combat_active():
			print("Player position at combat: ", _game.player.global_position)
			await _save("intro_combat")
			print("PASS: rendered intro captured through actual dialogue input")
			get_tree().quit()
			return
	push_error("Intro capture did not reach combat")
	get_tree().quit(1)

func _accept() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	Input.parse_input_event(event)
	var release: InputEventAction = InputEventAction.new()
	release.action = &"ui_accept"
	Input.parse_input_event(release)

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var error: Error = get_viewport().get_texture().get_image().save_png("res://scenes/preview/captures/" + name + ".png")
	if error != OK:
		push_error("Screenshot failed: %s" % error)
