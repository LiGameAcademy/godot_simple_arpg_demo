# 魔法场架构设计文档（方案三：Actor 作为传感器，Status 作为大脑）

## 核心思想

对于复杂的复合需求（如"每1秒对范围内的随机5个敌人造成伤害"），我们采用**职责分离**的架构：

- **MagicFieldBase (Actor/传感器)**：负责物理世界的"谁在我里面"，利用 Area3D 的事件驱动机制高效维护目标列表
- **Status (大脑)**：负责计时（Tick）和决策（Trigger Effect），挂在施法者身上
- **Effect (执行者)**：负责具体的伤害计算和应用

## 架构流程

### 1. 配置阶段

```
Ability 配置：
- magic_field_data: MagicFieldData
  - magic_field_scene: DamageField.tscn
  - duration: 10.0
  - periodic_target_selection_mode: RANDOM
  - periodic_target_count: 5
- statuses: [Status_FieldDamage]
  - period: 1.0（每秒触发一次）
  - periodic_effects: [GE_ApplyDamage]
    - damage: 100
```

### 2. 施法阶段（Ability 职责）

1. Ability 在指定位置实例化 `MagicFieldBase`
2. Ability 给**施法者自己**应用 Status，并将魔法场引用作为 context 传递给 Status
3. 魔法场开始维护目标列表（通过 `body_entered`/`body_exited` 事件）

### 3. 运行阶段（Actor 职责）

- `MagicFieldBase` 静静地待在那里
- 它的 `Area3D` 利用引擎高效的物理事件，实时维护 `_current_targets` 列表
- 有目标进入就加进去，离开就移除（比每秒主动查询高效得多）

### 4. 触发阶段（Status + MagicField 职责）

1. 施法者身上的 Status 每秒 Tick 一次（由 Status 的 `period` 控制）
2. Status 检测到 context 中有 `field` 引用，调用 `magic_field.apply_periodic_effects()`
3. MagicField 根据配置（`periodic_target_selection_mode`、`periodic_target_count`）选择目标
4. MagicField 对每个选中的目标应用 `periodic_effects`（如 `GE_ApplyDamage`）

## 代码示例

### 配置示例：每1秒对范围内随机5个敌人造成100点物理伤害

```gdscript
# MagicFieldData 配置（DamageFieldData.tres）
- magic_field_scene: DamageField.tscn
- duration: 10.0
- periodic_target_selection_mode: RANDOM
- periodic_target_count: 5

# Status 配置（Status_FieldDamage.tres）
- status_id: "field_damage"
- duration: 10.0  # 持续10秒
- period: 1.0     # 每秒触发一次
- periodic_effects: [GE_ApplyDamage]
  - damage: 100
  - damage_type: PHYSICAL

# Ability 配置（MagicFieldAbility）
- magic_field_data: DamageFieldData
- statuses: [Status_FieldDamage]
```

### 运行时流程

```gdscript
# 1. Ability 施法
MagicFieldAbility._on_cast():
  - 生成 MagicFieldBase
  - 应用 Status 到 instigator，传递 field 引用

# 2. MagicFieldBase 维护目标列表
MagicFieldBase._on_body_entered():
  - 添加目标到 _current_targets

# 3. Status 周期性触发
GameplayStatusInstance._on_periodic_effect():
  - 检测到 context["field"] 存在
  - 调用 magic_field.apply_periodic_effects(periodic_effects, instigator, context)
  - MagicFieldBase.apply_periodic_effects():
    - 根据配置选择目标（get_random_targets(5)）
    - 对每个目标应用 periodic_effects（GE_ApplyDamage）
```

## 架构优势

### 1. 职责完美分离

- **Actor (传感器)**：利用物理引擎事件高效维护目标列表
- **Status (大脑)**：负责计时、状态检查（如施法者被晕则停止 Tick）和逻辑分发
- **Effect (执行者)**：负责扣血

### 2. 高性能

- 避免了每秒主动进行昂贵的物理查询
- 利用了引擎底层的碰撞回调（`body_entered`/`body_exited`）
- 目标列表维护是事件驱动的，O(1) 复杂度

### 3. 高内聚

- 所有的游戏逻辑配置（周期、伤害量、挑选数量）都在 GAS 的数据资源里
- 不在分散的场景脚本里
- 易于调试和维护

### 4. 健壮性

- 如果魔法场 Actor 被提前销毁了，Status 在 Tick 时引用检查失效，优雅停止即可，不会崩溃
- Status 可以检查施法者状态（如被沉默、被眩晕），决定是否继续 Tick

## MagicFieldBase 传感器接口

### get_all_targets() -> Array[Node]

获取当前区域内的所有目标。

### get_random_targets(count: int = -1) -> Array[Node]

获取随机目标。
- `count < 0`：返回所有目标
- `count >= 总数`：返回所有目标
- 否则：返回随机选择的 `count` 个目标

### get_nearest_targets(count: int = -1) -> Array[Node]

获取最近的目标（按距离排序）。
- `count < 0`：返回所有目标（按距离排序）
- `count >= 总数`：返回所有目标
- 否则：返回最近的 `count` 个目标

## MagicFieldData 周期性效果配置

### periodic_target_selection_mode

周期性效果的目标选择模式：
- `RANDOM`：随机选择
- `NEAREST`：最近的优先
- `ALL`：所有目标

### periodic_target_count

周期性效果的目标数量（仅在 `RANDOM` 和 `NEAREST` 模式下有效）。
- `-1`：全部
- `> 0`：指定数量

### Status 的 periodic_effects

Status 的 `periodic_effects` 列表，会对每个选中的目标应用。

## 使用场景

### 场景1：每1秒对范围内随机5个敌人造成伤害

```gdscript
Status:
  - period: 1.0
  - periodic_effects: [GE_ApplyToFieldTargets]
    - selection_mode: RANDOM
    - target_count: 5
    - sub_effects: [GE_ApplyDamage]
```

### 场景2：每2秒对范围内所有友军进行治疗

```gdscript
Status:
  - period: 2.0
  - periodic_effects: [GE_ApplyToFieldTargets]
    - selection_mode: ALL
    - sub_effects: [GE_ApplyHealing]
```

### 场景3：每0.5秒对范围内最近3个敌人施加减速

```gdscript
Status:
  - period: 0.5
  - periodic_effects: [GE_ApplyToFieldTargets]
    - selection_mode: NEAREST
    - target_count: 3
    - sub_effects: [GE_ApplyStatus]
      - status_data: SlowStatus
```

## 总结

方案三完美地融合了物理世界（Actor）和逻辑世界（Status/Effect）的优势：

- **物理的归物理**：Actor 利用引擎事件高效维护目标列表
- **逻辑的归逻辑**：Status 负责计时和决策，Effect 负责执行

这种架构保持了系统的清晰性和可扩展性，能够应对未来更复杂的技能需求。

