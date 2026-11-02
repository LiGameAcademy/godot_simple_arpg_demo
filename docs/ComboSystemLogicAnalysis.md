# 连击系统逻辑分析

## 📋 问题梳理

### 1. BTSwitch 的超时逻辑

**问题**：`BTSwitch` 不应该包含超时重置逻辑。

**原因**：
- `BTSwitch` 的职责是**根据索引选择子节点**，这是纯粹的调度逻辑
- 超时应该由**连击段内部的 `BTWaitSignal`** 返回 `FAILURE` 来处理
- 职责分离：选择器只负责选择，超时由等待节点处理

**解决方案**：
- ✅ 已移除 `BTSwitch` 中的 `expiry_key` 和超时检查逻辑
- `BTSwitch` 现在只负责根据 `combo_index` 选择对应的子节点

### 2. GameplayAbilityInstance.try_activate 的实现

**当前实现**：
```gdscript
if is_active:
    _blackboard.set_var("event_input_received", true)
    return true
```

**分析**：
- ✅ **正确**：当技能已经在运行时，设置 `event_input_received = true` 用于连击输入
- ✅ **正确**：返回 `true` 表示"处理成功"（即使没有真正激活新技能）

**逻辑流程**：
1. 第一次触发：`is_active = false` → 正常激活技能
2. 连击输入：`is_active = true` → 设置信号 → 返回 `true`（表示输入已接收）

### 3. AbilityNodeSetComboIcon 的图标存储

**当前实现**：
```gdscript
blackboard.set_var("combo_next_icon", icon_texture)
ability.ability_data_changed.emit(ability)
```

**问题**：图标存在黑板上，但 `get_current_icon()` 没有读取。

**解决方案**：
- ✅ 已修改 `get_current_icon()` 优先读取 `combo_next_icon`
- ✅ `AbilityButton` 已监听 `ability_data_changed` 信号并更新图标

### 4. 连击行为树逻辑

**当前结构**：
```
Root: Sequence
├─ Cost (消耗)
├─ RepeatUntilFailure
│  └─ Switch (根据 combo_index 选择段)
│     ├─ 段1: [执行段树 -> AdvanceCombo -> SetIcon]
│     ├─ 段2: [执行段树 -> AdvanceCombo -> SetIcon]
│     └─ 段3: [执行段树 -> AdvanceCombo -> SetIcon]
└─ Cooldown (冷却)
```

**问题分析**：

1. **超时处理位置**：
   - ❌ 错误：在 `BTSwitch` 中处理超时
   - ✅ 正确：在连击段的 `BTWaitSignal` 中处理超时

2. **循环逻辑**：
   - ✅ `RepeatUntilFailure` 循环执行 `Switch`
   - ✅ `Switch` 成功 → `RepeatUntilFailure` 继续循环
   - ✅ `Switch` 失败 → `RepeatUntilFailure` 返回失败 → 进入 CD

3. **索引推进时机**：
   - ✅ 在每段执行完成后推进（`AdvanceCombo`）
   - ✅ 设置过期时间（用于窗口期）

## 🔄 正确的连击流程

### 第一次触发

```
玩家按下攻击键
    ↓
try_activate() → is_active = false
    ↓
Cost (检查消耗)
    ↓
RepeatUntilFailure
    ↓
Switch (combo_index = 0) → 选择段1
    ↓
段1执行：
  ├─ 前摇 (BTTagScope: State.Casting, Block.Movement)
  ├─ 打击 (BTTagScope: State.Attacking, Block.Movement, Block.Rotation)
  └─ 后摇 (BTTagScope: State.Recovery)
      └─ BTWaitSignal (等待输入，timeout = 0.5s)
          ├─ 收到输入 → SUCCESS → 继续
          └─ 超时 → FAILURE → 停止
    ↓
AdvanceCombo (推进索引，设置过期时间)
    ↓
SetComboIcon (更新 UI 图标)
    ↓
Switch 返回 SUCCESS
    ↓
RepeatUntilFailure: SUCCESS → 重置 Switch → 继续循环 (RUNNING)
```

### 连击输入（在窗口期内）

```
玩家再次按下攻击键
    ↓
try_activate() → is_active = true
    ↓
设置 event_input_received = true
    ↓
BTWaitSignal 检测到信号 → SUCCESS
    ↓
Switch 返回 SUCCESS
    ↓
RepeatUntilFailure: SUCCESS → 重置 Switch → 继续循环
    ↓
Switch (combo_index = 1) → 选择段2
    ↓
段2执行...
```

### 超时（窗口期外）

```
BTWaitSignal 等待中...
    ↓
超时 (timeout = 0.5s)
    ↓
BTWaitSignal 返回 FAILURE
    ↓
段1的 Sequence 返回 FAILURE
    ↓
Switch 返回 FAILURE
    ↓
RepeatUntilFailure: FAILURE → 停止循环 → 返回 FAILURE
    ↓
Root Sequence: FAILURE → 不执行 Cooldown？
```

**问题**：如果 `RepeatUntilFailure` 返回 `FAILURE`，`Root Sequence` 会中断，不会执行 `Cooldown`。

**解决方案**：需要调整结构，确保无论成功还是失败都执行 CD。

## 🛠️ 修复方案

### 方案 1：使用 Selector 包裹

```
Root: Sequence
├─ Cost
├─ Selector
│  ├─ RepeatUntilFailure(Switch) → SUCCESS
│  └─ AlwaysSuccess → SUCCESS (确保继续)
└─ Cooldown
```

### 方案 2：在 RepeatUntilFailure 内部处理 CD

```
Root: Sequence
├─ Cost
└─ RepeatUntilFailure
   └─ Sequence
      ├─ Switch
      └─ Cooldown (在每次循环后执行？不对)
```

### 方案 3：使用 Decorator 包裹（推荐）

```
Root: Sequence
├─ Cost
├─ BTRepeatUntilFailure
│  └─ Switch
└─ Cooldown (无论成功失败都执行)
```

**问题**：`Sequence` 在收到 `FAILURE` 时会中断，不执行后续节点。

### 方案 4：修改 RepeatUntilFailure 的行为（最佳）

让 `RepeatUntilFailure` 在失败时返回 `SUCCESS`，但标记一个状态，然后在外部检查：

```gdscript
# RepeatUntilFailure 失败时
if result == Status.FAILURE:
    blackboard.set_var("combo_timed_out", true)
    return Status.SUCCESS  # 返回成功，让 Sequence 继续
```

然后在 `Cooldown` 节点中检查这个标记。

### 方案 5：使用 Inverter（最简单）

```
Root: Sequence
├─ Cost
├─ BTInverter
│  └─ BTRepeatUntilFailure
│     └─ Switch
└─ Cooldown
```

**逻辑**：
- `RepeatUntilFailure` 失败 → 返回 `FAILURE`
- `BTInverter` 反转 → 返回 `SUCCESS`
- `Sequence` 继续 → 执行 `Cooldown`

但这样会改变语义，不够清晰。

### 方案 6：修改 RepeatUntilFailure 返回 SUCCESS（推荐）

**最佳方案**：让 `RepeatUntilFailure` 在失败时也返回 `SUCCESS`，表示"循环已结束"（无论是成功结束还是失败结束）。

```gdscript
Status.FAILURE:
    # 子节点失败，停止循环
    # 但返回 SUCCESS 表示"循环已正常结束"（无论成功还是失败）
    child.reset(instance)
    reset(instance)
    return Status.SUCCESS  # 改为返回 SUCCESS
```

这样 `Sequence` 会继续执行 `Cooldown`。

## 📝 最终推荐方案

**修改 `BTRepeatUntilFailure`**：失败时返回 `SUCCESS`，表示"循环已结束"。

**理由**：
1. 语义清晰：`RepeatUntilFailure` 的职责是"循环直到失败"，失败时表示"循环已正常结束"
2. 结构简单：不需要额外的装饰器或条件判断
3. 符合预期：无论成功还是失败，都应该执行 CD
4. 可选标记：在黑板上设置 `repeat_ended_by_failure = true` 用于区分结束原因

## ✅ 已完成的修改

1. ✅ `BTSwitch` - 移除超时逻辑，只负责根据索引选择子节点
2. ✅ `GameplayAbilityInstance.get_current_icon()` - 优先读取 `combo_next_icon`
3. ✅ `AbilityButton` - 监听 `ability_data_changed` 信号并更新图标
4. ✅ `BTRepeatUntilFailure` - 失败时返回 `SUCCESS`，确保执行 CD
5. ✅ `ComboAbilityDefinition` - 移除 `expiry_key` 引用，更新注释

## 🔄 完整的连击流程（修复后）

### 第一次触发
```
玩家按下攻击键
    ↓
try_activate() → is_active = false → 正常激活
    ↓
Cost (检查消耗)
    ↓
RepeatUntilFailure
    ↓
Switch (combo_index = 0) → 选择段1
    ↓
段1执行：
  ├─ 前摇 (BTTagScope: State.Casting, Block.Movement)
  ├─ 打击 (BTTagScope: State.Attacking, Block.Movement, Block.Rotation)
  └─ 后摇 (BTTagScope: State.Recovery)
      └─ BTWaitSignal (等待输入，timeout = 0.5s)
          ├─ 收到输入 → SUCCESS → 继续
          └─ 超时 → FAILURE → 停止
    ↓
AdvanceCombo (推进索引，设置过期时间)
    ↓
SetComboIcon (更新 UI 图标，发出 ability_data_changed 信号)
    ↓
Switch 返回 SUCCESS
    ↓
RepeatUntilFailure: SUCCESS → 重置 Switch → 继续循环 (RUNNING)
```

### 连击输入（窗口期内）
```
玩家再次按下攻击键
    ↓
try_activate() → is_active = true
    ↓
设置 event_input_received = true
    ↓
BTWaitSignal 检测到信号 → SUCCESS
    ↓
Switch 返回 SUCCESS
    ↓
RepeatUntilFailure: SUCCESS → 重置 Switch → 继续循环 (RUNNING)
    ↓
Switch (combo_index = 1) → 选择段2
    ↓
段2执行...
```

### 超时（窗口期外）
```
BTWaitSignal 等待中...
    ↓
超时 (timeout = 0.5s)
    ↓
BTWaitSignal 返回 FAILURE
    ↓
段1的 Sequence 返回 FAILURE
    ↓
Switch 返回 FAILURE
    ↓
RepeatUntilFailure: FAILURE → 停止循环 → 返回 SUCCESS（循环已结束）
    ↓
Root Sequence: SUCCESS → 继续执行
    ↓
Cooldown (应用冷却)
    ↓
技能完成
```

## 🎯 关键设计决策

1. **BTSwitch 职责单一**：只负责根据索引选择子节点，不处理超时
2. **超时由 BTWaitSignal 处理**：在连击段内部处理超时，返回 FAILURE
3. **RepeatUntilFailure 返回 SUCCESS**：失败时返回 SUCCESS 表示"循环已结束"，确保执行 CD
4. **图标更新机制**：通过 `ability_data_changed` 信号通知 UI 更新
5. **输入处理**：在 `try_activate` 中处理连击输入，设置 `event_input_received`

