# 状态系统重构总结

## 重构概述
本次重构解决了状态系统的多个架构问题，提升了系统的清晰度、性能和可维护性。

---

## 主要改动

### 1. 效果分类重构 ✅

**改动前：**
- 只有一个 `effects` 数组，混合了瞬时效果和需要存储的效果
- `periodic_effects` 用于周期性效果

**改动后：**
- `apply_effects`: 状态应用时触发的效果（一次性，不会在层数叠加时重新触发）
- `remove_effects`: 状态移除时触发的效果（用于清理或触发移除时的效果）
- `periodic_effects`: 周期性触发的效果（DoT、HoT等）
- `event_triggered_effects`: 事件触发型效果

**优势：**
- 清晰区分不同生效时机的效果
- 解决了 `add_stack` 时重复触发瞬时伤害的问题
- 支持移除时效果，可以用于清理操作

---

### 2. 堆叠逻辑优化 ✅

**改动前：**
- `add_stack` 会重新触发所有效果，包括瞬时效果
- 导致层数叠加时重复造成伤害

**改动后：**
- 堆叠只影响移除生效、周期触发和事件触发的效果
- 不会重新触发应用时效果
- 只更新属性修改器（使用新层数）

**优势：**
- 避免了层数叠加时的副作用
- 符合游戏设计预期

---

### 3. 移除 only_stateful 参数 ✅

**改动前：**
- `_apply_all_effects` 有 `only_stateful` 参数，但未实现
- 代码中只是 `pass`，无法真正过滤

**改动后：**
- 按效果分类区分执行，不再需要 `only_stateful` 参数
- 每种效果类型有独立的处理方法

**优势：**
- 代码更清晰，逻辑更明确
- 不再需要复杂的过滤逻辑

---

### 4. 统一事件监听字段 ✅

**改动前：**
- `event_to_listen`: 单个事件监听
- `trigger_on_events`: 多个事件监听
- 两个字段功能重叠，容易混淆

**改动后：**
- 统一使用 `trigger_on_events: Array[StringName]`
- 移除了 `event_to_listen` 字段

**优势：**
- 配置更简单，不会混淆
- 代码逻辑更清晰

---

### 5. 统一计时管理 ✅

**改动前：**
- 每个状态实例创建 `Timer` 节点
- `RefCounted` 类型依赖 `Node` 来管理计时器
- 生命周期管理复杂

**改动后：**
- 在 `GameplayStatusComponent` 的 `_process` 中统一管理
- 状态实例只存储剩余时间（`_remaining_duration`）和周期性计时器（`_periodic_timer`）
- 实现 `update(delta)` 方法，类似 CD 的计时方式

**优势：**
- 性能更好（不需要创建大量 Timer 节点）
- 生命周期管理更简单
- 统一管理，便于优化

---

### 6. 统一事件连接管理 ✅

**改动前：**
- 每个状态实例都连接到 `AbilityEventBus.game_event_occurred`
- 如果有 100 个状态，就有 100 个连接
- 事件触发时，所有状态都会收到事件

**改动后：**
- 在 `GameplayStatusComponent` 中统一连接一次
- 组件中过滤事件，只转发给相关状态
- 使用 `_has_event_listening_statuses` 标志优化性能

**优势：**
- 性能大幅提升（只有一个连接）
- 事件过滤更高效
- 代码更清晰

---

### 7. 移除目标选择策略 ✅

**改动前：**
- 代码注释提到"支持目标选择策略"
- 但实际实现中总是返回状态持有者

**改动后：**
- 明确状态层不再涉及目标选择策略的实现
- 移除了相关注释和代码

**优势：**
- 代码更清晰，不会误导
- 职责更明确

---

### 8. 优化上下文管理 ✅

**改动前：**
- `_initial_context` 在状态应用时保存
- 周期性效果使用固定上下文

**改动后：**
- 使用 `_cached_context` 缓存上下文
- 用于移除时效果和周期性效果
- 支持实现类似移除属性修改器这样的操作

**优势：**
- 上下文管理更灵活
- 支持移除时效果使用上下文

---

## 代码变更总结

### GameplayStatusData
- ✅ 添加 `apply_effects`、`remove_effects`、`event_triggered_effects`
- ✅ 移除 `event_to_listen` 字段
- ✅ 统一使用 `trigger_on_events`

### GameplayStatusInstance
- ✅ 移除 `Timer` 节点，改用 `_remaining_duration` 和 `_periodic_timer`
- ✅ 实现 `update(delta)` 方法
- ✅ 实现 `_apply_apply_effects`、`_apply_remove_effects`、`_apply_periodic_effects`、`_apply_event_triggered_effects`
- ✅ 移除 `only_stateful` 参数
- ✅ 移除事件总线连接（由组件统一管理）
- ✅ 优化 `add_stack` 逻辑
- ✅ 使用 `_cached_context` 缓存上下文

### GameplayStatusComponent
- ✅ 添加 `_process` 方法统一管理计时器
- ✅ 统一管理事件连接（只连接一次）
- ✅ 添加 `_has_event_listening_statuses` 标志优化性能
- ✅ 添加 `_update_event_listening_status` 方法

---

## 向后兼容性

⚠️ **注意：** 本次重构破坏了向后兼容性，需要更新所有使用旧字段的状态数据：

- `effects` → `apply_effects`
- `event_to_listen` → 移除，使用 `trigger_on_events` 数组

---

## 性能优化

1. **计时器管理**：从 O(n) 个 Timer 节点 → O(1) 个 _process 调用
2. **事件连接**：从 O(n) 个连接 → O(1) 个连接
3. **事件过滤**：在组件级别过滤，减少不必要的状态处理

---

## 测试建议

1. **效果分类测试**：
   - 验证应用时效果只在应用时触发
   - 验证移除时效果在移除时触发
   - 验证周期性效果按周期触发
   - 验证事件触发型效果在事件发生时触发

2. **堆叠测试**：
   - 验证层数叠加时不会重新触发应用时效果
   - 验证属性修改器正确更新

3. **计时测试**：
   - 验证持续时间正确计算
   - 验证周期性效果正确触发

4. **事件测试**：
   - 验证事件触发型效果正确响应事件

---

## 后续优化建议

1. **效果描述**：更新 `get_effects_description` 方法，包含所有效果类型
2. **迁移工具**：创建工具自动迁移旧的状态数据到新格式
3. **文档更新**：更新使用文档和示例

