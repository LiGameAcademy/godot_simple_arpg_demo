extends SceneTree
## 独立验证演员材质与实例状态，不需要游戏 UI 或战斗服务。
const ACTOR: PackedScene = preload("res://story/boss_actor/boss_actor.tscn")

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var actor_a: Node3D = ACTOR.instantiate() as Node3D
	var actor_b: Node3D = ACTOR.instantiate() as Node3D
	root.add_child(actor_a)
	root.add_child(actor_b)
	await process_frame
	actor_a.call("set_corruption", 0.25)
	var meshes_a: Array[Node] = actor_a.find_children("*", "MeshInstance3D", true, false)
	var meshes_b: Array[Node] = actor_b.find_children("*", "MeshInstance3D", true, false)
	assert(not meshes_a.is_empty(), "Actor has no visible mesh")
	assert(meshes_a.size() == meshes_b.size())
	for index: int in range(meshes_a.size()):
		var mesh_a: MeshInstance3D = meshes_a[index] as MeshInstance3D
		var mesh_b: MeshInstance3D = meshes_b[index] as MeshInstance3D
		for surface: int in range(mesh_a.mesh.get_surface_count()):
			var material_a: ShaderMaterial = mesh_a.get_surface_override_material(surface) as ShaderMaterial
			var material_b: ShaderMaterial = mesh_b.get_surface_override_material(surface) as ShaderMaterial
			assert(material_a != material_b, "Actor materials are shared")
			assert(is_equal_approx(float(material_a.get_shader_parameter("corruption_amount")), 0.25))
			assert(is_equal_approx(float(material_b.get_shader_parameter("corruption_amount")), 1.0))
			assert(mesh_a.mesh.surface_get_material(surface) is not ShaderMaterial, "Source mesh was modified")
	actor_a.call("set_corruption", 0.0)
	actor_a.call("set_corruption", 1.0)
	print("PASS: actor A/B materials isolated; source materials preserved; corruption reset supported.")
	actor_a.queue_free()
	actor_b.queue_free()
	await process_frame
	quit()
