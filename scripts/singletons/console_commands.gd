extends Node

## 控制台命令辅助类（单例）
## 为 Panku Console 提供游戏内调试命令

func _ready() -> void:
	# 等待一帧，确保 Panku Console 已经初始化
	await get_tree().process_frame
	
	# 注册到 Panku Console 的环境
	var panku = get_node_or_null("/root/Panku")
	if is_instance_valid(panku) and panku.has("gd_exprenv"):
		var gd_exprenv = panku.gd_exprenv
		if is_instance_valid(gd_exprenv) and gd_exprenv.has_method("register_env"):
			gd_exprenv.register_env("cmd", self)
			print("[ConsoleCommands] 已注册到 Panku Console，使用 'cmd.apply_effect()' 调用命令")
		else:
			push_warning("[ConsoleCommands] 无法注册到 Panku Console: gd_exprenv 不可用")
	else:
		push_warning("[ConsoleCommands] 无法注册到 Panku Console: Panku 节点未找到")

## 应用 GameplayEffect 到指定单位
## [param] entity_name_or_path: String 单位名称或路径（如 "Player" 或 "/root/Main/RoomLobby/Player"）
## [param] effect_path: String 效果资源路径（如 "res://data/effects/ge_damage_fire.tres"）
## [param] instigator_name_or_path: String 可选，施法者名称或路径，默认为目标自己
## [return] String 执行结果信息
func apply_effect(entity_name_or_path: String, effect_path: String, instigator_name_or_path: String = "") -> String:
	# 1. 查找目标单位
	var target = _find_entity(entity_name_or_path)
	if not is_instance_valid(target):
		return "错误: 找不到单位 '%s'" % entity_name_or_path
	
	# 2. 查找施法者（如果未指定，使用目标自己）
	var instigator = target
	if instigator_name_or_path != "":
		instigator = _find_entity(instigator_name_or_path)
		if not is_instance_valid(instigator):
			return "错误: 找不到施法者 '%s'" % instigator_name_or_path
	
	# 3. 加载效果资源
	if not ResourceLoader.exists(effect_path):
		return "错误: 效果资源不存在 '%s'" % effect_path
	
	var effect_resource = load(effect_path)
	if not effect_resource is GameplayEffect:
		return "错误: 资源 '%s' 不是 GameplayEffect 类型" % effect_path
	
	var effect = effect_resource as GameplayEffect
	
	# 4. 克隆效果（避免运行时状态共享）
	var effect_instance = effect.duplicate(true) as GameplayEffect
	if not is_instance_valid(effect_instance):
		return "错误: 无法克隆效果资源"
	
	# 5. 应用效果
	effect_instance.apply(target, instigator, {})
	
	return "成功: 已对 '%s' 应用效果 '%s'" % [target.name, effect_path]

## 查找单位（支持名称和路径）
## [param] identifier: String 单位标识符（名称或路径）
## [return] Node 找到的单位节点，如果找不到返回 null
func _find_entity(identifier: String) -> Node:
	if identifier.is_empty():
		return null
	
	# 策略1: 尝试作为路径查找
	if identifier.begins_with("/"):
		var node = get_tree().root.get_node_or_null(identifier)
		if is_instance_valid(node):
			return node
	
	# 策略2: 在 "Entities" 组中查找
	var entities = get_tree().get_nodes_in_group("Entities")
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		# 匹配名称
		if entity.name == identifier:
			return entity
		# 匹配路径（去掉开头的 /root）
		var path_str = str(entity.get_path())
		if path_str.ends_with(identifier) or path_str.contains(identifier):
			return entity
	
	# 策略3: 在整个场景树中查找（递归）
	var scene_root = get_tree().current_scene
	if is_instance_valid(scene_root):
		var found = _find_node_recursive(scene_root, identifier)
		if is_instance_valid(found):
			return found
	
	return null

## 递归查找节点
func _find_node_recursive(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	
	for child in node.get_children():
		var found = _find_node_recursive(child, name)
		if is_instance_valid(found):
			return found
	
	return null

## 列出所有可用单位
## [return] String 单位列表信息
func list_entities() -> String:
	var entities = get_tree().get_nodes_in_group("Entities")
	if entities.is_empty():
		return "未找到任何单位（Entities 组为空）"
	
	var result = "可用单位列表:\n"
	for i in range(entities.size()):
		var entity = entities[i]
		if not is_instance_valid(entity):
			continue
		var path_str = str(entity.get_path())
		result += "  [%d] %s (%s)\n" % [i, entity.name, path_str]
	
	return result

## 列出指定目录下的所有 GameplayEffect 资源
## [param] directory: String 目录路径，默认为 "res://data/effects/"
## [return] String 效果列表信息
func list_effects(directory: String = "res://data/effects/") -> String:
	var dir = DirAccess.open(directory)
	if not dir:
		return "错误: 无法打开目录 '%s'" % directory
	
	var result = "可用效果列表 (%s):\n" % directory
	var count = 0
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			file_name = dir.get_next()
			continue
		
		if file_name.ends_with(".tres"):
			var full_path = directory.path_join(file_name)
			var resource = load(full_path)
			if resource is GameplayEffect:
				var effect = resource as GameplayEffect
				var desc = effect.get_description().split("\n")[0] if effect.get_description() else "无描述"
				result += "  - %s\n    %s\n" % [full_path, desc]
				count += 1
		
		file_name = dir.get_next()
	
	if count == 0:
		result += "  未找到任何 GameplayEffect 资源"
	
	return result

