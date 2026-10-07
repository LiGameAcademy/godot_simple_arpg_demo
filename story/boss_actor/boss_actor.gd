extends Node3D
## 展示演员：仅管理自身视觉，不接入输入、任务或战斗规则。
@export_range(0.0, 1.0) var corruption_amount: float = 1.0
@onready var visuals: Node3D = $Visuals
@onready var animation_tree: AnimationTree = $Visuals/Barbarian/AnimationTree
@onready var animation_player: AnimationPlayer = $Visuals/Barbarian/AnimationPlayer
var _materials: Array[ShaderMaterial] = []
const CORRUPTION_SHADER: Shader = preload("res://story/boss_actor/corruption.gdshader")

func _ready() -> void:
	#region ========== 演员表现 ==========
	_prepare_visual_animation()
	for candidate: Node in visuals.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source: StandardMaterial3D = mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			var material: ShaderMaterial = ShaderMaterial.new()
			material.shader = CORRUPTION_SHADER
			if source != null:
				material.set_shader_parameter("base_color", source.albedo_color)
				if source.albedo_texture != null:
					material.set_shader_parameter("base_texture", source.albedo_texture)
					material.set_shader_parameter("use_texture", true)
			material.set_shader_parameter("corruption_amount", corruption_amount)
			mesh_instance.set_surface_override_material(surface_index, material)
			_materials.append(material)
	animation_tree.active = true
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback
	if playback != null:
		playback.start("movement")
	#endregion

## 材质为当前演员独占；不修改共享模型或源材质。
func set_corruption(amount: float) -> void:
	corruption_amount = clampf(amount, 0.0, 1.0)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("corruption_amount", corruption_amount)

func play_pose(pose: StringName) -> void:
	if pose == &"death":
		animation_tree.active = false
		animation_player.play(&"hero/Death_A")
		return
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback
	playback.travel(pose)

func set_movement_speed(speed: float) -> void:
	animation_tree.set("parameters/StateMachine/movement/blend_position", speed)

func _prepare_visual_animation() -> void:
	animation_tree.active = false
	# 玩家攻击素材包含命中框轨道，展示演员没有该组件。只复制并移除该轨道。
	var source_library: AnimationLibrary = animation_player.get_animation_library(&"hero")
	var local_library: AnimationLibrary = source_library.duplicate() as AnimationLibrary
	var attack: Animation = source_library.get_animation(&"Melee_1H_Attack_Chop").duplicate() as Animation
	for track_index: int in range(attack.get_track_count() - 1, -1, -1):
		if attack.track_get_path(track_index) == NodePath("../SwordHitbox:monitoring"):
			attack.remove_track(track_index)
	local_library.remove_animation(&"Melee_1H_Attack_Chop")
	local_library.add_animation(&"Melee_1H_Attack_Chop", attack)
	animation_player.remove_animation_library(&"hero")
	animation_player.add_animation_library(&"hero", local_library)
