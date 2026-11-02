# 冲刺状态架构说明

## 概述

在新三层架构下，持续位移效果（如冲刺、击退等）应该由 **Status 管理持续状态**，**Effect 只执行单次动作**。

## 架构对比

### 旧架构（异步 Effect）

```
Ability
  └─ GE_PhysicsMotion（异步效果）
      ├─ 自己管理 Tween
      ├─ 自己管理生命周期
      └─ 自己发出完成信号
```

**问题**：
- Effect 需要管理持续状态，职责过重
- 难以复用（每个持续效果都要自己实现生命周期管理）
- 不符合三层架构的设计理念

### 新架构（Status + 同步 Effect）

```
Ability
  └─ DashStatus（状态）
      ├─ duration: 0.3（持续时间）
      ├─ period: 0.05（周期，每 0.05 秒触发一次）
      └─ effects: [GE_SingleFrameMotion]
          └─ 只执行单次位移（同步完成）
```

**优势**：
- **Effect 职责单一**：只负责单次位移动作
- **Status 统一管理**：所有持续状态都由 Status 管理
- **更灵活**：可以通过 Status 的 `duration`、`period` 等配置控制
- **更易复用**：Effect 可以在不同 Status 中复用

## 配置示例

### 1. 创建单帧位移效果

**资源路径**：`data/effects/ge_dash_motion.tres`

```gdscript
[gd_resource type="Resource" script_class="GE_SingleFrameMotion"]

[resource]
script = ExtResource("...")
distance = 0.3  # 单次位移距离（米）
direction_type = 1  # INPUT（跟随输入方向）
ignore_gravity = false  # 贴合地面
```

**计算说明**：
- `distance = 0.3`：单次位移 0.3 米
- `period = 0.05`：每 0.05 秒触发一次
- `duration = 0.3`：总持续时间 0.3 秒
- **总位移距离** = `0.3 * (0.3 / 0.05)` = `0.3 * 6` = `1.8` 米

### 2. 创建冲刺状态

**资源路径**：`data/status/dash_status.tres`

```gdscript
[gd_resource type="Resource" script_class="GameplayStatusData"]

[resource]
script = ExtResource("...")
status_id = &"dash"
status_display_name = "冲刺"
duration = 0.3  # 持续时间 0.3 秒
period = 0.05  # 每 0.05 秒触发一次位移
effects = [ExtResource("ge_dash_motion")]  # 单帧位移效果
target_mode = 0  # SELF（应用到自己）
```

### 3. 创建冲刺技能

**资源路径**：`data/abilities/dash.tres`

```gdscript
[gd_resource type="Resource" script_class="ActiveAbility"]

[resource]
script = ExtResource("...")
ability_id = &"dash"
ability_name = "冲刺"
statuses = [ExtResource("dash_status")]  # 应用冲刺状态
```

## 工作流程

```
玩家按下冲刺键
    ↓
ActiveAbility._on_cast()
    ↓
ActiveAbility._apply_status()
    ↓
GameplayStatusComponent.apply_status()
    ↓
GameplayStatusInstance.apply()
    ├─ 立即应用一次效果（GE_SingleFrameMotion）
    └─ 创建周期性计时器（period = 0.05）
        ↓
    每 0.05 秒触发一次
        ↓
    GameplayStatusInstance._on_periodic_effect()
        ↓
    应用 GE_SingleFrameMotion（单次位移）
        ↓
    0.3 秒后，Status 自动移除
        ↓
    GameplayStatusInstance.remove()
        ↓
    status_completed.emit()
        ↓
    Ability.ability_completed.emit()
```

## 方向锁定

### 问题
周期性效果每帧都会重新计算方向，可能导致方向不一致。

### 解决方案

**方案 1：在 Status 应用时锁定方向**

在 `ActiveAbility._apply_status()` 中，将方向添加到 context：

```gdscript
func _apply_status(instigator: Node, status_data: GameplayStatusData, context: Dictionary) -> void:
    # 计算并锁定方向
    if status_data.status_id == &"dash":
        var dash_direction = _calculate_dash_direction(instigator, context)
        context["direction"] = dash_direction
        context["direction_type"] = GE_SingleFrameMotion.DirectionType.CUSTOM
    
    status_comp.apply_status(status_data, instigator, 1, context)
```

**方案 2：Effect 缓存方向**

`GE_SingleFrameMotion` 已经实现了方向缓存：
- `INPUT` 类型：每帧重新计算（因为输入可能改变）
- 其他类型：首次计算后缓存，后续使用缓存的方向

## 性能考虑

### 周期选择

- **period = 0.05**（20 FPS）：适合大多数情况，平衡性能和流畅度
- **period = 0.033**（30 FPS）：更流畅，但性能开销更大
- **period = 0.1**（10 FPS）：性能更好，但可能不够流畅

### 距离计算

单次位移距离应该根据 `period` 和期望的总距离计算：

```
单次距离 = 总距离 / (持续时间 / 周期)
例如：总距离 6 米，持续时间 0.3 秒，周期 0.05 秒
     单次距离 = 6 / (0.3 / 0.05) = 6 / 6 = 1.0 米
```

## 迁移指南

### 从 GE_PhysicsMotion 迁移

1. **创建 GE_SingleFrameMotion 资源**
   - 设置 `distance`（根据总距离和周期计算）
   - 设置 `direction_type`
   - 设置 `ignore_gravity`

2. **创建 Status 资源**
   - 设置 `duration`（原 GE_PhysicsMotion 的 duration）
   - 设置 `period`（建议 0.05）
   - 添加 GE_SingleFrameMotion 到 `effects`

3. **更新 Ability 资源**
   - 移除旧的 `GE_PhysicsMotion`
   - 添加新的 Status 到 `statuses`

## 总结

新架构的核心思想：
- **Ability**：触发技能
- **Status**：管理持续状态（duration、period、生命周期）
- **Effect**：执行单次动作（同步完成）

这样的设计更符合单一职责原则，也更易于维护和扩展。

