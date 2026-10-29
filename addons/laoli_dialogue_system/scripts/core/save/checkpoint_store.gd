extends RefCounted

var last_error: String = ""
var file_path: String

func _init(path: String = "user://story_checkpoint.json") -> void:
	file_path = path

func save_snapshot(snapshot: Dictionary) -> bool:
	last_error = ""
	var encoded: String = JSON.stringify(snapshot)
	var temporary: String = file_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入检查点临时文件"
		return false
	file.store_string(encoded)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		last_error = "检查点写入失败"
		return false
	if FileAccess.get_file_as_string(temporary) != encoded:
		last_error = "检查点写入校验失败"
		return false
	var parser: JSON = JSON.new()
	if parser.parse(encoded) != OK or not parser.data is Dictionary:
		last_error = "检查点不是有效的 JSON 对象"
		return false
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(file_path))
	if error != OK:
		last_error = "检查点替换失败，原文件保留"
		return false
	return true

func load_snapshot() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(file_path):
		last_error = "尚无叙事检查点"
		return {}
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		last_error = "检查点无法读取"
		return {}
	var encoded: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(encoded) != OK or not parser.data is Dictionary:
		last_error = "检查点 JSON 已损坏"
		return {}
	return parser.data as Dictionary
