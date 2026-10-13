extends Node3D

const CORRUPTION_SHADER : Shader = preload("res://prefabs/boss_actor/corruption.gdshader")

@export_range(0.0, 1.0) var corruptioon_amount : float = 1.0
@onready var visuals: Node3D = $Visuals
@onready var animation_player: AnimationPlayer = $Visuals/Barbarian/AnimationPlayer
@onready var animation_tree: AnimationTree = $Visuals/Barbarian/AnimationTree
var _materials : Array[ShaderMaterial] = []

func _ready() -> void:
	for mesh_instance : MeshInstance3D in visuals.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null:
			continue
		for surface_index : int in range(mesh_instance.mesh.get_surface_count()):
			var source: StandardMaterial3D = mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			var material : ShaderMaterial = ShaderMaterial.new()
			material.shader = CORRUPTION_SHADER
			if source != null:
				material.set_shader_parameter("base_color", source.albedo_color)
				if source.albedo_texture != null:
					material.set_shader_parameter("base_texture", source.albedo_texture)
					material.set_shader_parameter("use_texture", true)
			material.set_shader_parameter("corruption_amount", corruptioon_amount)
			mesh_instance.set_surface_override_material(surface_index, material)
			_materials.append(material)
	var playback : AnimationNodeStateMachinePlayback = animation_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback
	if playback != null:
		playback.start("movement")
	
func set_corruption(amount: float) -> void:
	corruptioon_amount = clampf(amount, 0.0, 1.0)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("corruption_amount", corruptioon_amount)

func play_pose(pose : StringName) -> void:
	if pose == &"death":
		animation_tree.active = false
		animation_player.play("hero/Death_A")
		return
	var playback : AnimationNodeStateMachinePlayback = animation_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback
	playback.travel(pose)

func set_movement_speed(speed: float) -> void:
	animation_tree.set("parameters/StateMachine/movement/blend_position", speed)
	
func _prepare_visual_animation() -> void:
	# 玩家攻击素材包括命中框轨道，展示Actor没有这个组件，只复制并移除该轨道
	pass
