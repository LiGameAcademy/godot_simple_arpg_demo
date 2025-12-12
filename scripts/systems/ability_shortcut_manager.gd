extends Node
class_name AbilityShortcutManager

## 技能快捷键管理器（输入映射层）
## 职责：处理技能快捷键绑定和输入检测，通过信号通知外部系统
##
## 设计原则：
## - 纯输入映射层，不持有 player 或 ability_component 的引用
## - 通过信号系统解耦，由外部系统（如 PlayerController）连接信号到具体执行逻辑
##
## 支持的快捷键格式：
## - 数字键: "1", "2", "3", ..., "9"
## - 字母键: "Q", "E", "R", "T", "F", "Z", "X", "C", "V"
## - 鼠标按键: "MOUSE_LEFT", "MOUSE_RIGHT", "MOUSE_MIDDLE", "MOUSE_X1", "MOUSE_X2"

## 当检测到技能施放意图时发出
## [param] ability_id: StringName 技能 ID
## [param] shortcut: String 触发的快捷键
## [param] context: Dictionary 上下文信息
signal cast_ability_requested(ability_id: StringName, shortcut: String, context: Dictionary)

## 当检测到引导取消意图时发出（按键释放）
## [param] ability_id: StringName 技能 ID
## [param] shortcut: String 触发的快捷键
signal cancel_channeling_requested(ability_id: StringName, shortcut: String)

# 快捷键映射（快捷键字符串 -> 技能 ID）
var shortcut_to_ability: Dictionary[String, StringName] = {}

# 反向映射（技能 ID -> 快捷键字符串）
var ability_to_shortcut: Dictionary[StringName, String] = {}

## 处理未处理的输入事件（应在 _unhandled_input 中调用）
## [param] event: InputEvent 输入事件
## [return] bool 是否处理了输入
func _unhandled_input(event: InputEvent) -> void:
	if event == null:
		return
	
	# 处理按键释放事件（用于取消引导技能）
	if _is_key_release_event(event):
		var shortcut = _get_shortcut_from_event(event)
		if not shortcut.is_empty() and shortcut_to_ability.has(shortcut):
			var ability_id = shortcut_to_ability[shortcut]
			# 发出取消引导信号，由外部系统判断是否应该取消
			cancel_channeling_requested.emit(ability_id, shortcut)
			get_viewport().set_input_as_handled()
		return
	
	# 处理按键按下事件（用于施放技能）
	# 【关键】忽略按键重复事件（echo），避免按住按键时持续触发信号
	# 只有第一次按下时才触发，后续的 echo 事件会被忽略
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.echo:
			# 这是按键重复事件，忽略
			return
	
	for shortcut in shortcut_to_ability.keys():
		if shortcut.is_empty():
			continue
		
		if _is_shortcut_event(event, shortcut):
			var ability_id = shortcut_to_ability[shortcut]
			if ability_id == null or ability_id == &"":
				push_error("AbilityShortcutManager: Invalid ability_id for shortcut: %s" % shortcut)
				continue
			
			# 创建 context
			var context: Dictionary = {}
			# 发出技能施放信号，由外部系统执行具体逻辑
			cast_ability_requested.emit(ability_id, shortcut, context)
			get_viewport().set_input_as_handled()
			return

## 绑定快捷键
## [param] ability_id: StringName 技能 ID
## [param] shortcut: String 快捷键（如 "1", "Q", "E", "R", "MOUSE_LEFT" 等）
## [return] bool 是否绑定成功
func bind_shortcut(ability_id: StringName, shortcut: String) -> bool:
	# 错误处理：检查参数有效性
	if ability_id == null or ability_id == &"":
		push_error("AbilityShortcutManager: Cannot bind shortcut, ability_id is empty")
		return false
	
	if shortcut.is_empty():
		push_warning("AbilityShortcutManager: Cannot bind shortcut for ability %s, shortcut is empty" % ability_id)
		return false
	
	# 验证快捷键格式
	if not _is_valid_shortcut(shortcut):
		push_error("AbilityShortcutManager: Invalid shortcut format: %s (for ability %s)" % [shortcut, ability_id])
		return false
	
	# 检查快捷键冲突（如果快捷键已被其他技能使用）
	if shortcut_to_ability.has(shortcut):
		var existing_ability = shortcut_to_ability[shortcut]
		if existing_ability != ability_id:
			push_warning("AbilityShortcutManager: Shortcut '%s' is already bound to ability '%s', will be replaced by '%s'" % [shortcut, existing_ability, ability_id])
			# 移除旧技能的绑定
			ability_to_shortcut.erase(existing_ability)
	
	# 移除旧的绑定（如果存在）
	if ability_to_shortcut.has(ability_id):
		var old_shortcut = ability_to_shortcut[ability_id]
		if old_shortcut != shortcut:
			shortcut_to_ability.erase(old_shortcut)
	
	# 添加新绑定
	shortcut_to_ability[shortcut] = ability_id
	ability_to_shortcut[ability_id] = shortcut
	
	return true

## 解绑快捷键
## [param] ability_id: StringName 技能 ID
## [return] bool 是否解绑成功
func unbind_shortcut(ability_id: StringName) -> bool:
	if ability_id == null or ability_id == &"":
		push_warning("AbilityShortcutManager: Cannot unbind shortcut, ability_id is empty")
		return false
	
	if not ability_to_shortcut.has(ability_id):
		push_warning("AbilityShortcutManager: Ability %s is not bound to any shortcut" % ability_id)
		return false
	
	var shortcut = ability_to_shortcut[ability_id]
	shortcut_to_ability.erase(shortcut)
	ability_to_shortcut.erase(ability_id)
	
	return true

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
	
	# 验证快捷键格式
	if not _is_valid_shortcut(shortcut):
		return false
	
	# 支持鼠标按键
	if shortcut.begins_with("MOUSE_"):
		return _is_mouse_button_pressed(shortcut)
	
	# 支持数字键 1-9（直接检查键码，不依赖输入映射）
	if shortcut.length() == 1 and shortcut.is_valid_int():
		var num = shortcut.to_int()
		if num >= 1 and num <= 9:
			# 直接检查键码：KEY_1 到 KEY_9
			var num_keycode: Key = (KEY_1 + (num - 1)) as Key
			return Input.is_key_pressed(num_keycode)
	
	# 支持字母键（转换为小写）
	var lower_shortcut = shortcut.to_lower()
	var letter_keycode = _get_keycode_from_string(lower_shortcut)
	if letter_keycode != KEY_NONE:
		return Input.is_key_pressed(letter_keycode)
	
	return false

## 验证快捷键格式是否有效
## [param] shortcut: String 快捷键字符串
## [return] bool 是否有效
func _is_valid_shortcut(shortcut: String) -> bool:
	if shortcut.is_empty():
		return false
	
	# 支持鼠标按键
	if shortcut.begins_with("MOUSE_"):
		var mouse_buttons = ["MOUSE_LEFT", "MOUSE_RIGHT", "MOUSE_MIDDLE", "MOUSE_X1", "MOUSE_X2"]
		return mouse_buttons.has(shortcut)
	
	# 支持数字键 1-9
	if shortcut.length() == 1 and shortcut.is_valid_int():
		var num = shortcut.to_int()
		return num >= 1 and num <= 9
	
	# 支持字母键（单字符）
	if shortcut.length() == 1:
		var lower = shortcut.to_lower()
		var supported_keys = ["q", "e", "r", "t", "f", "z", "x", "c", "v"]
		return supported_keys.has(lower)
	
	return false

## 将字符串转换为键码
## [param] key_str: String 键字符串（如 "q", "e", "r"）
## [return] Key 键码，如果无效则返回 KEY_NONE
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

## 将字符串转换为鼠标按键索引
## [param] mouse_str: String 鼠标按键字符串（如 "MOUSE_LEFT"）
## [return] MouseButton 鼠标按键索引，如果无效则返回 MOUSE_BUTTON_NONE
func _get_mouse_button_from_string(mouse_str: String) -> MouseButton:
	var mouse_map = {
		"MOUSE_LEFT": MOUSE_BUTTON_LEFT,
		"MOUSE_RIGHT": MOUSE_BUTTON_RIGHT,
		"MOUSE_MIDDLE": MOUSE_BUTTON_MIDDLE,
		"MOUSE_X1": MOUSE_BUTTON_XBUTTON1,
		"MOUSE_X2": MOUSE_BUTTON_XBUTTON2,
	}
	return mouse_map.get(mouse_str, MOUSE_BUTTON_NONE)

## 检查鼠标按键是否被按下
## [param] shortcut: String 鼠标按键快捷键（如 "MOUSE_LEFT"）
## [return] bool 是否被按下
func _is_mouse_button_pressed(shortcut: String) -> bool:
	var button = _get_mouse_button_from_string(shortcut)
	if button == MOUSE_BUTTON_NONE:
		return false
	return Input.is_mouse_button_pressed(button)

## 检查是否是按键释放事件
## [param] event: InputEvent 输入事件
## [return] bool 是否是按键释放
func _is_key_release_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event = event as InputEventKey
		return not key_event.pressed
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		return not mouse_event.pressed
	return false

## 从输入事件获取快捷键字符串
## [param] event: InputEvent 输入事件
## [return] String 快捷键字符串，如果无法识别则返回空字符串
func _get_shortcut_from_event(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		var button_map = {
			MOUSE_BUTTON_LEFT: "MOUSE_LEFT",
			MOUSE_BUTTON_RIGHT: "MOUSE_RIGHT",
			MOUSE_BUTTON_MIDDLE: "MOUSE_MIDDLE",
			MOUSE_BUTTON_XBUTTON1: "MOUSE_X1",
			MOUSE_BUTTON_XBUTTON2: "MOUSE_X2",
		}
		return button_map.get(mouse_event.button_index, "")
	
	if event is InputEventKey:
		var key_event = event as InputEventKey
		# 检查数字键 1-9
		if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
			var num = key_event.keycode - KEY_1 + 1
			return str(num)
		
		# 检查字母键
		var key_map = {
			KEY_Q: "Q",
			KEY_E: "E",
			KEY_R: "R",
			KEY_T: "T",
			KEY_F: "F",
			KEY_Z: "Z",
			KEY_X: "X",
			KEY_C: "C",
			KEY_V: "V",
		}
		return key_map.get(key_event.keycode, "")
	
	return ""


## 检查输入事件是否匹配快捷键
## [param] event: InputEvent 输入事件
## [param] shortcut: String 快捷键
## [return] bool 是否匹配
func _is_shortcut_event(event: InputEvent, shortcut: String) -> bool:
	# 错误处理：检查参数有效性
	if event == null:
		return false
	
	if shortcut.is_empty():
		return false
	
	# 验证快捷键格式
	if not _is_valid_shortcut(shortcut):
		return false
	
	# 支持鼠标按键
	if shortcut.begins_with("MOUSE_"):
		if event is InputEventMouseButton:
			var mouse_event = event as InputEventMouseButton
			if not mouse_event.pressed:
				return false
			
			var expected_button = _get_mouse_button_from_string(shortcut)
			if expected_button == MOUSE_BUTTON_NONE:
				return false
			
			return mouse_event.button_index == expected_button
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
				var num_keycode: Key = (KEY_1 + (num - 1)) as Key
				return key_event.keycode == num_keycode
		return false
	
	# 支持字母键
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if not key_event.pressed:
			return false
		
		var lower_shortcut = shortcut.to_lower()
		var expected_key = _get_keycode_from_string(lower_shortcut)
		if expected_key == KEY_NONE:
			return false
		
		return key_event.keycode == expected_key
	
	return false
