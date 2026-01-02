extends Node3D

@onready var particles: GPUParticles3D = $FireParticles

func _ready() -> void:
	# 确保粒子系统正在发射
	if is_instance_valid(particles):
		particles.emitting = true

## 停止粒子发射（由 CueAttachedParticle 的 stop 方法调用）
func stop() -> void:
	if is_instance_valid(particles):
		particles.emitting = false
		# 等待粒子自然消散后销毁（可选）
		await get_tree().create_timer(particles.lifetime).timeout
		queue_free()
