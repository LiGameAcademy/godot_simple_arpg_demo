extends RefCounted

## 演示旧版本插件的已读记录；配置与运行历史分开保存

var entries: Array[Dictionary] = []

func record(node_id: String, speaker: String, text: String) -> void:
	for entry : Dictionary in entries:
		if entry["node_id"] == node_id:
			return
	entries.append({
		"node_id" : node_id,
		"speaker": speaker,
		"text": text
	})

func replace(data: Array) -> void:
	entries.clear()
	for entry: Dictionary in data:
		entries.append(entry.duplicate(true))
	
static  func validate(data: Variant) -> bool:
	if not data is Array:
		return false
	var ids: Array[String] = []
	for value: Variant in data:
		if not value is Dictionary:
			return false
		var entry: Dictionary = value as Dictionary
		for key: String in ["node_id", "speaker", "text"]:
			if not entry.get(key) is String:
				return false
		if String(entry["node_id"]).is_empty() or ids.has(String(entry["node_id"])):
			return false
		ids.append(String(entry["node_id"]))
	return true
