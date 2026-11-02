# 📊 状态系统重构方案 V2（基于用户反馈）

**更新日期**: 2024
**基于**: 用户反馈和设计原则

---

## 1. 重构原则

1. **移除"状态型效果"概念**：效果只负责执行，状态负责管理触发时机
2. **效果必须克隆**：参考技能系统，所有效果使用前必须克隆
3. **状态优先级**：支持新状态替换旧状态（通过优先级）
4. **标签互斥**：通过标签系统处理互斥，不需要额外的互斥状态列表
5. **简化事件监听**：优化事件相关性检查逻辑

---

## 2. 重构方案

### 2.1 移除状态型效果判断逻辑（✅ 简化设计）

**当前问题**:
```gdscript
# 错误的逻辑：根据状态配置判断效果类型
if status_data.period > 0.0 or status_data.event_to_listen != &"":
    return  # 不应用任何效果
```

**重构方案**:
- **移除 `_apply_all_stateful_effects()` 方法**
- **统一使用 `_apply_all_effects()` 方法**
- **状态只负责管理触发时机，不区分效果类型**
- **所有效果在应用时都克隆**

**重构后**:
```gdscript
func apply(context: Dictionary = {}) -> void:
    # 1. 应用所有效果（立即生效的）
    # 注意：这里不区分"状态型效果"，所有效果都应用
    # 如果效果需要在特定时机触发，由效果自己决定（通过 delay 等）
    _apply_all_effects(context)
    
    # 2. 注册周期性效果（使用状态级别的 period）
    if status_data.period > 0.0:
        _create_periodic_timer()
    
    # 3. 注册事件监听型效果（使用状态级别的 event_to_listen）
    if status_data.event_to_listen != &"":
        _connect_event_bus()
    
    # 4. 应用状态标签
    _apply_status_tags()
```

### 2.2 统一效果克隆策略（✅ 参考技能系统）

**当前问题**:
- `_apply_all_stateful_effects()`: 克隆效果
- `_apply_all_effects()`: 不克隆效果

**重构方案**:
- **所有效果都使用克隆**（参考 `ActiveAbility._apply_single_effect_to_target`）
- **统一克隆逻辑**

**重构后**:
```gdscript
func _apply_all_effects(context: Dictionary) -> void:
    var target = get_target_entity()
    if not is_instance_valid(target):
        return
    
    context["stacks"] = stacks
    
    # 统一克隆所有效果（参考技能系统）
    for effect_template in status_data.effects:
        if not is_instance_valid(effect_template):
            continue
        
        # 克隆效果实例（避免状态共享）
        var effect_clone = effect_template.duplicate(true) as GameplayEffect
        if not is_instance_valid(effect_clone):
            continue
        
        # 应用效果
        effect_clone.apply(target, instigator, context)
        
        # 如果是需要移除的效果（有 remove 方法），存储克隆
        # 注意：这里需要判断效果是否需要移除
        # 可以通过检查效果是否有 _remove 实现，或者添加一个标记
        if effect_clone.has_method("_remove") and effect_clone._remove != GameplayEffect._remove:
            stateful_effects.append(effect_clone)
```

**问题**: 如何判断效果是否需要移除？

**解决方案**: 
- 方案1：检查效果是否有 `_remove` 实现（不是基类的默认实现）
- 方案2：在 `GameplayEffect` 中添加 `needs_removal: bool` 标记
- 方案3：所有效果都存储，移除时调用 `remove()`（如果效果没有实现 `_remove`，基类会处理）

**推荐**: 方案3，因为 `GameplayEffect.remove()` 已经处理了这种情况。

### 2.3 简化事件监听逻辑（✅ 优化实现）

**当前问题**:
- 硬编码检查事件相关性（`target`, `entity`, `source`）
- 可能遗漏或误判

**重构方案**:
- **方案A**: 由事件系统负责过滤（在 `AbilityEventBus` 中）
- **方案B**: 由效果系统负责过滤（在 `GameplayEffect` 中）
- **方案C**: 简化检查逻辑，只检查事件类型

**推荐**: 方案C（简化检查）+ 方案A（事件系统增强）

**重构后**:
```gdscript
func _on_game_event_occurred(event_type: StringName, context: Dictionary) -> void:
    var target = get_target_entity()
    if not is_instance_valid(target):
        return
    
    # 简化：只检查事件类型是否匹配
    # 事件相关性应该由事件系统在发送时保证，或者在效果系统中过滤
    if status_data.can_trigger_on_event(event_type) or status_data.event_to_listen == event_type:
        handle_event(event_type, context)
```

**进一步优化**: 在 `AbilityEventBus` 中添加目标过滤，确保事件只发送给相关实体。

### 2.4 添加状态优先级（✅ 支持替换）

**重构方案**:
- 在 `GameplayStatusData` 中添加 `priority: int`
- 在 `GameplayStatusComponent.apply_status()` 中实现优先级逻辑

**重构后**:
```gdscript
# GameplayStatusData
@export_group("Status Relations")
## 状态优先级（数字越大优先级越高）
## 当新状态与旧状态冲突时，优先级高的状态会替换优先级低的状态
@export var priority: int = 0

# GameplayStatusComponent.apply_status()
func apply_status(gsd: GameplayStatusData, instigator: Node, stacks: int = 1, context: Dictionary = {}) -> void:
    # ... 现有验证逻辑 ...
    
    var status_id = gsd.status_id
    
    # 处理优先级：如果新状态优先级更高，替换旧状态
    if _active_statuses.has(status_id):
        var existing_instance = _active_statuses[status_id]
        var existing_priority = existing_instance.status_data.priority
        
        if gsd.priority > existing_priority:
            # 新状态优先级更高，移除旧状态
            remove_status(status_id)
        elif gsd.priority < existing_priority:
            # 旧状态优先级更高，忽略新状态
            return
        # 如果优先级相同，继续执行堆叠逻辑
    
    # ... 现有堆叠逻辑 ...
```

### 2.5 统一效果应用入口（✅ 可选优化）

**重构方案**:
- 创建 `_apply_single_effect()` 统一方法
- 所有效果应用都通过此方法

**重构后**:
```gdscript
## 统一的效果应用入口
func _apply_single_effect(effect_template: GameplayEffect, context: Dictionary) -> void:
    var target = get_target_entity()
    if not is_instance_valid(target):
        return
    
    if not is_instance_valid(effect_template):
        return
    
    # 克隆效果实例
    var effect_clone = effect_template.duplicate(true) as GameplayEffect
    if not is_instance_valid(effect_clone):
        return
    
    # 应用效果
    effect_clone.apply(target, instigator, context)
    
    # 存储需要移除的效果
    # 注意：所有效果都存储，移除时统一调用 remove()
    stateful_effects.append(effect_clone)

func _apply_all_effects(context: Dictionary) -> void:
    context["stacks"] = stacks
    for effect_template in status_data.effects:
        _apply_single_effect(effect_template, context)
```

---

## 3. 实施计划

### 阶段 1: 核心修复（必须）

1. ✅ 移除 `_apply_all_stateful_effects()` 方法
2. ✅ 统一使用 `_apply_all_effects()`，所有效果都克隆
3. ✅ 简化事件监听逻辑

### 阶段 2: 功能增强（重要）

4. ✅ 添加状态优先级支持
5. ✅ 统一效果应用入口（可选）

### 阶段 3: 测试和验证

6. ✅ 测试所有状态类型（立即、周期性、事件触发）
7. ✅ 验证效果克隆正确性
8. ✅ 验证优先级替换逻辑

---

## 4. 代码变更清单

### 4.1 GameplayStatusInstance

**删除**:
- `_apply_all_stateful_effects()` 方法

**修改**:
- `apply()`: 移除状态型效果判断，统一使用 `_apply_all_effects()`
- `_apply_all_effects()`: 统一克隆所有效果
- `_on_game_event_occurred()`: 简化事件相关性检查
- `_remove_all_stateful_effects()`: 重命名为 `_remove_all_effects()`，移除所有效果

**新增**:
- `_apply_single_effect()`: 统一效果应用入口（可选）

### 4.2 GameplayStatusData

**新增**:
- `priority: int` - 状态优先级

### 4.3 GameplayStatusComponent

**修改**:
- `apply_status()`: 添加优先级检查逻辑

---

## 5. 风险评估

### 低风险
- ✅ **移除状态型效果概念**: 简化设计，不会破坏现有功能
- ✅ **统一效果克隆**: 更安全，避免状态共享
- ✅ **简化事件监听**: 减少误判，提高可靠性

### 中风险
- ⚠️ **状态优先级**: 可能改变现有状态的交互逻辑，需要测试

---

## 6. 总结

### 核心改进
1. **简化设计**: 移除"状态型效果"概念，效果只负责执行
2. **统一克隆**: 所有效果都克隆，避免状态共享
3. **简化事件**: 移除复杂的事件相关性检查
4. **支持优先级**: 新状态可以替换旧状态

### 预期效果
- **代码更简洁**: 移除不必要的类型判断
- **更安全**: 统一克隆策略，避免状态共享
- **更灵活**: 支持状态优先级替换
- **更可靠**: 简化事件监听逻辑

---

**重构优先级**: 🔴 高（修复严重问题，简化设计）

