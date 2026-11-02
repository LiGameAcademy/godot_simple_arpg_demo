# 状态系统缺点分析

## 概述
本文档分析了当前状态系统（GameplayStatusData、GameplayStatusInstance、GameplayStatusComponent）的架构缺点和潜在问题。

---

## 1. 效果分类不清晰

### 问题描述
在 `GameplayStatusData` 中，`effects` 数组混合了两种不同类型的效果：
- **瞬时效果**（如初始伤害、治疗）：只需要在应用时触发一次
- **需要存储的效果**（如属性修改器、状态型效果）：需要在移除时清理

### 代码位置
```23:29:addons/godot_gameplay_abilities/scripts/status/gameplay_status_data.gd
@export_group("Effects")
## 状态应用时触发的效果（一次性效果）
## 这些效果在状态被应用时立即触发，包括：
## - 瞬时效果（如初始伤害、治疗）
## - 属性修改器（需要存储以便移除时清理）
## - 视觉效果（如状态图标、粒子特效）
@export var effects: Array[GameplayEffect] = []
```

### 影响
- `add_stack` 时会重新触发所有效果，包括瞬时伤害效果，导致层数叠加时重复造成伤害
- 无法区分哪些效果需要存储，哪些不需要
- 代码注释中提到了 `instant_effects` 的分离方案，但未实现

### 建议
在 `GameplayStatusData` 中分离：
- `instant_effects`: 只在应用时触发一次的效果
- `stateful_effects`: 需要存储并在移除时清理的效果

---

## 2. add_stack 会重新触发瞬时效果

### 问题描述
在 `add_stack` 方法中，虽然注释说明"只重新应用需要存储的效果"，但实际实现中会重新触发所有效果，包括瞬时效果。

### 代码位置
```181:212:addons/godot_gameplay_abilities/scripts/status/gameplay_status_instance.gd
## 增加层数
## 注意：只重新应用需要存储的效果（属性修改器等），不重新触发瞬时效果
func add_stack(amount: int = 1, is_refresh_duration: bool = true) -> void:
	if stacks < status_data.max_stacks:
		# --- 核心：重建需要存储的效果（属性修改器等）---
		# 1. 移除所有旧的需要存储的效果
		_remove_all_effects()
		
		# 2. 移除旧的属性修改器（使用旧层数）
		_unregister_attribute_modifiers()

		# 3. 增加层数
		stacks = min(stacks + amount, status_data.max_stacks)

		# 4. 重新注册属性修改器（使用新层数）
		_register_attribute_modifiers()

		# 5. 用 *新* 的层数，重新施加所有效果
		# 注意：虽然会重新触发所有效果，但这是必要的，因为其他状态型效果需要重新应用
		# 瞬时效果（如伤害）虽然会被重新触发，但这是可以接受的权衡
		# 如果希望避免重新触发瞬时效果，应该在 GameplayStatusData 中将它们分离到 instant_effects
		var target_entity = get_target_entity()
		if is_instance_valid(target_entity):
			var context = {"stacks": stacks}
			# 重新应用所有效果（包括瞬时效果）
			# 这是为了确保其他需要存储的效果能够正确更新
			_apply_all_effects_to_target(target_entity, context, false)
```

### 影响
- 层数叠加时，瞬时伤害效果会被重复触发
- 例如：中毒状态叠加时，每次叠加都会造成一次初始伤害，这是不合理的

### 建议
实现 `only_stateful` 参数的真正过滤逻辑，或者分离 `instant_effects` 和 `stateful_effects`。

---

## 3. only_stateful 参数未实现

### 问题描述
`_apply_all_effects_to_target` 方法中的 `only_stateful` 参数实际上没有实现过滤逻辑，代码中只是 `pass`。

### 代码位置
```271:282:addons/godot_gameplay_abilities/scripts/status/gameplay_status_instance.gd
		# 如果 only_stateful=true，只处理需要存储的效果（有 _remove 实现的效果）
		# 检查效果是否有 _remove 方法的实现（通过检查方法是否存在）
		if only_stateful:
			# 检查效果类是否有 _remove 方法的实现
			# 注意：GDScript 中，如果子类没有重写 _remove，基类的 _remove 是空的
			# 我们需要通过其他方式判断，比如检查效果类型或使用标志
			# 这里我们假设所有需要存储的效果都会在 apply 时设置某种标志
			# 或者我们可以检查效果是否有特定的方法或属性
			# 暂时：如果 only_stateful=true，我们仍然应用所有效果，但只存储那些有实际 remove 逻辑的
			# 实际上，更好的方案是：在 GameplayStatusData 中区分 effects 和 instant_effects
			# 但为了保持向后兼容，我们暂时保持当前逻辑
			pass
```

### 影响
- `add_stack` 时无法真正过滤瞬时效果
- 代码注释承认了这个问题，但未解决

### 建议
- 方案1：在 `GameplayEffect` 基类中添加 `is_stateful: bool` 标志
- 方案2：在 `GameplayStatusData` 中分离 `instant_effects` 和 `stateful_effects`

---

## 4. 事件监听机制重复/混淆

### 问题描述
`GameplayStatusData` 中有两个事件相关的字段：
- `event_to_listen`: 单个事件监听（用于周期性效果）
- `trigger_on_events`: 多个事件监听（用于事件触发型效果）

这两个字段的功能有重叠，且使用场景不清晰。

### 代码位置
```36:49:addons/godot_gameplay_abilities/scripts/status/gameplay_status_data.gd
@export_group("Effect Timing")
## 周期性效果的周期时间，如果为0，则不周期性触发
## 当 period > 0 时，periodic_effects 会按此周期重复触发
@export var period: float = 0.0
## 监听的事件，如果为空，则不监听事件
## 当 event_to_listen 不为空时，所有效果会在该事件发生时触发
@export var event_to_listen: StringName = &""

@export_group("Event Triggers")
## 此状态可以响应的游戏事件类型
## 例如: [&"damage_received", &"turn_start", &"ability_completed"]
## 当这些事件发生时，状态会触发对应的效果
## 注意：效果需要设置 event_to_listen 字段才能被触发
@export var trigger_on_events: Array[StringName] = []
```

### 影响
- 配置时容易混淆，不清楚应该使用哪个字段
- `handle_event` 方法中同时检查两个字段，逻辑复杂

### 代码位置
```142:161:addons/godot_gameplay_abilities/scripts/status/gameplay_status_instance.gd
## 处理事件（用于事件监听型效果）
## 此方法用于处理通过统一事件系统触发的事件
func handle_event(event_id: StringName, context: Dictionary) -> void:
	var status_holder = get_target_entity()
	if not is_instance_valid(status_holder):
		return
	
	# 检查状态是否应该响应这个事件
	if not status_data.can_trigger_on_event(event_id):
		return
	
	# 检查是否是状态级别的事件监听
	if status_data.event_to_listen == event_id:
		# 【关键】获取效果应用的目标列表（支持目标选择策略）
		var effect_targets: Array[Node] = _get_effect_targets(status_holder, context)
		
		# 为所有目标应用效果
		for target in effect_targets:
			if is_instance_valid(target):
				_apply_all_effects_to_target(target, context)
```

### 建议
统一为一个字段 `trigger_on_events: Array[StringName]`，移除 `event_to_listen`。

---

## 5. 生命周期管理问题

### 问题描述
`GameplayStatusInstance` 是 `RefCounted` 类型，但它创建的计时器（`Timer`）是 `Node` 类型，需要添加到场景树中。计时器的生命周期依赖于 `owner_component`（一个 `Node`）。

### 代码位置
```7:20:addons/godot_gameplay_abilities/scripts/status/gameplay_status_instance.gd
var status_data: GameplayStatusData
var owner_component: Node  ## 状态组件（采用鸭子类型，不依赖具体类型）
var instigator: Node  ## 施加者
var stacks: int = 1

# 智能处理器追踪已注册的监听器
var stateful_effects: Array[GameplayEffect] = []  # 追踪需要在 remove 时调用的效果

var _duration_timer: Timer = null  # 用于自动移除的计时器
var _periodic_timer: Timer = null  # 周期性效果计时器（状态只有一个 period）
var _is_connected_to_event_bus: bool = false  # 是否已连接到统一事件系统
var _initial_context: Dictionary = {}  # 保存应用时的上下文（用于周期性效果）
var _cue_instance: GameplayCue = null  # 保存克隆的 Cue 实例（用于停止时清理）
var _applied_attribute_modifiers: Array[GameplayAttributeModifier] = []  # 存储已应用的属性修改器（用于移除时清理）
```

### 影响
- 如果 `owner_component` 被释放，计时器可能无法正确清理
- 状态实例的生命周期与 Node 的生命周期耦合，不够灵活

### 建议
- 使用 `SceneTreeTimer` 替代 `Timer`（不需要添加到场景树）
- 或者在 `GameplayStatusComponent` 中统一管理所有计时器

---

## 6. GameplayEffect 没有 remove 方法

### 问题描述
状态系统期望效果有 `remove` 方法用于清理，但 `GameplayEffect` 基类中并没有定义 `remove` 方法。

### 代码位置
```298:309:addons/godot_gameplay_abilities/scripts/status/gameplay_status_instance.gd
## 移除所有效果
func _remove_all_effects() -> void:
	var target = get_target_entity()
	if not is_instance_valid(target):
		return
	
	# 迭代所有效果克隆，统一调用 remove()
	for effect_clone in stateful_effects:
		if is_instance_valid(effect_clone):
			effect_clone.remove(target, instigator)
	
	stateful_effects.clear()
```

### 影响
- 如果效果没有实现 `remove` 方法，调用会失败
- 无法保证效果的清理逻辑被执行

### 建议
- 在 `GameplayEffect` 基类中添加 `remove` 方法（默认空实现）
- 或者检查方法是否存在再调用：`if effect_clone.has_method("remove")`

---

## 7. 事件总线连接的性能问题

### 问题描述
每个状态实例都会连接到 `AbilityEventBus.game_event_occurred` 信号。如果有大量状态，会有大量连接，可能导致性能问题。

### 代码位置
```84:90:addons/godot_gameplay_abilities/scripts/status/gameplay_status_instance.gd
	# 5. 连接到统一游戏事件系统
	# 如果状态配置了 trigger_on_events 或 event_to_listen，需要连接事件总线
	if not _is_connected_to_event_bus:
		var needs_event_bus = not status_data.trigger_on_events.is_empty() or status_data.event_to_listen != &""
		if needs_event_bus:
			AbilityEventBus.game_event_occurred.connect(_on_game_event_occurred)
			_is_connected_to_event_bus = true
```

### 影响
- 每个状态实例都创建一个连接，如果有 100 个状态，就有 100 个连接
- 事件触发时，所有连接的状态都会收到事件，即使它们不关心该事件

### 建议
- 在 `GameplayStatusComponent` 中统一管理事件连接，只连接一次
- 在组件中过滤事件，只转发给相关状态

---

## 8. 目标选择策略未实现

### 问题描述
代码注释中提到"支持目标选择策略"，但实际实现中 `_get_effect_targets` 总是返回状态持有者，不支持真正的目标选择。

### 代码位置
```245:252:addons/godot_gameplay_abilities/scripts/status/gameplay_status_instance.gd
## 获取效果应用的目标列表
## 注意：状态不再支持目标选择策略，效果直接应用到状态持有者
## [param] status_holder: Node 状态持有者（状态被应用到的实体）
## [param] context: Dictionary 上下文信息
## [return] Array[Node] 目标列表（始终只包含状态持有者）
func _get_effect_targets(status_holder: Node, context: Dictionary) -> Array[Node]:
	# 状态效果直接应用到状态持有者（不再支持目标选择策略）
	return [status_holder]
```

### 影响
- 无法实现"状态效果影响周围敌人"等需求
- 代码注释与实际实现不一致，容易误导

### 建议
- 如果需要目标选择，在 `GameplayStatusData` 中添加 `targeting_strategy` 字段
- 或者明确说明状态不支持目标选择，移除相关注释

---

## 9. 上下文管理不够灵活

### 问题描述
`_initial_context` 在状态应用时保存，用于周期性效果。但这种方式可能不够灵活，无法处理动态变化的上下文。

### 代码位置
```55:57:addons/godot_gameplay_abilities/scripts/status/gameplay_status_instance.gd
func apply(context: Dictionary = {}) -> void:
	# 保存初始上下文（用于周期性效果，如魔法场引用）
	_initial_context = context.duplicate()
```

### 影响
- 周期性效果无法获取最新的上下文信息
- 例如：如果施法者死亡，周期性效果仍然使用旧的施法者引用

### 建议
- 在周期性效果触发时，重新构建上下文
- 或者提供上下文更新机制

---

## 10. 状态移除时的事件处理不完善

### 问题描述
状态移除时，虽然会触发 `status_removed` 事件，但可能缺少一些清理逻辑。

### 代码位置
```104:141:addons/godot_gameplay_abilities/scripts/status/gameplay_status_instance.gd
## 状态被移除时，移除所有效果
func remove() -> void:
	# 1. 停止持续时间计时器
	if is_instance_valid(_duration_timer):
		_duration_timer.stop()
		_duration_timer.queue_free()
		_duration_timer = null

	# 2. 移除所有效果
	_remove_all_effects()

	# 3. 停止周期性计时器
	if is_instance_valid(_periodic_timer):
		_periodic_timer.stop()
		_periodic_timer.queue_free()
		_periodic_timer = null
	
	# 4. 断开统一游戏事件系统的连接
	if _is_connected_to_event_bus:
		if AbilityEventBus.game_event_occurred.is_connected(_on_game_event_occurred):
			AbilityEventBus.game_event_occurred.disconnect(_on_game_event_occurred)
		_is_connected_to_event_bus = false
	
	# 5. 移除状态标签（标签系统集成）
	_remove_status_tags()
	
	# 6. 移除属性修改器（清理属性修改）
	_unregister_attribute_modifiers()
	
	# 7. 移除技能行为修改器（清理修改器）
	_unregister_ability_modifiers()
	
	# 8. 停止状态 Cue（清理视觉反馈）
	_stop_status_cue()
	
	# 8. 发出完成信号（持续状态在移除时完成）
	status_completed.emit(self)
```

### 影响
- 如果 `owner_component` 已经被释放，某些清理操作可能失败
- 缺少错误处理和日志记录

### 建议
- 添加更多的有效性检查
- 使用 `is_instance_valid` 检查所有依赖对象

---

## 11. 状态优先级机制可能不够灵活

### 问题描述
状态优先级使用简单的整数比较，可能无法处理复杂的互斥关系。

### 代码位置
```142:165:addons/godot_gameplay_abilities/scripts/components/gameplay_status_component.gd
## 处理已有状态的优先级比较
## [return] bool 是否允许继续后续流程（false 表示应直接拒绝新状态）
func _handle_priority_for_existing_status(status_id: StringName, gsd: GameplayStatusData) -> bool:
	if not _active_statuses.has(status_id):
		return true
	
	var existing_instance: GameplayStatusInstance = _active_statuses[status_id]
	if not is_instance_valid(existing_instance) or not is_instance_valid(existing_instance.status_data):
		# 旧实例异常时，直接移除并允许新状态进入
		_active_statuses.erase(status_id)
		return true
	
	var existing_priority: int = existing_instance.status_data.priority
	
	if gsd.priority > existing_priority:
		# 新状态优先级更高，移除旧状态
		remove_status(status_id)
		return true
	elif gsd.priority < existing_priority:
		# 旧状态优先级更高，忽略新状态
		return false
	
	# 优先级相同，继续后续堆叠逻辑
	return true
```

### 影响
- 无法实现"状态A和状态B互斥，但优先级相同"等复杂关系
- 只能通过标签系统实现互斥，但标签系统可能不够精确

### 建议
- 考虑使用标签系统或互斥组来实现更灵活的互斥关系
- 或者添加 `mutually_exclusive_with: Array[StringName]` 字段

---

## 总结

### 严重程度分类

**高优先级（影响功能正确性）：**
1. 效果分类不清晰（问题1）
2. add_stack 会重新触发瞬时效果（问题2）
3. only_stateful 参数未实现（问题3）
4. GameplayEffect 没有 remove 方法（问题6）

**中优先级（影响性能和可维护性）：**
5. 事件监听机制重复（问题4）
6. 事件总线连接的性能问题（问题7）
7. 生命周期管理问题（问题5）

**低优先级（影响扩展性）：**
8. 目标选择策略未实现（问题8）
9. 上下文管理不够灵活（问题9）
10. 状态优先级机制可能不够灵活（问题11）

### 建议的改进方向

1. **重构效果分类**：分离 `instant_effects` 和 `stateful_effects`
2. **统一事件机制**：移除 `event_to_listen`，统一使用 `trigger_on_events`
3. **优化事件连接**：在组件级别统一管理事件连接
4. **完善生命周期管理**：使用 `SceneTreeTimer` 或统一管理计时器
5. **添加 remove 方法**：在 `GameplayEffect` 基类中添加 `remove` 方法

