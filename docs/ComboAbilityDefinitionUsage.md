# 基于行为树的连击系统使用指南

## 📋 概述

`ComboAbilityDefinition` 是一个基于行为树（Behavior Tree）实现的连击技能系统。它使用 `BTSwitch` 节点根据连击索引选择执行对应的连击段，每段连击都是一个独立的 `ActiveAbilityDefinition`。

## 🏗️ 架构设计

### 核心组件

1. **ComboAbilityDefinition**
   - 继承自 `GameplayAbilityDefinition`
   - 管理多段连击的配置和执行流程
   - 使用行为树构建执行逻辑

2. **BTSwitch**
   - 根据黑板变量 `combo_index` 选择执行对应的子节点
   - 支持超时重置逻辑（通过 `combo_expiry_time`）

3. **AbilityNodeAdvanceCombo**
   - 推进连击索引
   - 设置连击窗口期
   - 处理终结技后的重置逻辑

4. **AbilityNodeSetComboIcon**
   - 更新 UI 显示的连击图标
   - 提示玩家下一段连击的样式

### 执行流程

```
玩家触发连击技能
    ↓
[Cost] 检查并消耗资源（魔法值、体力等）
    ↓
[Switch] 根据 combo_index 选择连击段
    ↓
[Sequence] 执行当前段的逻辑
    ├─ [执行段的能力树] (动画、目标搜索、效果应用等)
    ├─ [AdvanceCombo] 推进索引，设置窗口期
    └─ [SetComboIcon] 更新 UI 图标
    ↓
[Cooldown] 应用冷却时间
```

## 📝 使用步骤

### 1. 创建连击段能力

为每一段连击创建独立的 `ActiveAbilityDefinition` 资源：

**示例：三段连击**

- `attack_combo_1.tres` - 第一段（轻击）
  - `animation_name`: `"attack_1"`
  - `pre_cast_delay`: `0.1`
  - `post_cast_delay`: `0.3`
  - `effects`: `[GE_ApplyDamage]`
  - `targeting_strategy`: `UnitTargetingStrategy`

- `attack_combo_2.tres` - 第二段（重击）
  - `animation_name`: `"attack_2"`
  - `pre_cast_delay`: `0.15`
  - `post_cast_delay`: `0.4`
  - `effects`: `[GE_ApplyDamage]` (伤害倍数更高)
  - `targeting_strategy`: `UnitTargetingStrategy`

- `attack_combo_3.tres` - 第三段（终结技）
  - `animation_name`: `"attack_3"`
  - `pre_cast_delay`: `0.2`
  - `post_cast_delay`: `0.5`
  - `effects`: `[GE_ApplyDamage, GE_Knockback]`
  - `targeting_strategy`: `UnitTargetingStrategy`

### 2. 创建 ComboAbilityDefinition 资源

1. 右键点击项目资源
2. 选择 "新建资源" → "ComboAbilityDefinition"
3. 配置参数：

```gdscript
# 基础配置
ability_id: "combo_attack"
ability_name: "连击攻击"
description: "三段连击，每段伤害递增"

# 连击配置
combo_steps: [
    attack_combo_1.tres,
    attack_combo_2.tres,
    attack_combo_3.tres
]
window_duration: 0.8  # 连击窗口期（秒）

# 消耗和冷却
costs: [VitalCost(mana: 10)]  # 只在第一段消耗
cooldown_duration: 0.5  # 每段之间的冷却
```

### 3. 配置动画状态机

在 `AnimationTree` 的状态机中添加连击状态：

```
StateMachine
├─ Idle
├─ Movement
└─ Combat
   ├─ attack_1 (第一段)
   ├─ attack_2 (第二段)
   └─ attack_3 (第三段，终结技)
```

### 4. 添加到玩家数据

在 `PlayerData` 的 `initial_abilities` 中添加连击技能：

```gdscript
initial_abilities = [
    combo_attack.tres,
    # ... 其他技能
]
```

## 🔧 高级配置

### 自定义消耗策略

默认情况下，消耗在连击开始时应用（第一段）。如果你想只在第一段消耗，可以：

1. 移除根 Sequence 中的 `AbilityNodeCommitCost`
2. 在 `combo_steps[0]` 的 `execution_tree` 中添加 `AbilityNodeCommitCost`

### 自定义冷却策略

默认情况下，每段连击都会应用冷却。如果你想只在终结技后冷却：

1. 移除根 Sequence 中的 `AbilityNodeCommitCooldown`
2. 在最后一段的 `wrapper` 中添加 `AbilityNodeCommitCooldown`

### 自定义连击窗口期

每段连击可以有不同的窗口期：

```gdscript
# 在 _build_combo_tree() 中
for i in range(combo_steps.size()):
    var advance_node = AbilityNodeAdvanceCombo.new()
    # 第一段窗口期较长，后续段较短
    advance_node.reset_timer = 1.0 if i == 0 else 0.6
    advance_node.is_finisher = (i == combo_steps.size() - 1)
```

### 循环连击 vs 终结后停止

默认情况下，终结技后会重置到第一段（循环模式）。如果你想终结后停止：

```gdscript
# 在 AbilityNodeAdvanceCombo 中
if is_finisher:
    # 不重置索引，而是设置为 -1 或特殊值
    blackboard.set_var(combo_index_key, -1)
```

然后在 `BTSwitch` 中处理 `-1` 的情况，返回 `FAILURE`。

## 📊 黑板变量

连击系统使用以下黑板变量：

- `combo_index` (int): 当前连击索引（0, 1, 2, ...）
- `combo_expiry_time` (int): 连击窗口期截止时间（毫秒时间戳）
- `combo_next_icon` (Texture2D): 下一段连击的图标（供 UI 使用）

## 🎯 最佳实践

1. **窗口期设置**
   - 第一段：1.0 - 1.5 秒（给玩家反应时间）
   - 中间段：0.6 - 0.8 秒（保持节奏感）
   - 终结技：0.5 - 0.7 秒（快速收尾）

2. **动画时长**
   - 确保每段动画时长略长于窗口期，避免玩家按太快导致跳过
   - 使用 `post_cast_delay` 控制后摇，防止连击过快

3. **伤害递增**
   - 第一段：基础伤害
   - 第二段：基础伤害 × 1.2
   - 终结技：基础伤害 × 1.5

4. **UI 反馈**
   - 使用 `AbilityNodeSetComboIcon` 提示下一段连击
   - 在技能按钮上显示下一段的图标
   - 窗口期快结束时显示警告（如闪烁）

## 🐛 常见问题

### Q: 连击无法推进到下一段

**A:** 检查：
1. `window_duration` 是否设置正确
2. `BTSwitch` 的 `variable_key` 是否为 `"combo_index"`
3. `AbilityNodeAdvanceCombo` 是否正确执行

### Q: 连击窗口期不生效

**A:** 检查：
1. `BTSwitch` 的 `expiry_key` 是否为 `"combo_expiry_time"`
2. 时间戳计算是否正确（毫秒）

### Q: UI 图标不更新

**A:** 检查：
1. `AbilityNodeSetComboIcon` 是否正确执行
2. UI 是否监听 `ability_data_changed` 信号
3. 是否从黑板读取 `combo_next_icon`

## 📚 相关文档

- [行为树系统文档](./BehaviorTreeSystem.md)
- [ActiveAbilityDefinition 使用指南](./ActiveAbilityDefinitionUsage.md)
- [能力系统架构](./AbilitySystemArchitecture.md)

