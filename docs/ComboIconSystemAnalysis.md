# 连击技能动态图标系统分析

## 🔍 问题分析

### 问题1：初始图标未设置

**位置**：`combo_ability_definition.gd` 的 `_initialize_blackboard()` 方法

**当前实现**：
```gdscript
func _initialize_blackboard(instance: GameplayAbilityInstance) -> void:
	instance.set_blackboard_var("combo_index", 0)
	instance.set_blackboard_var("combo_expiry_time", 0)
	instance.set_blackboard_var("combo_next_icon", null) # 初始为空，UI应显示默认图标
	# ❌ 缺少：instance.set_blackboard_var("current_icon_id", "combo_1")
```

**问题**：
- `DynamicIconFeature` 从黑板读取 `current_icon_id` 来获取图标
- 如果 `current_icon_id` 为空，`get_current_icon()` 返回 `null`
- 导致初始状态下显示的是 `_definition.icon`（默认图标），而不是第一段的图标

**影响**：
- 技能按钮初始显示默认图标，而不是第一段图标
- 用户体验不一致

### 问题2：图标更新时机不当

**位置**：`combo_ability_definition.gd` 的 `_build_combo_tree()` 方法

**当前实现**：
```gdscript
# 每段的执行顺序：
# A. 执行段的能力树（前摇、打击、后摇）
# B. BTWaitSignal 等待连击输入
# C. AbilityNodeAdvanceCombo 推进索引
# D. BTSetVar 设置下一段的图标ID  ← 在这里设置
```

**问题**：
- 图标是在段执行完成后设置的，而不是在段执行前
- 第一段执行时，`current_icon_id` 还是空的，显示默认图标
- 第一段执行完成后，才设置 `current_icon_id = "combo_2"`，显示第二段图标

**影响**：
- 第一段执行期间，UI 显示的是默认图标，而不是第一段图标
- 图标更新有延迟，用户体验不佳

### 问题3：图标ID计算逻辑

**位置**：`combo_ability_definition.gd` 第210-211行

**当前实现**：
```gdscript
if i + 1 < combo_steps.size():
	icon_node.value = "combo_%d" % (i + 2)  # i+1 对应 combo_i+2（因为从1开始）
```

**分析**：
- `i = 0`（第一段）→ 设置 `"combo_2"`（第二段图标）✅ 正确
- `i = 1`（第二段）→ 设置 `"combo_3"`（第三段图标）✅ 正确
- `i = 2`（第三段，终结技）→ 设置 `"combo_1"`（第一段图标，循环）✅ 正确

**结论**：计算逻辑是正确的，但注释可以更清晰

### 问题4：图标更新信号触发

**位置**：`ability_button.gd` 的 `_on_ability_data_changed()` 方法

**当前实现**：
```gdscript
func _on_ability_data_changed(ability_inst: GameplayAbilityInstance) -> void:
	if ability_inst == _instance:
		_update_tooltip()
		_update_icon()
```

**分析**：
- `BTSetVar` 节点设置黑板变量时，会触发 `value_changed` 信号
- `GameplayAbilityInstance` 监听该信号，并发出 `ability_data_changed` 信号
- `AbilityButton` 监听该信号并更新图标 ✅ 正确

**结论**：信号机制是正确的

## 🔧 修复方案

### 修复1：初始化时设置第一段图标

```gdscript
func _initialize_blackboard(instance: GameplayAbilityInstance) -> void:
	instance.set_blackboard_var("combo_index", 0)
	instance.set_blackboard_var("combo_expiry_time", 0)
	instance.set_blackboard_var("combo_next_icon", null)
	# ✅ 初始化第一段图标
	if combo_steps.size() > 0:
		instance.set_blackboard_var("current_icon_id", "combo_1")
	else:
		instance.set_blackboard_var("current_icon_id", null)
```

### 修复2：在段执行前设置当前段图标（可选优化）

如果希望在段执行时就显示当前段的图标，可以在每段的开始处添加一个 `BTSetVar` 节点：

```gdscript
# 在每段执行前设置当前段图标
var set_current_icon = BTSetVar.new()
set_current_icon.variable_key = "current_icon_id"
set_current_icon.value = "combo_%d" % (i + 1)
set_current_icon.node_id = "set_current_icon"
wrapper.children.insert(0, set_current_icon)  # 插入到最前面
```

**注意**：这个优化是可选的，因为当前的设计是在段执行完成后显示下一段图标，这也是合理的（提示玩家下一段是什么）。

### 修复3：改进注释

```gdscript
# D. 设置下一段的图标ID（用于UI提示）
# 注意：这里设置的是"下一段"的图标，因为当前段已经执行完成
# 例如：第一段（i=0）执行完成后，设置 combo_2，提示玩家下一段是第二段
var icon_node = BTSetVar.new()
icon_node.variable_key = "current_icon_id"
if is_last_step:
	# 如果是终结技，下一段图标重置为第一段的图标，形成闭环
	icon_node.value = "combo_1" if combo_steps.size() > 0 else null
else:
	# 如果是中间段，设置为下一段的图标ID
	# 当前段索引为 i，下一段索引为 i+1，图标ID为 combo_(i+2)（因为从1开始）
	if i + 1 < combo_steps.size():
		icon_node.value = "combo_%d" % (i + 2)
	else:
		icon_node.value = null
```

## 📊 总结

### 必须修复的问题
1. ✅ **初始化时设置第一段图标**：确保技能按钮初始显示正确的图标

### 可选优化
2. ⚠️ **在段执行前设置当前段图标**：如果希望段执行时就显示当前段图标（而不是下一段图标）

### 正确的部分
3. ✅ **图标ID计算逻辑**：计算逻辑是正确的
4. ✅ **信号机制**：图标更新信号机制是正确的

## 🎯 推荐修复方案

**最小修复**：只需修复问题1，在初始化时设置第一段图标。这样：
- 初始状态显示第一段图标 ✅
- 第一段执行完成后，显示第二段图标 ✅
- 第二段执行完成后，显示第三段图标 ✅
- 终结技执行完成后，显示第一段图标（循环）✅

**完整优化**：如果希望段执行时就显示当前段图标，可以添加修复2，但这不是必须的。

