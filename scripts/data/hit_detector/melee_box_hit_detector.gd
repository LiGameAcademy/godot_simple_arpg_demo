extends HitDetectorBase
class_name MeleeBoxHitDetector

## 攻击盒的大小 (半宽/半高/半深)
@export var box_extents: Vector3 = Vector3(1, 1, 1)
## 攻击盒相对于角色的偏移 (比如前方 1米)
@export var offset: Vector3 = Vector3(0, 1, 1)
## 碰撞层级掩码
@export_flags_3d_physics var collision_mask: int = 1

## 是否启用调试绘制（需要配置 debug_draw 为 autoload，建议命名为 "DDD"）
@export var debug_draw_enabled: bool = false
## 调试框体显示时间（帧数，0 表示只显示 1 帧）
@export var debug_linger_frames: int = 30
## 攻击盒绘制颜色
@export var debug_box_color: Color = Color.YELLOW
## 方向向量绘制颜色
@export var debug_direction_color: Color = Color.CYAN
## 目标绘制颜色
@export var debug_target_color: Color = Color.RED

func _get_targets(caster: Node3D, context: Dictionary = {}) -> Array[Node]:
	if not caster: return []
	
	# 1. 构建查询参数
	var space_state = caster.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# 2. 创建形状
	var shape = BoxShape3D.new()
	shape.size = box_extents * 2 # BoxShape使用全长
	query.shape = shape
	
	# 3. 从 context 获取角色面朝方向（优先使用方向向量，更准确）
	var facing_dir: Vector3 = Vector3.ZERO
	if context.has("facing_direction"):
		facing_dir = (context["facing_direction"] as Vector3).normalized()
	elif context.has("facing_angle"):
		# 既然你有角度，直接构建一个绕 Y 轴的旋转即可
		# 假设 0 度是朝前 (-Z)，那么旋转该角度后的前方就是：
		facing_dir = Basis.from_euler(Vector3(0, context["facing_angle"], 0)) * Vector3.FORWARD
	else:
		var visuals = caster.get_node_or_null("Visuals")
		if is_instance_valid(visuals) and visuals is Node3D:
			# 直接用 Visuals 的 Basis 变换“前方”向量
			facing_dir = visuals.global_transform.basis * Vector3.FORWARD
		else:
			# 使用 transform 的 -Z 轴
			facing_dir = -caster.global_transform.basis.z
	
	# 如果还是没有方向，使用默认方向
	if facing_dir.length_squared() < 0.01:
		facing_dir = -caster.global_transform.basis.z
	
	facing_dir = facing_dir.normalized()
	
	# 4. 构建旋转矩阵（从方向向量构建，更准确）
	var up = Vector3.UP
	var right = facing_dir.cross(up).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	up = right.cross(facing_dir).normalized()
	var rotation_basis = Basis(right, up, facing_dir)
	
	# 5. 计算攻击盒的位置和旋转
	# 将 offset 从局部空间转换到世界空间（应用角色朝向）
	var rotated_offset = rotation_basis * offset
	var box_position = caster.global_position + rotated_offset
	
	# 6. 构建完整的 transform（位置 + 旋转）
	var box_transform = Transform3D(rotation_basis, box_position)
	query.transform = box_transform
	
	query.collision_mask = collision_mask
	query.collide_with_areas = true # 根据需要开启
	query.collide_with_bodies = true
	query.exclude = [caster] # 排除施法者自己
	
	# 7. 执行查询
	var results = space_state.intersect_shape(query)
	var targets: Array[Node] = []
	
	for data in results:
		var collider = data.get("collider")
		if not is_instance_valid(collider):
			continue
		
		# 通过工具函数转换为实体根节点
		var entity = collider.get_parent()
		if is_instance_valid(entity):
			targets.append(entity)
	
	# 8. 调试绘制（如果启用）
	if debug_draw_enabled:
		_draw_debug_info(caster, box_transform, facing_dir, targets)
		
	return targets

## 绘制调试信息
func _draw_debug_info(caster: Node3D, box_transform: Transform3D, facing_dir: Vector3, targets: Array[Node]) -> void:
	if not is_instance_valid(caster):
		return
	
	# 尝试获取 debug_draw 单例（可能命名为 "DDD" 或 "DebugDraw"）
	var debug_draw = _get_debug_draw_singleton(caster)
	if not is_instance_valid(debug_draw):
		return
	
	# 1. 绘制攻击盒（使用完整的 transform）
	# 注意：draw_transformed_cube 不支持 linger_frames，所以我们使用 draw_box_aabb
	# 从 transform 和 box_extents 计算旋转后的 AABB
	# 计算局部空间的 8 个顶点
	var local_corners = [
		Vector3(-box_extents.x, -box_extents.y, -box_extents.z),
		Vector3( box_extents.x, -box_extents.y, -box_extents.z),
		Vector3(-box_extents.x,  box_extents.y, -box_extents.z),
		Vector3( box_extents.x,  box_extents.y, -box_extents.z),
		Vector3(-box_extents.x, -box_extents.y,  box_extents.z),
		Vector3( box_extents.x, -box_extents.y,  box_extents.z),
		Vector3(-box_extents.x,  box_extents.y,  box_extents.z),
		Vector3( box_extents.x,  box_extents.y,  box_extents.z)
	]
	# 转换到世界空间
	var world_corners: Array[Vector3] = []
	for corner in local_corners:
		world_corners.append(box_transform * corner)
	# 计算世界空间的 AABB
	var min_pos = world_corners[0]
	var max_pos = world_corners[0]
	for corner in world_corners:
		min_pos = min_pos.min(corner)
		max_pos = max_pos.max(corner)
	var world_aabb = AABB(min_pos, max_pos - min_pos)
	debug_draw.draw_box_aabb(world_aabb, debug_box_color, debug_linger_frames)
	
	# 2. 绘制攻击盒的坐标轴（显示朝向）
	debug_draw.draw_axes(box_transform, 0.3)
	
	# 3. 绘制从角色位置到攻击盒中心的连线
	debug_draw.draw_line_3d(caster.global_position, box_transform.origin, Color(debug_box_color.r, debug_box_color.g, debug_box_color.b, 0.5))
	
	# 4. 绘制方向向量（从攻击盒中心向前）
	var direction_length = box_extents.z * 2.0  # 使用 Z 轴长度作为方向向量长度
	debug_draw.draw_ray_3d(box_transform.origin, facing_dir, direction_length, debug_direction_color)
	
	# 5. 绘制检测到的目标位置
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		var target_pos: Vector3
		if target is Node3D:
			target_pos = (target as Node3D).global_position
		else:
			# 尝试获取子节点中的 Node3D
			var node3d = target as Node
			if is_instance_valid(node3d):
				var child_3d = node3d.get_node_or_null("Visuals")
				if is_instance_valid(child_3d) and child_3d is Node3D:
					target_pos = (child_3d as Node3D).global_position
				else:
					target_pos = node3d.global_position if node3d.has_method("get_global_position") else Vector3.ZERO
		
		# 绘制从攻击盒到目标的连线
		debug_draw.draw_line_3d(box_transform.origin, target_pos, debug_target_color)
		# 在目标位置绘制一个小立方体
		debug_draw.draw_cube(target_pos, 0.2, debug_target_color, 5)

## 获取 debug_draw 单例
func _get_debug_draw_singleton(caster: Node3D) -> Node:
	if not is_instance_valid(caster):
		return null
	
	var tree = caster.get_tree()
	if not is_instance_valid(tree):
		return null
	
	# 尝试常见的命名：DDD（推荐）、DebugDraw
	var names = ["DDD", "DebugDraw", "debug_draw"]
	for name in names:
		# 尝试从 autoload 获取
		if Engine.has_singleton(name):
			var singleton = Engine.get_singleton(name)
			if is_instance_valid(singleton):
				return singleton
		# 也尝试从场景树中查找
		var node = tree.get_first_node_in_group(name)
		if is_instance_valid(node):
			return node
	
	# 如果都没找到，尝试通过类型查找（如果它是 autoload）
	var root = tree.root
	for child in root.get_children():
		if child.get_script() and child.get_script().resource_path.ends_with("debug_draw.gd"):
			return child
	
	return null
