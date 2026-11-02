extends Node
## 回归验证：持续播放多个周期后仍有骨骼变化，攻击能返回循环移动状态。
const PLAYER: PackedScene = preload("res://prefabs/player.tscn")
const PlayerActor = preload("res://prefabs/player.gd")
var _player: PlayerActor
var _skeleton: Skeleton3D

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    _player = PLAYER.instantiate() as PlayerActor
    add_child(_player)
    _player.set_physics_process(false)
    _skeleton = _player.get_node("Visuals/Barbarian/Rig_Medium/Skeleton3D") as Skeleton3D
    var animations: AnimationPlayer = _player.get_node("Visuals/Barbarian/AnimationPlayer") as AnimationPlayer
    for animation_name: StringName in [&"Idle_B", &"Walking_B", &"Running_B"]:
        assert(animations.get_animation("hero/" + animation_name).loop_mode == Animation.LOOP_LINEAR)
    var attack: Animation = animations.get_animation("hero/Melee_1H_Attack_Chop")
    assert(attack.loop_mode == Animation.LOOP_NONE)
    assert(attack.find_track(NodePath("../SwordHitbox:monitoring"), Animation.TYPE_VALUE) >= 0, "Attack lost its hitbox track")
    await _verify_loop(0.0, "idle")
    await _verify_loop(2.0, "walk")
    await _verify_loop(5.0, "run")
    _player.animation_state_machine.travel(&"attack")
    var attack_seen: bool = false
    for frame_index: int in range(90):
        await get_tree().physics_frame
        attack_seen = attack_seen or _player.animation_state_machine.get_current_node() == &"attack"
    assert(attack_seen, "Attack never started")
    assert(_player.animation_state_machine.get_current_node() == &"movement", "Attack did not return to movement")
    await _verify_loop(5.0, "run after attack")
    _player.queue_free()
    await get_tree().process_frame
    print("PASS: idle/walk/run keep animating beyond clip end; attack returns to looping movement")
    get_tree().quit()

func _verify_loop(speed: float, label: String) -> void:
    _player.animation_tree.set("parameters/StateMachine/movement/blend_position", speed)
    # 等待超过最慢待机片段的两个周期，不能只验证启动时播放过一遍。
    for frame_index: int in range(300):
        await get_tree().physics_frame
    var before: Array[Quaternion] = _sample_pose()
    var changed: bool = false
    for frame_index: int in range(30):
        await get_tree().physics_frame
        var after: Array[Quaternion] = _sample_pose()
        for bone_index: int in range(before.size()):
            changed = changed or before[bone_index].angle_to(after[bone_index]) > 0.01
    assert(changed, label + " froze after its first cycle")
    print("PASS: ", label, " bone poses continue changing")

func _sample_pose() -> Array[Quaternion]:
    var rotations: Array[Quaternion] = []
    for bone_index: int in range(_skeleton.get_bone_count()):
        rotations.append(_skeleton.get_bone_pose_rotation(bone_index))
    return rotations
