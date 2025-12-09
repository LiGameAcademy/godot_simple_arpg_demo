# TargetingType 枚举通用性分析

## 📋 当前实现问题

### 1. **职责混合**
当前 `TargetingType` 枚举混合了多个维度的概念：
- **目标类型**：自己、单位、地面、无
- **目标数量**：单个、多个（未明确支持）
- **目标关系**：友军、敌军、任意（未明确支持）
- **目标获取方式**：指定、自动、范围（部分由 `hit_detector` 处理）

### 2. **扩展性差**
无法优雅地支持复杂场景：
- ❌ 多目标技能（如"对周围所有敌人"）
- ❌ 区域目标（如"圆形区域"、"矩形区域"、"扇形区域"）
- ❌ 链式目标（如"闪电链"、"弹射"）
- ❌ 方向性技能（如"向前方扇形区域"）
- ❌ 组合目标（如"对目标及其周围敌人"）

### 3. **与现有架构不一致**
系统已经采用了策略模式：
- `HitDetectorBase` - 处理目标检测
- `TargetingScorer` - 处理目标选择
- 但 `TargetingType` 仍然作为硬编码的枚举存在

## 🎯 更好的抽象方案

### 方案 A：完全策略化（推荐）

**核心思想**：将目标获取逻辑完全抽象为 `TargetingStrategy` 接口，移除枚举。

#### 优势：
1. **完全解耦**：框架层只定义接口，不限制具体实现
2. **无限扩展**：业务层可以实现任意复杂的目标获取策略
3. **组合灵活**：可以组合多个策略（如"先检测范围，再评分选择"）
4. **职责清晰**：每个策略类只负责一种目标获取方式

#### 实现结构：
```gdscript
# 框架层：抽象接口
@abstract
extends Resource
class_name TargetingStrategy

func resolve_targets(instigator: Node, input_target: Node, context: Dictionary) -> Array[Node]:
    return _resolve_targets(instigator, input_target, context)

@abstract
func _resolve_targets(instigator: Node, input_target: Node, context: Dictionary) -> Array[Node]

# 业务层：具体实现
# - SelfTargetingStrategy（自己）
# - UnitTargetingStrategy（指定单位）
# - GroundTargetingStrategy（地面位置）
# - NoTargetingStrategy（无目标）
# - AreaTargetingStrategy（区域范围）
# - ChainTargetingStrategy（链式目标）
# - DirectionalTargetingStrategy（方向性）
```

### 方案 B：保留枚举 + 策略组合（折中）

**核心思想**：保留枚举作为"快速配置"，但允许用策略覆盖。

#### 优势：
1. **向后兼容**：现有代码无需大改
2. **简单场景快速配置**：枚举值足够用
3. **复杂场景灵活扩展**：用策略覆盖

#### 实现结构：
```gdscript
# 框架层：枚举 + 策略接口
enum TargetingType {
    SELF_ONLY,
    UNIT_TARGET,
    GROUND_TARGET,
    NO_TARGET
}

@export var targeting_type: TargetingType = TargetingType.UNIT_TARGET
@export var targeting_strategy: TargetingStrategy = null  # 可选，覆盖枚举

# 使用时：优先使用策略，否则回退到枚举
func _resolve_targets(...):
    if targeting_strategy:
        return targeting_strategy.resolve_targets(...)
    else:
        return _resolve_targets_by_enum(...)
```

## 📊 对比分析

| 维度 | 当前枚举 | 方案A（完全策略化） | 方案B（枚举+策略） |
|------|---------|-------------------|------------------|
| **通用性** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **扩展性** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **易用性** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **向后兼容** | ✅ | ❌ | ✅ |
| **代码复杂度** | 低 | 中 | 中 |
| **教学友好度** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

## 💡 推荐方案

**对于框架层**：推荐 **方案A（完全策略化）**

**理由**：
1. 框架层应该提供**最大灵活性**，而不是预设限制
2. 策略模式是成熟的架构模式，符合"开闭原则"
3. 与现有的 `HitDetectorBase`、`TargetingScorer` 架构一致
4. 虽然需要更多代码，但提供了**无限扩展能力**

**对于业务层**：可以提供**便捷的预设策略类**，简化常见场景的配置。

## ✅ 实施结果

### 已实现

1. **创建 TargetingStrategy 基类**
   - 位置：`addons/godot_gameplay_abilities/scripts/data/targeting/targeting_strategy.gd`
   - 提供抽象接口，框架层不限制具体实现

2. **实现4个预设策略类**
   - `SelfTargetingStrategy` - 自身目标
   - `UnitTargetingStrategy` - 单位目标
   - `GroundTargetingStrategy` - 地面目标
   - `NoTargetingStrategy` - 无目标

3. **重构 ActiveAbility**
   - 添加 `targeting_strategy` 字段（推荐）
   - 保留 `targeting_type` 枚举（向后兼容，已标记为已弃用）
   - 优先使用策略，回退到枚举

4. **文档完善**
   - 分析文档：`docs/TargetingTypeAnalysis.md`
   - 使用指南：`docs/TargetingStrategyUsage.md`

### 优势总结

✅ **通用性提升**：从4个枚举值扩展到无限可能  
✅ **扩展性提升**：支持自定义策略，无需修改框架代码  
✅ **架构一致性**：与 `HitDetectorBase`、`TargetingScorer` 保持一致  
✅ **向后兼容**：保留枚举，现有代码无需立即迁移  
✅ **教学友好**：提供预设策略，简化常见场景配置

