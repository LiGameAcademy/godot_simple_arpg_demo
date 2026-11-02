# 📊 状态系统重构建议

**评估日期**: 2024
**评估范围**: `GameplayStatusComponent`, `GameplayStatusData`, `GameplayStatusInstance`

---

## 1. 当前实现分析

### 1.1 架构概览

```
GameplayStatusComponent (Node)
  └─ 管理多个 GameplayStatusInstance
      └─ 每个实例对应一个 GameplayStatusData
          └─ 包含多个 GameplayEffect
```

### 1.2 核心组件

- **GameplayStatusComponent**: 状态容器，管理所有激活的状态
- **GameplayStatusData**: 状态定义（资源），配置状态的所有属性
- **GameplayStatusInstance**: 状态实例，管理单个状态的生命周期

---

## 2. 发现的问题

### 🔴 严重问题

#### 2.1 状态型效果判断逻辑错误

**位置**: `GameplayStatusInstance._apply_all_stateful_effects()`

**问题**:
```gdscript
# 检查是否是状态型效果（不是周期性，不是事件监听型）
if status_data.period > 0.0 or status_data.event_to_listen != &"":
    return  # 直接返回，不应用任何效果
```

**分析**:
- 如果一个状态同时配置了 `period > 0` 和状态型效果，状态型效果永远不会被应用
- 逻辑假设"状态型效果"和"周期性效果"是互斥的，但实际上一个状态可以同时拥有多种类型的效果
- 应该根据**效果本身**的类型来判断，而不是根据状态的配置

**影响**: 状态型效果可能永远不会生效

#### 2.2 效果克隆策略不一致

**位置**: `GameplayStatusInstance._apply_all_stateful_effects()` vs `_apply_all_effects()`

**问题**:
- `_apply_all_stateful_effects()`: 克隆效果模板 (`duplicate(true)`)
- `_apply_all_effects()`: 直接使用效果模板（不克隆）

**分析**:
- 周期性效果和事件监听型效果直接使用模板，可能导致状态共享
- 如果多个状态实例使用同一个 `GameplayStatusData`，它们会共享效果实例
- 应该统一使用克隆策略

**影响**: 可能导致效果状态混乱，多个状态实例互相影响

#### 2.3 事件监听逻辑复杂且可能不准确

**位置**: `GameplayStatusInstance._on_game_event_occurred()`

**问题**:
```gdscript
# 检查事件上下文中的目标是否为当前实体
var is_related_to_entity = false
if context.has("target") and context["target"] == target:
    is_related_to_entity = true
elif context.has("entity") and context["entity"] == target:
    is_related_to_entity = true
elif context.has("source") and context["source"] == target:
    is_related_to_entity = true
```

**分析**:
- 事件相关性检查逻辑复杂，且可能遗漏某些情况
- 不同事件可能有不同的上下文键名，硬编码检查不够灵活
- 应该由事件系统或效果系统来过滤，而不是在状态实例中

**影响**: 状态可能响应不相关的事件，或错过相关事件

### ⚠️ 中等问题

#### 2.4 状态型效果定义不清晰

**问题**: "状态型效果"的定义依赖于 `period` 和 `event_to_listen` 是否为空，这个逻辑不够直观

**建议**: 应该在 `GameplayEffect` 中添加 `effect_type` 枚举，明确区分：
- `IMMEDIATE` - 立即生效，持续存在
- `PERIODIC` - 周期性触发
- `EVENT_TRIGGERED` - 事件触发

#### 2.5 缺少状态优先级和互斥机制

**问题**:
- 没有状态优先级系统（如：高级状态覆盖低级状态）
- 没有状态互斥机制（除了通过标签）
- 无法实现"新状态替换旧状态"的逻辑

**建议**: 在 `GameplayStatusData` 中添加：
- `priority: int` - 状态优先级
- `mutually_exclusive_statuses: Array[StringName]` - 互斥状态列表

#### 2.6 效果应用时机不统一

**问题**: 
- 状态型效果在 `apply()` 时立即应用
- 周期性效果在定时器触发时应用
- 事件监听型效果在事件发生时应用
- 缺少统一的入口点，难以追踪和调试

**建议**: 统一使用 `_apply_effect()` 方法，根据效果类型决定应用时机

#### 2.7 缺少状态过期检查

**问题**: 除了定时器自动移除，没有其他机制检查状态是否应该过期（如：条件过期）

**建议**: 添加 `_check_status_expiration()` 方法，支持条件过期

### 💡 优化建议

#### 2.8 状态堆叠逻辑可以优化

**位置**: `GameplayStatusComponent.apply_status()`

**问题**: 堆叠逻辑集中在 Component 中，Instance 只负责执行

**建议**: 将堆叠逻辑移到 Instance 中，Component 只负责管理

#### 2.9 缺少状态查询API

**问题**: 缺少按标签、按类型查询状态的API

**建议**: 添加：
- `get_statuses_by_tags(tags: Array[StringName]) -> Array[GameplayStatusInstance]`
- `get_statuses_by_type(is_debuff: bool) -> Array[GameplayStatusInstance]`

#### 2.10 事件监听系统冗余

**问题**: 有两个事件监听系统：
- `event_to_listen` - 状态级别的事件监听
- `trigger_on_events` - 状态可以响应的事件类型

**建议**: 统一为一个系统，简化配置

---

## 3. 重构建议

### 3.1 重构优先级

#### 优先级 1: 修复严重问题（必须）

1. **修复状态型效果判断逻辑**
   - 移除 `_apply_all_stateful_effects()` 中的错误检查
   - 根据效果类型而不是状态配置来判断

2. **统一效果克隆策略**
   - 所有效果都使用克隆
   - 确保每个状态实例有独立的效果实例

3. **简化事件监听逻辑**
   - 移除复杂的事件相关性检查
   - 由事件系统或效果系统负责过滤

#### 优先级 2: 架构改进（重要）

4. **添加效果类型枚举**
   - 在 `GameplayEffect` 中添加 `effect_type` 枚举
   - 明确区分不同类型的效果

5. **添加状态优先级和互斥**
   - 在 `GameplayStatusData` 中添加 `priority` 和 `mutually_exclusive_statuses`
   - 在 `GameplayStatusComponent.apply_status()` 中实现优先级和互斥逻辑

6. **统一效果应用入口**
   - 创建 `_apply_effect()` 统一方法
   - 根据效果类型决定应用时机

#### 优先级 3: 功能增强（可选）

7. **添加状态过期检查**
   - 支持条件过期（如：血量低于阈值时移除状态）

8. **优化状态查询API**
   - 添加按标签、按类型查询的方法

9. **简化事件监听系统**
   - 统一 `event_to_listen` 和 `trigger_on_events`

---

## 4. 详细重构方案

### 4.1 修复状态型效果判断逻辑

**当前代码**:
```gdscript
func _apply_all_stateful_effects(context: Dictionary) -> void:
    # 检查是否是状态型效果（不是周期性，不是事件监听型）
    if status_data.period > 0.0 or status_data.event_to_listen != &"":
        return  # ❌ 错误：直接返回
```

**重构后**:
```gdscript
func _apply_all_stateful_effects(context: Dictionary) -> void:
    var target = get_target_entity()
    if not is_instance_valid(target):
        return
    
    # 应用所有立即生效的效果（不依赖 period 或 event_to_listen）
    for effect_template in status_data.effects:
        # 检查效果类型（需要在 GameplayEffect 中添加 effect_type）
        if effect_template.effect_type == GameplayEffect.EffectType.IMMEDIATE:
            var effect_clone = effect_template.duplicate(true)
            context["stacks"] = stacks
            effect_clone.apply(target, instigator, context)
            stateful_effects.append(effect_clone)
```

### 4.2 统一效果克隆策略

**重构后**:
```gdscript
func _apply_all_effects(context: Dictionary) -> void:
    var target = get_target_entity()
    if not is_instance_valid(target):
        return
    
    context["stacks"] = stacks
    
    # 统一使用克隆策略
    for effect_template in status_data.effects:
        if not is_instance_valid(effect_template):
            continue
        
        # 克隆效果实例（避免状态共享）
        var effect_clone = effect_template.duplicate(true) as GameplayEffect
        if is_instance_valid(effect_clone):
            effect_clone.apply(target, instigator, context)
```

### 4.3 简化事件监听逻辑

**重构后**:
```gdscript
func _on_game_event_occurred(event_type: StringName, context: Dictionary) -> void:
    var target = get_target_entity()
    if not is_instance_valid(target):
        return
    
    # 简化：只检查事件类型是否匹配，不检查事件相关性
    # 事件相关性应该由事件系统或效果系统负责
    if status_data.can_trigger_on_event(event_type) or status_data.event_to_listen == event_type:
        handle_event(event_type, context)
```

### 4.4 添加效果类型枚举

**在 `GameplayEffect` 中添加**:
```gdscript
enum EffectType {
    IMMEDIATE,      # 立即生效，持续存在（状态型效果）
    PERIODIC,       # 周期性触发
    EVENT_TRIGGERED # 事件触发
}

@export var effect_type: EffectType = EffectType.IMMEDIATE
```

### 4.5 添加状态优先级和互斥

**在 `GameplayStatusData` 中添加**:
```gdscript
@export_group("Status Relations")
## 状态优先级（数字越大优先级越高）
## 当新状态与旧状态冲突时，优先级高的状态会覆盖优先级低的状态
@export var priority: int = 0

## 互斥状态列表（与此状态互斥的状态ID列表）
## 当添加此状态时，会自动移除互斥状态；反之亦然
@export var mutually_exclusive_statuses: Array[StringName] = []
```

**在 `GameplayStatusComponent.apply_status()` 中添加**:
```gdscript
func apply_status(gsd: GameplayStatusData, instigator: Node, stacks: int = 1, context: Dictionary = {}) -> void:
    # ... 现有验证逻辑 ...
    
    # 处理互斥状态
    if not gsd.mutually_exclusive_statuses.is_empty():
        for excl_status_id in gsd.mutually_exclusive_statuses:
            if has_status(excl_status_id):
                remove_status(excl_status_id)
    
    # 处理优先级（如果新状态优先级更高，移除旧状态）
    if _active_statuses.has(status_id):
        var existing_instance = _active_statuses[status_id]
        var existing_priority = existing_instance.status_data.priority
        if gsd.priority > existing_priority:
            # 新状态优先级更高，移除旧状态
            remove_status(status_id)
        elif gsd.priority < existing_priority:
            # 旧状态优先级更高，忽略新状态
            return
    
    # ... 现有堆叠逻辑 ...
```

### 4.6 统一效果应用入口

**重构后**:
```gdscript
## 统一的效果应用入口
func _apply_effect(effect: GameplayEffect, context: Dictionary) -> void:
    var target = get_target_entity()
    if not is_instance_valid(target):
        return
    
    context["stacks"] = stacks
    
    # 克隆效果实例
    var effect_clone = effect.duplicate(true) as GameplayEffect
    if not is_instance_valid(effect_clone):
        return
    
    # 根据效果类型决定存储方式
    match effect_clone.effect_type:
        GameplayEffect.EffectType.IMMEDIATE:
            effect_clone.apply(target, instigator, context)
            stateful_effects.append(effect_clone)
        GameplayEffect.EffectType.PERIODIC:
            # 周期性效果由定时器触发，不在这里应用
            pass
        GameplayEffect.EffectType.EVENT_TRIGGERED:
            # 事件触发型效果由事件系统触发，不在这里应用
            pass
```

---

## 5. 重构后的架构

### 5.1 类图

```
GameplayStatusComponent
  ├─ apply_status() - 应用状态（处理优先级、互斥、堆叠）
  ├─ remove_status() - 移除状态
  ├─ get_statuses_by_tags() - 按标签查询
  └─ get_statuses_by_type() - 按类型查询

GameplayStatusInstance
  ├─ apply() - 应用状态（统一入口）
  ├─ remove() - 移除状态（统一清理）
  ├─ _apply_effect() - 统一效果应用入口
  ├─ _apply_immediate_effects() - 应用立即生效效果
  ├─ _apply_periodic_effects() - 注册周期性效果
  └─ _apply_event_triggered_effects() - 注册事件触发效果

GameplayStatusData
  ├─ priority - 优先级
  ├─ mutually_exclusive_statuses - 互斥状态列表
  └─ effects - 效果列表（每个效果有 effect_type）
```

### 5.2 数据流

```
应用状态流程:
1. GameplayStatusComponent.apply_status()
   ├─ 检查互斥状态 → 移除互斥状态
   ├─ 检查优先级 → 决定是否替换
   └─ 检查堆叠策略 → 决定堆叠方式
2. GameplayStatusInstance.apply()
   ├─ _apply_immediate_effects() → 立即应用
   ├─ _create_periodic_timer() → 注册周期性效果
   ├─ _connect_event_bus() → 注册事件监听
   └─ _apply_status_tags() → 应用标签
```

---

## 6. 迁移计划

### 阶段 1: 修复严重问题（1-2天）
1. 修复状态型效果判断逻辑
2. 统一效果克隆策略
3. 简化事件监听逻辑

### 阶段 2: 架构改进（2-3天）
4. 添加效果类型枚举
5. 添加状态优先级和互斥
6. 统一效果应用入口

### 阶段 3: 功能增强（1-2天）
7. 添加状态过期检查
8. 优化状态查询API
9. 简化事件监听系统

### 阶段 4: 测试和文档（1天）
10. 编写测试用例
11. 更新文档

**总计**: 5-8天

---

## 7. 风险评估

### 高风险
- ⚠️ **效果克隆策略改变**: 可能影响现有状态的运行
- ⚠️ **事件监听逻辑简化**: 可能改变状态的响应行为

### 中风险
- ⚠️ **效果类型枚举**: 需要为所有现有效果添加类型
- ⚠️ **状态优先级和互斥**: 可能改变状态的交互逻辑

### 低风险
- ✅ **状态查询API**: 纯新增功能，不影响现有代码
- ✅ **状态过期检查**: 可选功能，不影响现有代码

---

## 8. 总结

### 当前状态
- **实现质量**: ⭐⭐⭐ (3/5)
- **架构清晰度**: ⭐⭐⭐ (3/5)
- **可维护性**: ⭐⭐ (2/5)

### 重构后预期
- **实现质量**: ⭐⭐⭐⭐ (4/5)
- **架构清晰度**: ⭐⭐⭐⭐⭐ (5/5)
- **可维护性**: ⭐⭐⭐⭐ (4/5)

### 建议
1. **立即**: 修复严重问题（状态型效果判断、效果克隆、事件监听）
2. **短期**: 添加效果类型枚举和状态优先级/互斥
3. **中期**: 统一效果应用入口，优化查询API

---

**重构优先级**: 🔴 高（存在严重问题，可能影响功能正确性）

