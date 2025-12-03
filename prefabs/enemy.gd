extends CharacterBase
class_name Enemy

# 预留给掉落物的插槽 (稍后制作)
@export var loot_scene: PackedScene 

# 简单的生命值
var hp: int = 3

func _ready() -> void:
	super()
	hide()

func awaken() -> void:
	await get_tree().create_timer(randf_range(0.1, 0.5)).timeout
	show()
	animation_state_machine.travel("awaken")

# 公开接口：受到伤害
func take_damage(amount: int) -> void:
	hp -= amount
	print("骷髅受到伤害！剩余HP: ", hp)
	
	# 受击反馈 (简单的闪白或动画，这里省略)
	animation_state_machine.travel("hit")
	
	if hp <= 0:
		die()

func die() -> void:
	# 1. 生成掉落物 (稍后实现)
	spawn_loot()
	# 2. 销毁自身
	animation_state_machine.travel("death")

func spawn_loot() -> void:
	if not is_instance_valid(loot_scene):
		return
	var loot = loot_scene.instantiate()
	# 添加到当前场景 (不要加给怪物自己，因为怪物要死)
	get_parent().add_child(loot)
	loot.global_position = global_position + Vector3(0, 1, 0)
	
	# 给它一个随机的爆炸推力！
	var random_dir = Vector3(randf_range(-2, 2), 2, randf_range(-2, 2)).normalized()
	loot.apply_impulse(random_dir * 5.0)

## 获取动画树路径（重写基类方法）
func _get_animation_tree_path() -> NodePath:
	return NodePath("Skeleton_Warrior/AnimationTree")

## 组件初始化（重写基类方法）
func _init_components() -> void:
	super()
	
	attribute_component.initialize()
	var health_vital : HealthVital = attribute_component.get_vital("health")
	if is_instance_valid(health_vital):
		health_vital.damage_applied.connect(
			func(_damage_info : DamageInfo, _final_damage: float) -> void:
				_play_anim("hit")
		)
