# 基于行为树的连击系统 - 高级用法

## 📋 概述

本文档介绍如何使用新的行为树节点构建更精细的连击系统，包括状态管理、动画取消和输入窗口期。

## 🏗️ 核心节点

### 1. BTTagScope（标签作用域装饰器）

**职责**：在子节点执行期间管理状态标签

**用途**：
- 标记技能状态（如 `State.Casting`, `State.Attacking`）
- 阻止某些行为（如 `Block.Movement`, `Block.Rotation`）

**示例**：
```gdscript
var tag_scope = BTTagScope.new()
tag_scope.tags = [&"State.Casting", &"Block.Movement"]
tag_scope.child = some_sequence_node
```

### 2. AbilityNodeFaceTarget（转向目标节点）

**职责**：让施法者转向目标

**配置**：
- `target_key`: 目标来源 Key（默认 `"targets"`）
- `instant`: 是否瞬间转向（默认 `false`）
- `rotation_speed`: 转向速度（弧度/秒，默认 `12.0`）
- `horizontal_only`: 是否只考虑水平方向（默认 `true`）

### 3. BTWaitSignal（等待信号节点）

**职责**：等待黑板变量变为 `true`，或超时

**配置**：
- `signal_key`: 信号 Key（默认 `"event_input_received"`）
- `timeout`: 超时时间（秒，默认 `0.8`）
- `consume_signal`: 是否消费信号（默认 `true`）

**逻辑**：
- 如果在超时前收到信号 → 返回 `SUCCESS` → 连击继续
- 如果超时 → 返回 `FAILURE` → 连击中断

### 4. BTModifyInt（修改整数变量节点）

**职责**：修改黑板中的整数变量

**操作类型**：
- `SET`: 设置为指定值
- `ADD`: 增加指定值
- `SUBTRACT`: 减少指定值

**用途**：推进连击索引（替代 `AbilityNodeAdvanceCombo`）

## 📝 连击段设计示例

### 示例：Slash_01.tres（第一段攻击）

```
Root: Sequence
│
├─ [Decorator] BTTagScope
│  └─ Tags: ["State.Casting", "Block.Movement"]
│  └─ Child: Sequence (第一阶段：前摇)
│     ├─ [Action] AbilityNodeFaceTarget
│     │  └─ instant: false
│     │  └─ rotation_speed: 12.0
│     ├─ [Action] AbilityNodePlayAnimation
│     │  └─ animation_name: "Slash_01"
│     │  └─ wait_for_finish: false
│     └─ [Action] BTWait
│        └─ duration: 0.1
│
├─ [Decorator] BTTagScope
│  └─ Tags: ["State.Attacking", "Block.Movement", "Block.Rotation"]
│  └─ Child: Sequence (第二阶段：打击)
│     ├─ [Action] AbilityNodeTargetSearch
│     │  └─ strategy: UnitTargetingStrategy
│     │  └─ write_to_key: "targets"
│     ├─ [Action] AbilityNodeApplyEffect
│     │  └─ effects: [GE_ApplyDamage]
│     │  └─ target_key: "targets"
│     └─ [Action] BTWait
│        └─ duration: 0.2
│
└─ [Decorator] BTTagScope
   └─ Tags: ["State.Recovery"]
   └─ Child: BTWaitSignal (第三阶段：后摇与衔接)
      └─ signal_key: "event_input_received"
      └─ timeout: 0.5
      └─ consume_signal: true
```

### 代码实现

```gdscript
func _build_slash_01_tree() -> BTNode:
	var root = BTSequence.new()
	
	# 第一阶段：前摇
	var windup_scope = BTTagScope.new()
	windup_scope.tags = [&"State.Casting", &"Block.Movement"]
	var windup_seq = BTSequence.new()
	
	var face_target = AbilityNodeFaceTarget.new()
	face_target.instant = false
	face_target.rotation_speed = 12.0
	
	var play_anim = AbilityNodePlayAnimation.new()
	play_anim.animation_name = &"Slash_01"
	play_anim.wait_for_finish = false
	
	var wait_windup = BTWait.new()
	wait_windup.duration = 0.1
	
	windup_seq.children = [face_target, play_anim, wait_windup]
	windup_scope.child = windup_seq
	
	# 第二阶段：打击
	var impact_scope = BTTagScope.new()
	impact_scope.tags = [&"State.Attacking", &"Block.Movement", &"Block.Rotation"]
	var impact_seq = BTSequence.new()
	
	var target_search = AbilityNodeTargetSearch.new()
	target_search.strategy = UnitTargetingStrategy.new()
	target_search.write_to_key = "targets"
	
	var apply_effect = AbilityNodeApplyEffect.new()
	apply_effect.effects = [damage_effect]
	apply_effect.target_key = "targets"
	
	var wait_impact = BTWait.new()
	wait_impact.duration = 0.2
	
	impact_seq.children = [target_search, apply_effect, wait_impact]
	impact_scope.child = impact_seq
	
	# 第三阶段：后摇与衔接
	var recovery_scope = BTTagScope.new()
	recovery_scope.tags = [&"State.Recovery"]
	
	var wait_signal = BTWaitSignal.new()
	wait_signal.signal_key = "event_input_received"
	wait_signal.timeout = 0.5
	wait_signal.consume_signal = true
	
	recovery_scope.child = wait_signal
	
	# 组装
	root.children = [windup_scope, impact_scope, recovery_scope]
	return root
```

## 🔄 连击循环逻辑

### ComboAbilityDefinition 的构建逻辑

```gdscript
func _build_combo_tree() -> BTNode:
	var root_sequence = BTSequence.new()
	
	# 1. 提交消耗
	var cost_node = AbilityNodeCommitCost.new()
	root_sequence.children.append(cost_node)
	
	# 2. Switch 选择器（根据 combo_index 选择段）
	var switch_node = BTSwitch.new()
	switch_node.variable_key = "combo_index"
	switch_node.expiry_key = "combo_expiry_time"
	
	var switch_children: Array[BTNode] = []
	for i in range(combo_steps.size()):
		var step_def = combo_steps[i]
		var is_last_step = (i == combo_steps.size() - 1)
		
		# 包装器：执行段 -> 推进索引 -> 设置图标
		var wrapper = BTSequence.new()
		
		# A. 执行段的能力树
		var step_tree = step_def.execution_tree
		if step_tree == null and step_def.has_method("_build_default_behavior_tree"):
			step_tree = step_def.call("_build_default_behavior_tree")
		if step_tree:
			wrapper.children.append(step_tree.duplicate(true))
		
		# B. 推进索引（使用 BTModifyInt）
		var advance_node = BTModifyInt.new()
		advance_node.variable_key = "combo_index"
		if is_last_step:
			advance_node.operation = BTModifyInt.Operation.SET
			advance_node.value = 0  # 重置为第一段
		else:
			advance_node.operation = BTModifyInt.Operation.ADD
			advance_node.value = 1
		wrapper.children.append(advance_node)
		
		# C. 设置过期时间（如果非终结技）
		if not is_last_step:
			var set_expiry = BTModifyInt.new()
			set_expiry.variable_key = "combo_expiry_time"
			set_expiry.operation = BTModifyInt.Operation.SET
			# 注意：这里需要计算时间戳，可能需要自定义节点
			# 或者使用 BTWait + 自定义逻辑
		
		# D. 设置下一段的图标
		var icon_node = AbilityNodeSetComboIcon.new()
		if is_last_step:
			icon_node.icon_texture = combo_steps[0].icon
		else:
			if i + 1 < combo_steps.size():
				icon_node.icon_texture = combo_steps[i+1].icon
		wrapper.children.append(icon_node)
		
		switch_children.append(wrapper)
	
	switch_node.children = switch_children
	root_sequence.children.append(switch_node)
	
	# 3. 提交冷却
	var cd_node = AbilityNodeCommitCooldown.new()
	root_sequence.children.append(cd_node)
	
	return root_sequence
```

## 🎯 输入处理

### 在玩家脚本中处理输入

```gdscript
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		# 设置信号，触发连击继续
		var ability_comp = get_component("GameplayAbilityComponent")
		if is_instance_valid(ability_comp):
			var current_ability = ability_comp.get_current_ability()
			if is_instance_valid(current_ability):
				var blackboard = current_ability.get_blackboard()
				if is_instance_valid(blackboard):
					blackboard.set_var("event_input_received", true)
```

## 📊 状态标签说明

### 常用状态标签

- `State.Casting`: 施法状态（前摇阶段）
- `State.Attacking`: 攻击状态（打击阶段）
- `State.Recovery`: 恢复状态（后摇阶段）
- `Block.Movement`: 阻止移动
- `Block.Rotation`: 阻止转向

### 标签管理

标签由 `TagManager` 管理，支持引用计数。多个节点可以同时添加相同的标签，只有在所有节点都移除后，标签才会真正移除。

## 🔧 最佳实践

1. **前摇阶段**：
   - 允许转向，但阻止移动
   - 播放动画，但不等待完成
   - 短暂等待，让动画进入关键帧

2. **打击阶段**：
   - 阻止移动和转向（表现力度）
   - 搜索目标并应用效果
   - 短暂等待，表现攻击惯性

3. **后摇阶段**：
   - 移除移动限制，允许取消后摇
   - 等待输入信号
   - 如果收到信号 → 继续连击（动画取消）
   - 如果超时 → 进入冷却

4. **动画取消**：
   - 使用 `BTWaitSignal` 实现
   - 在超时前收到输入 → 立即切换到下一段
   - 提供流畅的连击体验

## 🐛 常见问题

### Q: 标签没有正确移除

**A:** 确保 `BTTagScope` 的 `_exit` 方法被正确调用。检查行为树是否正确结束（返回 `SUCCESS` 或 `FAILURE`）。

### Q: 转向不生效

**A:** 检查：
1. Agent 是否是 `Node3D`
2. 目标是否有效
3. `horizontal_only` 设置是否正确

### Q: 输入信号不触发

**A:** 检查：
1. 信号 Key 是否正确
2. 是否在正确的时机设置信号
3. `BTWaitSignal` 是否正确注册观察者

## 📚 相关文档

- [ComboAbilityDefinition 基础用法](./ComboAbilityDefinitionUsage.md)
- [行为树系统文档](./BehaviorTreeSystem.md)
- [标签系统文档](./TagSystemIntegrationSummary.md)

