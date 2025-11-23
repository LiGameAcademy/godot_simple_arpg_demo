extends CharacterBody3D

@onready var animation_tree: AnimationTree = $Skeleton_Warrior/AnimationTree

# 预留给掉落物的插槽 (稍后制作)
@export var loot_scene: PackedScene 
@export var enemy_id: String = "skeleton"

# 简单的生命值
var hp: int = 3
var animation_state_machine : AnimationNodeStateMachinePlayback

func _ready() -> void:
	animation_state_machine = animation_tree.get("parameters/StateMachine/playback")
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
	GameState.emit_game_event("enemy_died", {"id": enemy_id})

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
