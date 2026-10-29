extends RefCounted

const Quests = preload("res://addons/laoli_dialogue_system/scripts/core/save/quest_snapshot.gd")
const Transcript = preload("res://addons/laoli_dialogue_system/scripts/core/save/dialogue_transcript.gd")
const VERSION: int = 1

var last_error: String = ""
var quests: Quests = Quests.new()

func validate(data: Dictionary, database: Dictionary[String, Quest]) -> bool:
	last_error = ""
	if not Quests.is_integer(data.get("schema_version")) or int(data["schema_version"]) != VERSION:
		return _reject("检查点版本不兼容")
	if data.get("checkpoint") not in ["before_intro", "before_resolution", "after_boss"]:
		return _reject("检查点位置无效")
	if not data.get("story") is Dictionary or not data.get("quests") is Dictionary or not Transcript.validate(data.get("history")):
		return _reject("检查点字段无效")
	var story: Dictionary = data["story"]
	for key: String in ["intro_seen", "boss_defeated", "resolution_seen"]:
		if not story.get(key) is bool:
			return _reject("剧情标记类型无效")
	if bool(story["resolution_seen"]) and not bool(story["boss_defeated"]) or bool(story["boss_defeated"]) and not bool(story["intro_seen"]):
		return _reject("剧情标记相互矛盾")
	var expected: String = phase(bool(story["intro_seen"]), bool(story["boss_defeated"]))
	if data["checkpoint"] != expected:
		return _reject("剧情标记与检查点不一致")
	if not quests.prepare(data["quests"], database):
		return _reject(quests.last_error)
	var clone_found: bool = quests.prepared_completed.has("defeat_clone")
	var clone_done: bool = clone_found
	for quest: Quest in quests.prepared_quests:
		if quest.id == "defeat_clone":
			clone_found = true
			clone_done = quest.is_completed
	if clone_found != bool(story["intro_seen"]) or clone_done != bool(story["boss_defeated"]):
		return _reject("剧情标记与克隆体任务不一致")
	return true

static func phase(intro_seen: bool, boss_defeated: bool) -> String:
	return "after_boss" if boss_defeated else ("before_resolution" if intro_seen else "before_intro")

func _reject(message: String) -> bool:
	last_error = message
	return false
