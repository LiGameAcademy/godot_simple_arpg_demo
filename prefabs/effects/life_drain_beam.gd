extends Node3D
class_name LifeDrainBeam

## 生命吸取牵引绳特效
## 在施法者和目标之间绘制一条连接线，表示生命吸取效果

## 起点位置（世界坐标）
var start_point: Vector3 = Vector3.ZERO
## 终点位置（世界坐标）
var end_point: Vector3 = Vector3.ZERO
## 施法者节点（用于持续更新）
var instigator: Node = null
## 目标节点（用于持续更新）
var target: Node = null

## 牵引绳粗细
@export var beam_thickness: float = 0.05
## 牵引绳颜色
@export var beam_color: Color = Color(1.0, 0.2, 0.2, 0.8)
## 是否显示粒子效果
@export var show_particles: bool = true

@onready var beam_mesh: MeshInstance3D = $BeamMesh
@onready var particles: GPUParticles3D = $Particles

func _ready() -> void:
	_update_beam()

func _process(_delta: float) -> void:
	# 持续更新牵引绳位置
	_update_beam()

## 设置起点和终点
## [param] start: Vector3 起点位置（世界坐标）
## [param] end: Vector3 终点位置（世界坐标）
func set_start_and_end(start: Vector3, end: Vector3) -> void:
	start_point = start
	end_point = end
	_update_beam()

## 更新位置（由 Cue 组件调用）
## [param] start: Vector3 起点位置（世界坐标）
## [param] end: Vector3 终点位置（世界坐标）
func update_positions(start: Vector3, end: Vector3) -> void:
	set_start_and_end(start, end)

## 更新牵引绳视觉效果
func _update_beam() -> void:
	if not is_instance_valid(beam_mesh):
		return
	
	# 计算方向和距离
	var direction = end_point - start_point
	var distance = direction.length()
	
	if distance < 0.001:
		# 距离太近，隐藏牵引绳
		beam_mesh.visible = false
		return
	
	beam_mesh.visible = true
	
	# 设置位置为起点和终点的中点
	global_position = (start_point + end_point) / 2.0
	
	# 计算旋转（使圆柱体朝向终点）
	var up = Vector3.UP
	var forward = direction.normalized()
	
	# 如果方向与 UP 向量平行，使用不同的上向量
	if abs(forward.dot(up)) > 0.99:
		up = Vector3.RIGHT
	
	# 使用 look_at 计算旋转
	var target_pos = global_position + forward
	look_at(target_pos, up)
	
	# 调整圆柱体的高度和粗细
	# 注意：在 Godot 4 中，Resource 不能直接修改，需要创建新实例
	var mesh = beam_mesh.mesh
	if mesh is CylinderMesh:
		# 创建新的 CylinderMesh 实例（避免修改原始资源）
		var new_cylinder_mesh = CylinderMesh.new()
		new_cylinder_mesh.height = distance
		new_cylinder_mesh.top_radius = beam_thickness
		new_cylinder_mesh.bottom_radius = beam_thickness
		beam_mesh.mesh = new_cylinder_mesh
		
		# 更新材质颜色（如果材质存在）
		var material = beam_mesh.get_surface_override_material(0)
		if material is StandardMaterial3D:
			var std_material = material as StandardMaterial3D
			std_material.albedo_color = beam_color
		elif material == null:
			# 如果没有材质，创建一个新的
			var new_material = StandardMaterial3D.new()
			new_material.albedo_color = beam_color
			new_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			new_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			beam_mesh.set_surface_override_material(0, new_material)
	
	# 更新粒子效果（如果启用）
	if is_instance_valid(particles) and show_particles:
		particles.global_position = global_position
		# 可以在这里配置粒子效果，使其沿着牵引绳流动

## 从上下文设置参数（由 Cue 组件调用）
## [param] context: Dictionary 上下文信息
func setup_from_context(context: Dictionary) -> void:
	# 可以从 context 中读取参数，如颜色、粗细等
	if context.has("beam_color"):
		beam_color = context["beam_color"]
	if context.has("beam_thickness"):
		beam_thickness = context["beam_thickness"]

## 清理特效（播放消失动画或直接销毁）
func cleanup() -> void:
	# 可以在这里播放消失动画
	# 暂时直接销毁
	queue_free()

