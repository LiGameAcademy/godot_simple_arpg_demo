# 状态效果移除机制分析

## 当前实现分析

### 实现方式
```gdscript
func remove() -> void:
    # 1. 应用移除时效果（用于其他清理逻辑，如视觉效果、事件触发等）
    _apply_effects(status_data.remove_effects, remove_context)
    
    # 2. 移除应用时效果（清理应用时创建的资源，如修改器）
    _remove_effects(status_data.apply_effects, remove_context)
```

**设计思路：**
- `remove_effects` → 调用 `apply` 方法（执行移除时的逻辑）
- `apply_effects` → 调用 `remove` 方法（清理应用时创建的资源）

---

## 实现合理性分析

### ✅ 当前实现是合理的

**理由：**
1. **对称性**：应用时创建的资源，移除时应该清理
2. **清晰性**：`apply_effects` 在移除时调用 `remove`，逻辑清晰
3. **灵活性**：可以通过 `remove_effects` 配置额外的移除逻辑

**示例：**
- 应用时：`GE_AttributeModifier` 创建修改器（`apply`）
- 移除时：`GE_AttributeModifier` 清理修改器（`remove`）

---

## 周期触发和事件触发效果是否需要 remove？

### 分析场景

#### 场景1：周期触发效果应用修改器
**问题**：如果 `periodic_effects` 中的效果应用了修改器，这些修改器是否需要在状态移除时清理？

**分析：**
- 如果周期触发效果使用**状态实例的 source_id**，那么：
  - 状态移除时，`_remove_effects(status_data.apply_effects, remove_context)` 会清理所有使用该 source_id 的修改器
  - **不需要单独清理周期触发的修改器** ✅

- 如果周期触发效果使用**不同的 source_id**（如 `"periodic." + effect_path`），那么：
  - 状态移除时，不会自动清理这些修改器
  - **需要单独清理** ❌

**结论**：取决于 source_id 的设计策略。

#### 场景2：事件触发效果应用修改器
**问题**：如果 `event_triggered_effects` 中的效果应用了修改器，这些修改器是否需要在状态移除时清理？

**分析：**
- 与周期触发效果类似，取决于 source_id 的设计策略。

---

## 推荐方案

### 方案A：统一使用状态实例的 source_id（推荐）⭐

**设计：**
- 所有效果（应用时、周期触发、事件触发）都使用状态实例的 `source_id`
- 状态移除时，统一清理所有使用该 source_id 的修改器

**优势：**
- ✅ 简单：不需要单独清理周期触发和事件触发的效果
- ✅ 可靠：所有修改器都会被清理
- ✅ 性能：一次批量移除，效率高

**实现：**
```gdscript
# 周期触发效果
func update(delta: float) -> bool:
    # ...
    var context = _cached_context.duplicate()
    context["source_id"] = _get_source_instance_id()  # 使用状态实例的 source_id
    _apply_effects(status_data.periodic_effects, context)

# 事件触发效果
func handle_event(event_id: StringName, context: Dictionary) -> void:
    var event_context = context.duplicate()
    event_context["stacks"] = stacks
    event_context["source_id"] = _get_source_instance_id()  # 使用状态实例的 source_id
    _apply_effects(status_data.event_triggered_effects, event_context)
```

**状态移除时：**
```gdscript
func remove() -> void:
    # 移除所有使用状态实例 source_id 的修改器
    _remove_effects(status_data.apply_effects, remove_context)
    # 周期触发和事件触发的修改器也会被清理（因为使用相同的 source_id）
```

### 方案B：周期触发和事件触发使用不同的 source_id

**设计：**
- 周期触发效果使用 `"periodic." + status_instance_id`
- 事件触发效果使用 `"event." + status_instance_id`
- 状态移除时，需要单独清理

**优势：**
- ✅ 可以区分不同来源的修改器
- ✅ 可以单独控制清理逻辑

**劣势：**
- ❌ 复杂度增加
- ❌ 需要单独清理逻辑

**实现：**
```gdscript
func remove() -> void:
    # 移除应用时效果的修改器
    _remove_effects(status_data.apply_effects, remove_context)
    
    # 移除周期触发效果的修改器
    var periodic_source_id = "periodic." + str(get_instance_id())
    _remove_effects_by_source_id(status_data.periodic_effects, periodic_source_id)
    
    # 移除事件触发效果的修改器
    var event_source_id = "event." + str(get_instance_id())
    _remove_effects_by_source_id(status_data.event_triggered_effects, event_source_id)
```

---

## 实际需求分析

### 周期触发和事件触发效果通常是什么类型？

**常见类型：**
1. **瞬时效果**（伤害、治疗、位移等）
   - 不需要清理 ✅
   - 执行完就结束

2. **修改器效果**（属性修改器、技能修改器）
   - 需要清理 ❌
   - 但通常不应该在周期触发或事件触发中应用修改器

**设计原则：**
- **应用时效果**：适合应用修改器（状态持续期间生效）
- **周期触发效果**：适合瞬时效果（DoT、HoT等）
- **事件触发效果**：适合瞬时效果（响应事件）

**结论：**
- 周期触发和事件触发效果**通常不需要清理**
- 如果确实需要在这些效果中应用修改器，应该使用状态实例的 `source_id`，这样会自动清理

---

## 最终建议

### 推荐：方案A（统一使用状态实例的 source_id）

**实现：**
1. **确保所有效果使用状态实例的 source_id**
   - 在 `update()` 中，周期触发效果使用状态实例的 `source_id`
   - 在 `handle_event()` 中，事件触发效果使用状态实例的 `source_id`

2. **状态移除时统一清理**
   - 只调用 `_remove_effects(status_data.apply_effects, remove_context)`
   - 周期触发和事件触发的修改器也会被自动清理（如果使用相同的 source_id）

3. **周期触发和事件触发效果通常不需要调用 remove**
   - 因为它们通常是瞬时效果
   - 如果确实应用了修改器，使用相同的 source_id 会自动清理

---

## 代码实现建议

### 更新周期触发效果
```gdscript
func update(delta: float) -> bool:
    # ...
    if status_data.period > 0.0 and not status_data.periodic_effects.is_empty():
        _periodic_timer += delta
        if _periodic_timer >= status_data.period:
            _periodic_timer = 0.0
            var context = _cached_context.duplicate()
            context["source_id"] = _get_source_instance_id()  # 确保使用状态实例的 source_id
            _apply_effects(status_data.periodic_effects, context)
```

### 更新事件触发效果
```gdscript
func handle_event(event_id: StringName, context: Dictionary) -> void:
    # ...
    var event_context = context.duplicate()
    event_context["stacks"] = stacks
    event_context["source_id"] = _get_source_instance_id()  # 确保使用状态实例的 source_id
    _apply_effects(status_data.event_triggered_effects, event_context)
```

### 状态移除（当前实现已合理）
```gdscript
func remove() -> void:
    # 移除应用时效果的修改器（会自动清理所有使用状态实例 source_id 的修改器）
    _remove_effects(status_data.apply_effects, remove_context)
    # 周期触发和事件触发的修改器也会被清理（如果使用相同的 source_id）
```

---

## 总结

1. **当前实现是合理的** ✅
   - `_remove_effects(status_data.apply_effects, remove_context)` 清理应用时效果的修改器

2. **周期触发和事件触发效果通常不需要调用 remove** ✅
   - 它们通常是瞬时效果，不需要清理
   - 如果确实应用了修改器，应该使用状态实例的 `source_id`，这样会自动清理

3. **建议**：
   - 确保周期触发和事件触发效果使用状态实例的 `source_id`
   - 这样状态移除时会自动清理所有修改器
   - 不需要单独为周期触发和事件触发效果调用 remove

