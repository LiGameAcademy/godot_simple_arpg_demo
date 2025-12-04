extends Node
class_name AbilityShortcutManager

## 技能快捷键管理器
## 处理技能快捷键绑定和输入检测

# 快捷键映射（快捷键字符串 -> 技能 ID）
var shortcut_to_ability: Dictionary[String, StringName] = {}

# 反向映射（技能 ID -> 快捷键字符串）
var ability_to_shortcut: Dictionary[StringName, String] = {}

## 绑定快捷键
## [param] ability_id: StringName 技能 ID
## [param] shortcut: String 快捷键（如 "1", "Q", "E", "R" 等）
func bind_shortcut(ability_id: StringName, shortcut: String) -> void:
	# 移除旧的绑定（如果存在）
	if ability_to_shortcut.has(ability_id):
		var old_shortcut = ability_to_shortcut[ability_id]
		shortcut_to_ability.erase(old_shortcut)
	
	# 添加新绑定
	shortcut_to_ability[shortcut] = ability_id
	ability_to_shortcut[ability_id] = shortcut

## 解绑快捷键
## [param] ability_id: StringName 技能 ID
func unbind_shortcut(ability_id: StringName) -> void:
	if not ability_to_shortcut.has(ability_id):
		return
	
	var shortcut = ability_to_shortcut[ability_id]
	shortcut_to_ability.erase(shortcut)
	ability_to_shortcut.erase(ability_id)

## 获取技能的快捷键
## [param] ability_id: StringName 技能 ID
## [return] String 快捷键，如果未绑定则返回空字符串
func get_shortcut(ability_id: StringName) -> String:
	return ability_to_shortcut.get(ability_id, "")

## 检查快捷键是否被按下
## [param] shortcut: String 快捷键
## [return] bool 是否被按下
func is_shortcut_pressed(shortcut: String) -> bool:
	if shortcut.is_empty():
		return false
	
	# 支持数字键 1-9（直接检查键码，不依赖输入映射）
	if shortcut.length() == 1 and shortcut.is_valid_int():
		var num = shortcut.to_int()
		if num >= 1 and num <= 9:
			# 直接检查键码：KEY_1 到 KEY_9
			var keycode = KEY_1 + (num - 1)
			return Input.is_key_pressed(keycode)
	
	# 支持字母键（转换为小写）
	var lower_shortcut = shortcut.to_lower()
	return Input.is_key_pressed(_get_keycode_from_string(lower_shortcut))

## 将字符串转换为键码
## [param] key_str: String 键字符串（如 "q", "e", "r"）
## [return] Key 键码
func _get_keycode_from_string(key_str: String) -> Key:
	var key_map = {
		"q": KEY_Q,
		"e": KEY_E,
		"r": KEY_R,
		"t": KEY_T,
		"f": KEY_F,
		"z": KEY_Z,
		"x": KEY_X,
		"c": KEY_C,
		"v": KEY_V,
	}
	return key_map.get(key_str, KEY_NONE)

## 处理输入事件（应在 _unhandled_input 中调用）
## [param] event: InputEvent 输入事件
## [param] player: Node 玩家节点（需要实现 try_cast_ability 方法）
## [return] bool 是否处理了输入
func handle_input(event: InputEvent, player: Node) -> bool:
	if not is_instance_valid(player) or not player.has_method("try_cast_ability"):
		return false
	
	# 检查所有绑定的快捷键
	for shortcut in shortcut_to_ability.keys():
		if _is_shortcut_event(event, shortcut):
			var ability_id = shortcut_to_ability[shortcut]
			player.try_cast_ability(ability_id)
			return true
	
	return false

## 检查输入事件是否匹配快捷键
## [param] event: InputEvent 输入事件
## [param] shortcut: String 快捷键
## [return] bool 是否匹配
func _is_shortcut_event(event: InputEvent, shortcut: String) -> bool:
	if shortcut.is_empty():
		return false
	
	# 支持数字键 1-9
	if shortcut.length() == 1 and shortcut.is_valid_int():
		var num = shortcut.to_int()
		if num >= 1 and num <= 9:
			if event is InputEventKey:
				var key_event = event as InputEventKey
				if not key_event.pressed:
					return false
				# 直接检查键码：KEY_1 到 KEY_9
				var keycode = KEY_1 + (num - 1)
				return key_event.keycode == keycode
	
	# 支持字母键
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if not key_event.pressed:
			return false
		
		var lower_shortcut = shortcut.to_lower()
		var expected_key = _get_keycode_from_string(lower_shortcut)
		return key_event.keycode == expected_key
	
	return false
