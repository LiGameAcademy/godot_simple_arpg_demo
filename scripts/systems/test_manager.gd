extends Node

## 测试管理器
## 提供快速测试命令和调试功能

signal test_command_executed(command: String, result: String)

# 测试命令字典
var _test_commands: Dictionary = {}

func _ready() -> void:
	_register_test_commands()
	print("TestManager: 测试管理器已加载")
	print("TestManager: 按 F1 查看帮助")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				_show_help()
			KEY_F2:
				_test_all_abilities()
			KEY_F3:
				_test_all_statuses()
			KEY_F4:
				_test_all_attributes()
			KEY_F5:
				_test_performance()

## 注册测试命令
func _register_test_commands() -> void:
	_test_commands["help"] = _show_help
	_test_commands["abilities"] = _test_all_abilities
	_test_commands["statuses"] = _test_all_statuses
	_test_commands["attributes"] = _test_all_attributes
	_test_commands["performance"] = _test_performance
	_test_commands["add_talent_point"] = _add_talent_point
	_test_commands["add_status"] = _add_status_to_player
	_test_commands["remove_status"] = _remove_status_from_player
	_test_commands["set_health"] = _set_player_health
	_test_commands["set_mana"] = _set_player_mana

## 显示帮助信息
func _show_help() -> void:
	print("\n=== 测试管理器帮助 ===")
	print("快捷键：")
	print("  F1 - 显示帮助")
	print("  F2 - 测试所有技能")
	print("  F3 - 测试所有状态")
	print("  F4 - 测试所有属性")
	print("  F5 - 性能测试")
	print("\n控制台命令：")
	for cmd in _test_commands.keys():
		print("  - %s" % cmd)
	print("====================\n")

## 测试所有技能
func _test_all_abilities() -> void:
	print("\n=== 开始测试所有技能 ===")
	var ability_dir = "res://data/abilities/"
	var dir = DirAccess.open(ability_dir)
	
	if not dir:
		push_error("TestManager: 无法打开技能目录")
		return
	
	var count = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path = ability_dir + file_name
			var resource = load(path)
			if resource:
				print("  ✓ 加载技能: %s" % file_name)
				count += 1
			else:
				push_warning("  ✗ 加载失败: %s" % file_name)
		file_name = dir.get_next()
	
	print("=== 技能测试完成：共 %d 个技能 ===\n" % count)

## 测试所有状态
func _test_all_statuses() -> void:
	print("\n=== 开始测试所有状态 ===")
	var status_dir = "res://data/ability_status/"
	var dir = DirAccess.open(status_dir)
	
	if not dir:
		push_error("TestManager: 无法打开状态目录")
		return
	
	var count = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path = status_dir + file_name
			var resource = load(path)
			if resource:
				print("  ✓ 加载状态: %s" % file_name)
				count += 1
			else:
				push_warning("  ✗ 加载失败: %s" % file_name)
		file_name = dir.get_next()
	
	print("=== 状态测试完成：共 %d 个状态 ===\n" % count)

## 测试所有属性
func _test_all_attributes() -> void:
	print("\n=== 开始测试所有属性 ===")
	var player = _get_player()
	if not player:
		push_error("TestManager: 无法找到玩家")
		return
	
	var attr_comp = GameplayAbilitySystem.get_component_by_interface(player, "GameplayAttributeComponent")
	if not attr_comp:
		push_error("TestManager: 玩家没有属性组件")
		return
	
	print("玩家属性值：")
	var attributes = attr_comp.get_all_attributes()
	for attr_id in attributes.keys():
		var attr_instance = attributes[attr_id]
		var value = attr_instance.get_value()
		var base_value = attr_instance.base_value
		print("  - %s: %.2f (基础值: %.2f)" % [attr_id, value, base_value])
	
	print("=== 属性测试完成 ===\n")

## 性能测试
func _test_performance() -> void:
	print("\n=== 开始性能测试 ===")
	var start_time = Time.get_ticks_msec()
	
	# 测试技能加载性能
	var ability_dir = "res://data/abilities/"
	var dir = DirAccess.open(ability_dir)
	var load_count = 0
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path = ability_dir + file_name
				var resource = load(path)
				if resource:
					load_count += 1
			file_name = dir.get_next()
	
	var end_time = Time.get_ticks_msec()
	var elapsed = end_time - start_time
	
	print("性能测试结果：")
	print("  - 加载 %d 个技能资源耗时: %d ms" % [load_count, elapsed])
	print("  - 平均每个资源: %.2f ms" % (elapsed / float(load_count) if load_count > 0 else 0))
	print("  - 当前 FPS: %.1f" % Engine.get_frames_per_second())
	print("=== 性能测试完成 ===\n")

## 添加天赋点数
func _add_talent_point() -> void:
	TalentManager.add_points(1)
	print("TestManager: 已添加 1 个天赋点数（当前: %d）" % TalentManager.available_points)

## 给玩家添加状态
func _add_status_to_player(status_id: StringName) -> void:
	var player = _get_player()
	if not player:
		push_error("TestManager: 无法找到玩家")
		return
	
	var status_comp = GameplayAbilitySystem.get_component_by_interface(player, "GameplayStatusComponent")
	if not status_comp:
		push_error("TestManager: 玩家没有状态组件")
		return
	
	# 加载状态资源
	var status_path = "res://data/ability_status/%s_status.tres" % status_id
	var status_data = load(status_path) as GameplayStatusData
	
	if not status_data:
		push_error("TestManager: 无法加载状态资源: %s" % status_path)
		return
	
	status_comp.apply_status(status_data, player, 1, {})
	print("TestManager: 已给玩家添加状态: %s" % status_id)

## 移除玩家状态
func _remove_status_from_player(status_id: StringName) -> void:
	var player = _get_player()
	if not player:
		push_error("TestManager: 无法找到玩家")
		return
	
	var status_comp = GameplayAbilitySystem.get_component_by_interface(player, "GameplayStatusComponent")
	if not status_comp:
		push_error("TestManager: 玩家没有状态组件")
		return
	
	status_comp.remove_status(status_id)
	print("TestManager: 已移除玩家状态: %s" % status_id)

## 设置玩家生命值
func _set_player_health(value: float) -> void:
	var player = _get_player()
	if not player:
		push_error("TestManager: 无法找到玩家")
		return
	
	var vital_comp = GameplayAbilitySystem.get_component_by_interface(player, "GameplayVitalAttributeComponent")
	if not vital_comp:
		push_error("TestManager: 玩家没有生命值组件")
		return
	
	var health_vital = vital_comp.get_vital(&"health")
	if not health_vital:
		push_error("TestManager: 玩家没有生命值属性")
		return
	
	health_vital.set_current_value(value)
	print("TestManager: 已设置玩家生命值: %.1f / %.1f" % [value, health_vital.get_max_value()])

## 设置玩家魔法值
func _set_player_mana(value: float) -> void:
	var player = _get_player()
	if not player:
		push_error("TestManager: 无法找到玩家")
		return
	
	var vital_comp = GameplayAbilitySystem.get_component_by_interface(player, "GameplayVitalAttributeComponent")
	if not vital_comp:
		push_error("TestManager: 玩家没有魔法值组件")
		return
	
	var mana_vital = vital_comp.get_vital(&"mana")
	if not mana_vital:
		push_error("TestManager: 玩家没有魔法值属性")
		return
	
	mana_vital.set_current_value(value)
	print("TestManager: 已设置玩家魔法值: %.1f / %.1f" % [value, mana_vital.get_max_value()])

## 获取玩家节点
func _get_player() -> Node:
	# 尝试从场景树中查找玩家
	var tree = get_tree()
	if not tree:
		return null
	
	# 查找 Player 节点
	var player = tree.get_first_node_in_group("player")
	if player:
		return player
	
	# 如果没找到，尝试通过类型查找
	for node in tree.get_nodes_in_group("player"):
		if node is Player:
			return node
	
	return null

## 执行测试命令（供外部调用）
func execute_command(command: String, args: Array = []) -> void:
	if not _test_commands.has(command):
		push_warning("TestManager: 未知命令: %s" % command)
		_show_help()
		return
	
	var func_ref = _test_commands[command]
	if args.is_empty():
		func_ref.call()
	else:
		func_ref.callv(args)

