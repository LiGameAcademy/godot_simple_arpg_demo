extends Node3D

# 爆炸总持续时间（秒），需要比最长的粒子寿命稍长一点
@export var total_lifetime: float = 3.0
@onready var anim_conductor: AnimationPlayer = $AnimConductor

func _ready() -> void:
	# 先等一帧，确保节点和材质初始化完成
	await get_tree().process_frame
	
	# 启动动画指挥家（如果有需要控制灯光变化）
	if anim_conductor.has_animation("explode"):
		anim_conductor.play("explode")
	
	await anim_conductor.animation_finished
	get_parent().queue_free()
