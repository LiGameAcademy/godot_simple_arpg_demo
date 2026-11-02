# 框架层设计原则

## 📋 核心原则

**框架层应该只包含通用的、可扩展的接口，不应该包含业务特定的逻辑。**

## 🎯 为什么 `is_ranged()` 不应该在框架层？

### 问题分析

1. **"远程技能"是业务概念**：
   - 不同游戏对"远程"的定义不同：
     - 有些游戏认为"需要鼠标指向"就是远程
     - 有些游戏认为"有投射物"才是远程
     - 有些游戏认为"超出近战范围"才是远程
     - 有些游戏可能不需要这个概念

2. **框架层的职责**：
   - 提供通用的、可扩展的接口
   - 不应该包含业务特定的逻辑
   - 应该支持多种业务场景，而不是硬编码某种业务逻辑

3. **扩展性问题**：
   - 如果框架层包含 `is_ranged()`，那么未来可能需要 `is_melee()`、`is_aoe()`、`is_channeled()` 等
   - 这些方法会不断膨胀，违反"开闭原则"
   - 不同游戏的需求不同，无法用一套方法覆盖所有场景

## ✅ 正确的设计

### 方案1：使用技能标签系统（推荐）

```gdscript
# 在技能资源中配置标签
@export var tags: Array[StringName] = ["ranged", "projectile"]

# 业务层判断
func is_ranged_ability(ability: GameplayAbility) -> bool:
    return ability.tags.has(&"ranged")
```

**优势**：
- ✅ 完全灵活，可以定义任意标签
- ✅ 不污染框架层
- ✅ 易于扩展和维护

### 方案2：业务层基于策略类型判断

```gdscript
# 业务层判断
func is_ranged_ability(ability: GameplayAbility) -> bool:
    if ability is ActiveAbility:
        var active_ability = ability as ActiveAbility
        if is_instance_valid(active_ability.targeting_strategy):
            # 根据策略类型判断
            var strategy = active_ability.targeting_strategy
            if strategy is UnitTargetingStrategy or strategy is GroundTargetingStrategy:
                return true
    return false
```

**优势**：
- ✅ 不需要修改技能资源
- ✅ 基于框架层已有的类型信息
- ✅ 业务层可以自定义判断逻辑

### 方案3：在业务层添加属性（可选）

```gdscript
# 在 ActiveAbility 中添加业务层属性
@export_group("Business Logic")
@export var requires_mouse_targeting: bool = false  # 业务层属性
```

**优势**：
- ✅ 明确标记业务逻辑
- ✅ 易于理解和配置
- ⚠️ 但会污染框架层，不推荐

## 📊 对比

| 方案 | 框架层污染 | 灵活性 | 易用性 | 推荐度 |
|------|-----------|--------|--------|--------|
| 技能标签 | ❌ 无污染 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 策略类型判断 | ❌ 无污染 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 业务层属性 | ⚠️ 轻微污染 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

## 💡 最佳实践

1. **优先使用标签系统**：
   - 标签系统已经存在于 `GameplayAbility` 中
   - 可以定义任意业务标签，如 `"ranged"`、`"melee"`、`"aoe"`、`"channeled"` 等
   - 完全灵活，不污染框架层

2. **业务层实现判断逻辑**：
   - 将业务特定的判断逻辑放在业务层（如 `player.gd`）
   - 框架层只提供数据（标签、策略类型等），不提供判断方法

3. **保持框架层纯净**：
   - 框架层应该只包含通用的、可扩展的接口
   - 业务特定的逻辑应该由业务层实现

## 🔄 重构历史

### 之前的设计（错误）
```gdscript
# 框架层
class TargetingStrategy:
    func is_ranged() -> bool:  # ❌ 业务逻辑不应该在框架层
        return _is_ranged()
```

### 现在的设计（正确）
```gdscript
# 框架层：只提供数据
class TargetingStrategy:
    func resolve_targets(...) -> Array[Node]:  # ✅ 通用接口
        ...

# 业务层：实现判断逻辑
func is_ranged_ability(ability: GameplayAbility) -> bool:
    # 方案1: 通过标签判断
    if ability.tags.has(&"ranged"):
        return true
    
    # 方案2: 通过策略类型判断
    if ability is ActiveAbility:
        var strategy = active_ability.targeting_strategy
        if strategy is UnitTargetingStrategy:
            return true
    
    return false
```

## 📚 相关文档

- [TargetingStrategy 使用指南](./TargetingStrategyUsage.md)
- [TargetingType 分析文档](./TargetingTypeAnalysis.md)

