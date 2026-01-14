# AbilityEventBus 使用指南

## 概述

`AbilityEventBus` 是技能系统的全局事件总线，提供统一的事件通讯机制。经过重构后，现在支持：

- ✅ **类型安全**：严格的类型检查
- ✅ **性能优化**：事件过滤机制
- ✅ **调试支持**：事件日志和统计
- ✅ **向后兼容**：保持原有 API

---

## 基本使用

### 1. 触发事件

```gdscript
# 触发伤害应用事件
AbilityEventBus.trigger_game_event(&"damage_applied", {
    "damage_info": damage_info,
    "target": target,
    "final_damage": 50.0
})

# 触发技能学习事件
AbilityEventBus.trigger_game_event(&"ability_learned", {
    "entity": player,
    "ability_id": &"fireball"
})
```

### 2. 监听所有事件（向后兼容）

```gdscript
# 在 _ready() 中连接
func _ready() -> void:
    AbilityEventBus.game_event_occurred.connect(_on_game_event_occurred)

func _on_game_event_occurred(event_type: StringName, context: Dictionary) -> void:
    # 需要手动过滤事件类型
    if event_type == &"damage_applied":
        _handle_damage(context)
    elif event_type == &"ability_learned":
        _handle_ability_learned(context)
```

**注意**：这种方式所有监听者都会收到所有事件，性能较差。

### 3. 监听特定事件（推荐，性能更好）⭐

```gdscript
# 在 _ready() 中订阅
func _ready() -> void:
    AbilityEventBus.subscribe_to_event(&"damage_applied", _on_damage_applied)
    AbilityEventBus.subscribe_to_event(&"ability_learned", _on_ability_learned)

func _on_damage_applied(event_type: StringName, context: Dictionary) -> void:
    var damage_info = context.get("damage_info")
    var target = context.get("target")
    var final_damage = context.get("final_damage", 0.0)
    
    print("Damage applied to %s: %.1f" % [target.name, final_damage])

func _on_ability_learned(event_type: StringName, context: Dictionary) -> void:
    var entity = context.get("entity")
    var ability_id = context.get("ability_id")
    
    print("%s learned ability: %s" % [entity.name, ability_id])

# 在 _exit_tree() 中取消订阅（可选，但推荐）
func _exit_tree() -> void:
    AbilityEventBus.unsubscribe_from_event(&"damage_applied", _on_damage_applied)
    AbilityEventBus.unsubscribe_from_event(&"ability_learned", _on_ability_learned)
```

**优势**：
- ✅ 只接收关心的事件，性能更好
- ✅ 不需要手动过滤
- ✅ 代码更清晰

---

## 常用事件类型

### 伤害相关
- `damage_received` - 伤害接收时（在计算减免之前）
- `damage_applied` - 伤害应用时（在计算减免之后）

**Context 结构**：
```gdscript
{
    "damage_info": DamageInfo,  # 伤害信息
    "target": Node,              # 目标实体
    "final_damage": float         # 最终伤害值（仅 damage_applied）
}
```

### 治疗相关
- `healing_applied` - 治疗应用时

**Context 结构**：
```gdscript
{
    "target": Node,              # 目标实体
    "instigator": Node,          # 施法者
    "amount": float              # 治疗量
}
```

### 技能相关
- `ability_learned` - 技能学习时
- `ability_forgotten` - 技能遗忘时
- `ability_activated` - 技能激活时
- `ability_completed` - 技能完成时
- `ability_cancelled` - 技能取消时

**Context 结构**：
```gdscript
{
    "entity": Node,              # 实体
    "ability_id": StringName     # 技能ID
}
```

### 状态相关
- `status_applied` - 状态应用时
- `status_removed` - 状态移除时

**Context 结构**：
```gdscript
{
    "entity": Node,              # 实体
    "status_id": StringName       # 状态ID
}
```

---

## 调试功能

### 启用调试日志

在 Godot 编辑器中：
1. 选择 `AbilityEventBus` 节点（在自动加载中）
2. 勾选 `Enable Debug` 属性

或在代码中：
```gdscript
AbilityEventBus.enable_debug = true
```

启用后，所有事件都会：
- 打印到控制台
- 记录到事件日志

### 查看事件统计

```gdscript
var stats = AbilityEventBus.get_event_stats()
for event_type in stats:
    print("%s: %d subscribers" % [event_type, stats[event_type].subscriber_count])
```

### 查看事件日志

```gdscript
# 查看所有事件
var all_events = AbilityEventBus.get_event_log()

# 查看特定类型的事件
var damage_events = AbilityEventBus.get_event_log(&"damage_applied")

# 清空日志
AbilityEventBus.clear_event_log()
```

---

## 最佳实践

### 1. 优先使用 `subscribe_to_event`

```gdscript
# ✅ 推荐
AbilityEventBus.subscribe_to_event(&"damage_applied", _on_damage)

# ❌ 不推荐（性能较差）
AbilityEventBus.game_event_occurred.connect(_on_all_events)
func _on_all_events(event_type: StringName, context: Dictionary) -> void:
    if event_type == &"damage_applied":  # 需要手动过滤
        _on_damage(event_type, context)
```

### 2. 记得取消订阅

```gdscript
func _ready() -> void:
    AbilityEventBus.subscribe_to_event(&"damage_applied", _on_damage)

func _exit_tree() -> void:
    # 避免内存泄漏
    AbilityEventBus.unsubscribe_from_event(&"damage_applied", _on_damage)
```

### 3. 使用类型安全的 context

```gdscript
func _on_damage_applied(event_type: StringName, context: Dictionary) -> void:
    # ✅ 使用 get() 并提供默认值
    var damage_info = context.get("damage_info")
    var final_damage = context.get("final_damage", 0.0)
    
    # ✅ 类型检查
    if not damage_info is DamageInfo:
        push_error("Invalid damage_info in context")
        return
    
    # 使用数据
    print("Damage: %.1f" % final_damage)
```

### 4. 避免在回调中执行耗时操作

```gdscript
# ❌ 不推荐：在事件回调中执行耗时操作
func _on_damage_applied(event_type: StringName, context: Dictionary) -> void:
    # 这会阻塞事件处理
    save_to_database(context)
    process_complex_calculation(context)

# ✅ 推荐：使用队列或异步处理
func _on_damage_applied(event_type: StringName, context: Dictionary) -> void:
    # 添加到队列，稍后处理
    _damage_queue.append(context)
    # 或使用异步
    _process_damage_async(context)
```

---

## 迁移指南

### 从旧版本迁移

如果你之前使用 `game_event_occurred` 信号：

```gdscript
# 旧代码
func _ready() -> void:
    AbilityEventBus.game_event_occurred.connect(_on_event)

func _on_event(event_type: StringName, context: Dictionary) -> void:
    if event_type == &"damage_applied":
        _handle_damage(context)
```

**迁移到新 API**：

```gdscript
# 新代码（性能更好）
func _ready() -> void:
    AbilityEventBus.subscribe_to_event(&"damage_applied", _handle_damage)

func _handle_damage(event_type: StringName, context: Dictionary) -> void:
    # 直接处理，不需要过滤
    var damage_info = context.get("damage_info")
    # ...
```

---

## 性能对比

### 场景：10 个事件类型，每个类型 5 个监听者

**旧方式（game_event_occurred）**：
- 每次触发：通知 50 个监听者（10 × 5）
- 每个监听者需要过滤：50 次字符串比较

**新方式（subscribe_to_event）**：
- 每次触发：只通知 5 个相关监听者
- 无需过滤：0 次字符串比较

**性能提升**：约 10 倍（取决于事件类型数量）

---

## 常见问题

### Q: 为什么需要取消订阅？

A: 避免内存泄漏。如果节点被销毁但回调仍然注册，会导致：
- 内存泄漏
- 调用已销毁对象的回调（错误）

### Q: 可以同时使用两种方式吗？

A: 可以，但推荐只使用 `subscribe_to_event`。两种方式都会触发，但 `subscribe_to_event` 性能更好。

### Q: 调试日志会影响性能吗？

A: 只有在 `enable_debug = true` 时才会记录日志。生产环境建议关闭。

### Q: 如何知道有哪些事件类型？

A: 查看代码中使用 `trigger_game_event` 的地方，或查看本文档的"常用事件类型"部分。

---

## 总结

- ✅ 使用 `subscribe_to_event` 而不是 `game_event_occurred.connect`
- ✅ 记得在 `_exit_tree()` 中取消订阅
- ✅ 使用类型安全的 context 访问
- ✅ 避免在回调中执行耗时操作
- ✅ 生产环境关闭调试日志
