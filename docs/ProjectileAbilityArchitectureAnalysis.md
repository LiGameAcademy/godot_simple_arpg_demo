# 投射物技能架构分析

## 当前架构

### 三层职责分离

1. **ProjectileAbility（技能层）**
   - 职责：计算"怎么发"（数量、角度、枪口位置、散射）
   - 负责：实例化投射物、配置投射物、注入弹头（Effect）
   - 特点：知道发射的所有参数，适合处理复杂的发射逻辑

2. **ProjectileBase（载具层）**
   - 职责：负责"怎么飞"（直线、追踪、抛物线）
   - 负责：碰撞检测、穿透逻辑、生命周期管理
   - 特点：是 Node（Area3D），由场景树管理

3. **GameplayEffect（弹头层）**
   - 职责：负责"做什么"（伤害、治疗、状态施加）
   - 特点：是 Resource，不管理 Node 生命周期

## 为什么不在 Effect 中创建投射物？

### 1. 职责错位

**Effect 的职责**：
- 数值修改（扣血、加蓝、修改属性）
- 状态施加（眩晕、燃烧、加速）
- 逻辑执行（应用伤害、触发事件）

**Effect 不应该负责**：
- 创建和管理 Node（投射物是 Node）
- 处理物理和变换（位置、旋转、速度）
- 管理生命周期（何时创建、何时销毁）

### 2. 参数复杂性

投射物创建需要大量参数：
- `projectile_scene`: PackedScene
- `projectile_data`: ProjectileData（速度、生命周期、穿透等）
- `projectile_count`: int（多重施法）
- `spread_angle`: float（散射角度）
- `muzzle_attachment_point`: StringName（枪口挂点）
- `spawn_transform`: Transform3D（发射位置和朝向）

如果让 Effect 创建投射物，Effect 需要：
- 知道所有发射参数
- 知道如何计算枪口位置
- 知道如何计算发射方向
- 知道如何处理散射和多重施法

这会让 Effect 变得臃肿，违反单一职责原则。

### 3. 生命周期管理

- **Effect 是 Resource**：由资源系统管理，不管理 Node 生命周期
- **Projectile 是 Node**：由场景树管理，需要添加到场景树中

让 Resource 管理 Node 的生命周期，违背了 Godot 的设计模式。

### 4. 复用性问题

如果 Effect 创建投射物：
- 每个需要投射物的技能都需要一个专门的 Effect
- 无法复用投射物创建逻辑
- 无法在非技能场景中使用投射物（如陷阱、环境伤害）

当前架构的优势：
- 投射物创建逻辑集中在 `ProjectileAbility` 中，易于复用
- 可以在任何地方使用 `ProjectileAbility`（技能、陷阱、环境等）

## 特殊情况：状态系统中周期性发射投射物

如果需要在状态系统中周期性发射投射物（如"每 2 秒发射一颗火球"），有两种方案：

### 方案 1：通过状态系统触发技能（推荐）

在状态的效果中，使用 `GE_ExecuteAbility` 效果，周期性触发投射物技能：

```gdscript
# 状态效果：每 2 秒触发一次火球技能
# GE_ExecuteAbility.tres
- ability: fireball_ability
- skip_cost: true
- skip_cooldown: true
```

优点：
- 复用现有的投射物技能
- 保持架构一致性
- 不需要修改 Effect 系统

### 方案 2：创建专门的 Effect（不推荐）

创建一个 `GE_SpawnProjectile` 效果，在 Effect 中创建投射物。

缺点：
- 违反单一职责原则
- Effect 需要知道所有投射物参数
- 难以复用和维护

## 结论

**当前架构是合理的**，原因：

1. ✅ **职责清晰**：Ability 负责发射，Projectile 负责飞行，Effect 负责结果
2. ✅ **符合设计原则**：单一职责、开闭原则、依赖倒置
3. ✅ **符合 Godot 模式**：Resource 不管理 Node 生命周期
4. ✅ **易于扩展**：可以轻松添加新的投射物类型和效果
5. ✅ **易于复用**：投射物创建逻辑集中在 Ability 中

**不应该改为在 Effect 中创建投射物**，因为：

1. ❌ **职责错位**：Effect 应该负责"做什么"，不应该负责"怎么做"
2. ❌ **参数复杂**：Effect 需要知道太多发射参数
3. ❌ **生命周期管理**：Resource 不应该管理 Node 生命周期
4. ❌ **难以复用**：每个技能都需要专门的 Effect

## 最佳实践

1. **投射物创建**：始终在 `ProjectileAbility` 中创建
2. **效果应用**：投射物撞击时，将 Effect 应用给目标
3. **周期性发射**：通过状态系统触发技能，而不是在 Effect 中创建投射物
4. **复用性**：将投射物创建逻辑集中在 Ability 中，便于复用

