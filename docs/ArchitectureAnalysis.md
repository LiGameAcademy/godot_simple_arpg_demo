# 投射物与魔法阵系统架构分析

## 当前架构概述

### 组件关系
```
ProjectileAbility (技能)
  ↓ 配置
ProjectileData (数据)
  ↓ 包含
MagicCircleAbility (魔法阵技能)
  ↓ 创建
MagicCircleBase (魔法阵实体)

ProjectileBase (投射物实体)
  ↓ 触发
MagicCircleAbility (通过 AbilityComponent)
```

## 问题分析

### ❌ 问题 1：职责混乱 - ProjectileBase 依赖技能系统

**当前实现**：
```gdscript
# ProjectileBase._trigger_aoe_ability()
var ability_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayAbilityComponent")
impact_aoe_ability._on_cast(ability_comp, null, aoe_context)
```

**问题**：
- `ProjectileBase` 应该只负责**飞行和碰撞检测**，不应该知道技能系统的存在
- 违反了**单一职责原则**：投射物需要获取 `AbilityComponent`，这是技能系统的职责
- 增加了耦合度：投射物系统依赖技能系统

**影响**：
- 如果未来需要在不使用技能系统的场景中使用投射物，会变得困难
- 测试投射物时需要模拟整个技能系统

---

### ❌ 问题 2：配置层级不合理 - ProjectileData 包含技能配置

**当前实现**：
```gdscript
# ProjectileData
@export var impact_aoe_ability: MagicCircleAbility = null
```

**问题**：
- `ProjectileData` 应该只关心**投射物本身的属性**（速度、生命周期、穿透等）
- 魔法阵的配置属于**技能层面的决策**，不应该在数据层
- 违反了**关注点分离**原则

**影响**：
- 多个技能共享同一个 `ProjectileData` 时，无法为每个技能配置不同的魔法阵
- 配置层级混乱：数据层包含了技能层的配置

---

### ❌ 问题 3：效果传递不清晰

**当前实现**：
- 投射物携带 `payload_effects`（单体伤害）
- 魔法阵技能有自己的 `target_effects`（范围伤害）
- 两者关系不明确

**问题**：
- 如果魔法阵技能没有配置效果，应该使用投射物的效果吗？
- 如果两者都配置了，是合并还是覆盖？
- 当前实现中，魔法阵技能的效果是独立的，投射物的效果不会传递给魔法阵

**影响**：
- 配置时容易混淆：需要在两个地方配置效果
- 无法灵活控制：比如"投射物造成 100 伤害，爆炸造成 50 范围伤害"

---

### ❌ 问题 4：触发机制绕过技能系统

**当前实现**：
```gdscript
# 直接调用 _on_cast，绕过冷却和消耗检查
impact_aoe_ability._on_cast(ability_comp, null, aoe_context)
```

**问题**：
- 虽然注释说明了这是"副作用"，但这种设计不够优雅
- 绕过了技能系统的正常流程（冷却、消耗、前摇等）
- 如果未来需要在魔法阵触发时也检查冷却，就需要修改代码

**影响**：
- 技能系统的完整性被破坏
- 无法利用技能系统的其他功能（如事件系统、状态检查等）

---

### ❌ 问题 5：命名不一致

**当前实现**：
- `impact_aoe_ability` - 变量名还是 "AoE"
- `trigger_aoe_on_timeout` - 注释和变量名不一致

**问题**：
- 已经改名为 `MagicCircleAbility`，但变量名和注释还在用 "AoE"
- 命名不一致会导致理解困难

---

### ⚠️ 问题 6：魔法阵技能无法独立使用

**当前设计**：
- `MagicCircleAbility` 主要通过 `ProjectileBase` 触发
- 虽然可以独立使用，但主要场景是作为投射物的副作用

**问题**：
- 如果玩家想直接施放魔法阵技能（不通过投射物），需要确保配置正确
- 当前设计更偏向"投射物的副作用"，而不是"独立的技能类型"

---

## 改进建议

### ✅ 建议 1：使用事件/信号系统解耦

**方案**：
```gdscript
# ProjectileBase
signal impact_triggered(hit_position: Vector3, direct_hit_target: Node, context: Dictionary)
signal timeout_triggered(position: Vector3, context: Dictionary)

# ProjectileAbility 监听信号
projectile_base.impact_triggered.connect(_on_projectile_impact)
projectile_base.timeout_triggered.connect(_on_projectile_timeout)
```

**优势**：
- `ProjectileBase` 不再依赖技能系统
- 通过信号解耦，符合 Godot 的设计理念
- 更容易测试和维护

---

### ✅ 建议 2：将魔法阵配置移到 ProjectileAbility

**方案**：
```gdscript
# ProjectileAbility
@export var impact_magic_circle_ability: MagicCircleAbility = null
@export var trigger_magic_circle_on_timeout: bool = false

# ProjectileData 只保留投射物本身的属性
```

**优势**：
- 配置层级清晰：技能层配置技能相关的内容
- 每个技能可以有不同的魔法阵配置
- `ProjectileData` 保持单一职责

---

### ✅ 建议 3：明确效果传递策略

**方案**：
```gdscript
# 选项 1：魔法阵技能使用投射物的效果（如果未配置）
if magic_circle_ability.target_effects.is_empty():
    magic_circle_ability.target_effects = payload_effects.duplicate(true)

# 选项 2：魔法阵技能总是使用自己的效果（当前实现）
# 选项 3：合并两者（需要明确合并规则）
```

**建议**：
- 在 `ProjectileAbility` 中明确效果传递策略
- 提供配置选项让用户选择

---

### ✅ 建议 4：通过 AbilityComponent 正常触发技能

**方案**：
```gdscript
# ProjectileAbility._on_projectile_impact()
if is_instance_valid(impact_magic_circle_ability):
    # 通过 AbilityComponent 正常触发，但可以设置标志跳过冷却/消耗
    ability_comp.apply_ability_effect(impact_magic_circle_ability.ability_id, null, context)
```

**优势**：
- 保持技能系统的完整性
- 可以利用技能系统的所有功能
- 如果需要，可以通过 context 标志跳过冷却/消耗

---

### ✅ 建议 5：统一命名

**方案**：
```gdscript
# 统一使用 MagicCircle 命名
var impact_magic_circle_ability: MagicCircleAbility = null
var trigger_magic_circle_on_timeout: bool = false
```

---

## 推荐的重构方案

### 架构调整

```
ProjectileAbility (技能)
  ├─ ProjectileData (投射物数据 - 只包含投射物属性)
  ├─ impact_magic_circle_ability (魔法阵技能配置)
  └─ trigger_magic_circle_on_timeout (超时触发标志)

ProjectileBase (投射物实体)
  ├─ 发射信号：impact_triggered
  └─ 发射信号：timeout_triggered

ProjectileAbility (监听信号)
  └─ 触发 MagicCircleAbility
```

### 关键改进点

1. **解耦**：`ProjectileBase` 通过信号通知，不再直接调用技能系统
2. **配置层级**：魔法阵配置在 `ProjectileAbility` 中，不在 `ProjectileData` 中
3. **效果传递**：在 `ProjectileAbility` 中明确处理效果传递逻辑
4. **触发机制**：通过 `AbilityComponent` 正常触发，保持系统完整性

---

## 总结

当前架构的主要问题：
1. ❌ **职责混乱**：投射物依赖技能系统
2. ❌ **配置层级不合理**：数据层包含技能配置
3. ❌ **效果传递不清晰**：两者关系不明确
4. ❌ **触发机制绕过系统**：直接调用内部方法
5. ❌ **命名不一致**：变量名和类名不匹配

建议优先解决：
1. **解耦**：使用信号系统，让 `ProjectileBase` 不再依赖技能系统
2. **配置层级**：将魔法阵配置移到 `ProjectileAbility`
3. **效果传递**：明确效果传递策略，提供配置选项

