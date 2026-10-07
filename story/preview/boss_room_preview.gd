extends Node3D
## 独立验收场景，不改变主游戏入口；仅在显式 --capture 参数下输出截图。
@onready var overview_camera: Camera3D = $OverviewCamera
@onready var close_camera: Camera3D = $CloseCamera

func _ready() -> void:
	overview_camera.look_at(Vector3(14.0, 0.7, 9.5))
	close_camera.look_at(Vector3(14.0, 1.5, 8.0))
	if "--capture" in OS.get_cmdline_user_args():
		call_deferred("_capture_views")

func _capture_views() -> void:
	for frame_index: int in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var output_dir: String = "res://story/preview/captures"
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(output_dir)
	if directory_error != OK:
		push_error("Cannot create capture directory: %s" % directory_error)
		get_tree().quit(1)
		return
	var save_error: Error = image.save_png(output_dir + "/boss_room_overview.png")
	if save_error != OK:
		push_error("Cannot save overview: %s" % save_error)
		get_tree().quit(1)
		return
	close_camera.make_current()
	for frame_index: int in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	save_error = get_viewport().get_texture().get_image().save_png(output_dir + "/clone_closeup.png")
	get_tree().quit(0 if save_error == OK else 1)
