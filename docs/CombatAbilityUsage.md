# 连击系统使用指南

## 概述

`CombatAbility` 是一个支持多段连击的技能系统，每次触发时根据当前连击索引执行对应的能力。系统会自动管理连击进度和重置逻辑。

## 核心概念

### CombatAbility

`CombatAbility` 继承自 `ActiveAbility`，包含：
- **连击段数数组**：`combo_abilities`，每段对应一个 `ActiveAbility`
- **连击索引**：`_current_combo_index`，当前执行到第几段
- **重置时间**：`combo_reset_time`，超时后重置到第一段

### 工作流程

```
玩家按下攻击键
    ↓
CombatAbility._can_cast() → 检查当前段是否可以施放
    ↓
CombatAbility._commit_cast() → 提交当前段的施法
    ↓
CombatAbility._on_cast() → 执行当前段的能力
    ↓
播放对应动画（根据 combo_index）
    ↓
动画关键帧触发效果
    ↓
CombatAbility.on_combo_complete() → 推进到下一段
    ↓
等待下一次输入或超时重置
```

## 使用方法

### 1. 创建连击段能力

为每一段连击创建独立的 `ActiveAbility` 资源：

**示例：三段连击**
- `attack_combo_1.tres` - 第一段（轻击）
- `attack_combo_2.tres` - 第二段（重击）
- `attack_combo_3.tres` - 第三段（终结技）

每个能力需要配置：
- `animation_name`：对应的动画名称（如 `"attack_1"`, `"attack_2"`, `"jump_chop"`）
- `effects`：该段的伤害效果
- `hit_detector`：该段的命中检测器

### 2. 创建 CombatAbility 资源

1. 右键点击项目资源
2. 选择 "新建资源" → "CombatAbility"
3. 配置：
   - `ability_id`: `"combo_attack"`
   - `ability_name`: `"连击攻击"`
   - `combo_abilities`: 添加三段能力 `[attack_combo_1, attack_combo_2, attack_combo_3]`
   - `combo_reset_time`: `1.5`（1.5 秒内未继续连击则重置）

### 3. 配置动画状态机

在 `AnimationTree` 的状态机中添加连击状态：

**状态结构**：
```
StateMachine
├─ Idle
├─ Movement
└─ Combat
   ├─ attack_1 (第一段)
   ├─ attack_2 (第二段)
   └─ jump_chop (第三段，跳跃斩击)
```

**状态转换**：
- `attack_1` → `attack_2`（条件：在连击窗口内）
- `attack_2` → `jump_chop`（条件：在连击窗口内）
- 任何状态 → `Idle`（条件：动画完成且超时）

**参数设置**：
- 添加 `combo_index` 参数（int），用于选择当前连击段
- 添加 `can_combo` 参数（bool），用于判断是否可以继续连击

### 4. 在代码中使用

```gdscript
# 获取能力组件
var ability_comp = character.get_ability_component()

# 尝试施放连击（会自动根据当前索引选择段数）
ability_comp.try_cast_ability("combo_attack")

# 检查当前连击进度
var combat_ability = ability_comp.get_ability_data("combo_attack") as CombatAbility
if is_instance_valid(combat_ability):
    var current_index = combat_ability.get_current_combo_index()
    var max_count = combat_ability.get_max_combo_count()
    print("当前连击: %d/%d" % [current_index + 1, max_count])
```

## 动画状态机配置

### 示例：三段连击状态机

```
Combat State Machine
├─ attack_1
│  ├─ Animation: "attack_1"
│  ├─ Transition to attack_2: can_combo && combo_index == 1
│  └─ Transition to Idle: animation_finished && !can_combo
├─ attack_2
│  ├─ Animation: "attack_2"
│  ├─ Transition to jump_chop: can_combo && combo_index == 2
│  └─ Transition to Idle: animation_finished && !can_combo
└─ jump_chop
   ├─ Animation: "jump_chop"
   └─ Transition to Idle: animation_finished
```

### 在 VisualAdapter 中设置参数

```gdscript
# 在 AnimationTreeVisualAdapter 中
func _on_ability_cast(ability_id: StringName) -> void:
    # ... 现有代码 ...
    
    if ability_data is CombatAbility:
        var combat_ability = ability_data as CombatAbility
        var combo_index = combat_ability.get_current_combo_index()
        
        # 设置动画树参数
        set_blend_parameter("combo_index", combo_index)
        set_blend_parameter("can_combo", combat_ability.can_continue_combo())
        
        # 播放对应动画
        var anim_name = combat_ability.get_animation_name()
        _play_animation(anim_name)
```

## API 参考

### CombatAbility

```gdscript
## 获取当前连击段数（0-based）
func get_current_combo_index() -> int

## 获取最大连击段数
func get_max_combo_count() -> int

## 获取当前连击对应的能力
func get_current_combo_ability() -> ActiveAbility

## 重置连击到第一段
func reset_combo() -> void

## 推进到下一段连击
func advance_combo() -> void

## 更新连击计时器（需要在 _process 中调用）
func update_combo_timer(delta: float) -> void

## 检查是否可以继续连击
func can_continue_combo() -> bool

## 通知连击完成（由动画事件调用）
func on_combo_complete() -> void
```

## 配置示例

### 示例 1：三段连击

**CombatAbility 配置**：
```gdscript
CombatAbility:
  ability_id: "combo_attack"
  combo_abilities: [
    attack_combo_1,  # 第一段：轻击
    attack_combo_2,  # 第二段：重击
    attack_combo_3   # 第三段：跳跃斩击
  ]
  combo_reset_time: 1.5
```

**动画配置**：
- 第一段：`attack_1` 动画
- 第二段：`attack_2` 动画
- 第三段：`jump_chop` 动画

### 示例 2：五段连击

**CombatAbility 配置**：
```gdscript
CombatAbility:
  ability_id: "advanced_combo"
  combo_abilities: [
    combo_1, combo_2, combo_3, combo_4, combo_5
  ]
  combo_reset_time: 2.0  # 更长的连击窗口
```

## 最佳实践

### 1. 连击窗口时间

- **短连击**（2-3 段）：`1.0 - 1.5` 秒
- **中等连击**（4-5 段）：`1.5 - 2.0` 秒
- **长连击**（6+ 段）：`2.0 - 3.0` 秒

### 2. 动画时长

确保每段动画的时长合理：
- 第一段：快速（0.3-0.5 秒）
- 中间段：中等（0.5-0.8 秒）
- 最后段：稍慢（0.8-1.2 秒），有终结感

### 3. 伤害递增

建议每段伤害递增：
- 第一段：100% 基础伤害
- 第二段：120% 基础伤害
- 第三段：150% 基础伤害

### 4. 视觉效果

- 每段使用不同的特效
- 最后一段使用更华丽的特效
- 使用 `GameplayCue` 系统区分不同段的视觉反馈

## 常见问题

### Q: 如何让连击在特定条件下重置？

**A**: 可以在外部调用 `reset_combo()`：
```gdscript
# 例如：受到伤害时重置连击
func on_damage_taken():
    var combat_ability = get_ability_data("combo_attack") as CombatAbility
    if is_instance_valid(combat_ability):
        combat_ability.reset_combo()
```

### Q: 如何实现无限连击？

**A**: 在 `advance_combo()` 中不重置索引：
```gdscript
func advance_combo() -> void:
    _current_combo_index += 1
    if _current_combo_index >= combo_abilities.size():
        _current_combo_index = 0  # 循环回到第一段
```

### Q: 如何让某些段可以跳过？

**A**: 可以在 `_can_cast()` 中检查条件，或者使用不同的 `CombatAbility` 配置不同的连击路径。

### Q: 动画状态机如何知道当前是第几段？

**A**: 通过 `set_blend_parameter("combo_index", combo_index)` 设置参数，状态机根据此参数选择状态。

## 完成！

现在你的连击系统已就绪！🎉

