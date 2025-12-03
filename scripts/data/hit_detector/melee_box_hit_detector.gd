extends HitDetectorBase
class_name MeleeBoxHitDetector

## 攻击盒的大小 (半宽/半高/半深)
@export var box_extents: Vector3 = Vector3(1, 1, 1)
## 攻击盒相对于角色的偏移 (比如前方 1米)
@export var offset: Vector3 = Vector3(0, 1, 1)
## 碰撞层级掩码
@export_flags_3d_physics var collision_mask: int = 1

func _get_targets(caster: Node3D, context: Dictionary = {}) -> Array[Node]:
	if not caster: return []
	
	# 1. 构建查询参数
	var space_state = caster.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# 2. 创建形状
	var shape = BoxShape3D.new()
	shape.size = box_extents * 2 # BoxShape使用全长
	query.shape = shape
	
	# 3. 从 context 获取角色面朝方向（优先使用传入的值）
	var facing_angle: float = 0.0
	if context.has("facing_angle"):
		# 直接使用传入的角度（弧度）
		facing_angle = context["facing_angle"]
	elif context.has("facing_direction"):
		# 从方向向量计算角度
		var facing_dir = context["facing_direction"] as Vector3
		if facing_dir != Vector3.ZERO:
			facing_angle = atan2(facing_dir.x, facing_dir.z)

	# 4. 构建旋转矩阵（Y轴旋转）
	var rotation_basis = Basis.from_euler(Vector3(0, facing_angle, 0))
	
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
		
	return targets
