# ToggleAbility 与 ChannelingAbility 设计分析

## 当前设计问题

### 1. ToggleAbility 的设计问题

**当前实现**：
- `is_toggled_on()` 默认实现检查 `_current_casting_ability_id == ability_id`
- `_on_cast()` 方法用于状态系统（应用/移除状态），但逻辑有问题
- 设计理念不清晰：是"可以切换的技能"还是"基于状态的切换技能"？

**问题**：
1. **状态管理不一致**：`ToggleAbility` 依赖 `_current_casting_ability_id`，但 `ChannelingAbility` 使用自己的 `_channeling_state`
2. **`_on_cast()` 逻辑错误**：检查 `not is_toggled_on()` 时认为是"关闭"，但实际上应该是"开启"
   ```gdscript
   if not is_toggled_on(ability_comp):
       # 关闭：移除开启状态，应用关闭状态  <- 逻辑错误！
       # 如果 is_toggled_on() 返回 false，说明技能是关闭的，应该开启，而不是关闭
   ```
3. **职责不清晰**：`ToggleAbility` 应该是一个通用的切换技能基类，但目前的实现似乎不够通用
4. **`_on_cast()` 未被调用**：`ChannelingAbility` 完全重写了 `_on_cast()`，没有调用父类，导致 `ToggleAbility._on_cast()` 的状态逻辑从未执行

### 2. ChannelingAbility 的设计问题

**当前实现**：
- 继承自 `ToggleAbility`，但完全重写了 `_on_cast()`，没有调用父类
- 使用自己的状态管理 `_channeling_state`，而不是依赖 `_current_casting_ability_id`
- `is_toggled_on()` 重写为检查 `_channeling_state.get("is_active", false)`

**问题**：
1. **继承关系混乱**：`ChannelingAbility` 虽然继承自 `ToggleAbility`，但几乎完全独立实现
2. **状态管理重复**：两套状态管理系统（`_current_casting_ability_id` 和 `_channeling_state`）
3. **职责不清晰**：`ChannelingAbility` 应该代表什么？是"引导技能"还是"切换式引导技能"？

## 设计理念分析

### ToggleAbility 应该代表什么？

**选项 1：通用的切换技能基类**
- 可以主动开关的技能（如光环、持续效果）
- 不关心具体实现，只提供切换框架
- 子类负责实现具体的开启/关闭逻辑

**选项 2：基于状态的切换技能**
- 通过状态系统（Status）实现切换
- `_on_cast()` 负责应用/移除状态
- 适合简单的 Buff/Debuff 切换

**当前实现偏向选项 2，但不够完善**

### ChannelingAbility 应该代表什么？

**选项 1：引导技能（Channeling）**
- 持续施法，周期触发
- 可以被打断（移动、松开按键等）
- 可以是切换式（Toggle）或按住维持式（Hold）

**选项 2：切换式引导技能**
- 继承自 `ToggleAbility`，表示可以切换的引导技能
- 但目前的实现中，`stop_on_input_release = true` 时是按住维持式，不是切换式

**当前实现混合了两种模式，导致混乱**

## 建议的设计方案

### 方案 1：分离关注点（推荐）

**ToggleAbility**：
- 纯粹的切换技能基类
- 不关心具体实现，只提供切换框架
- 子类负责实现 `is_toggled_on()` 和 `_toggle_off()`
- 移除 `_on_cast()` 中的状态系统逻辑（这是子类的职责）

**ChannelingAbility**：
- 引导技能基类（不继承 `ToggleAbility`）
- 支持两种模式：
  - **切换式（Toggle）**：按一下开启，再按一下关闭
  - **按住维持式（Hold）**：按住开启，松开关闭
- 通过 `stop_on_input_release` 控制模式

**ToggleChannelingAbility**（新类）：
- 继承自 `ChannelingAbility` 和 `ToggleAbility`（多重继承？）
- 或者：`ChannelingAbility` 继承 `ToggleAbility`，但只在 `stop_on_input_release = false` 时启用切换功能

### 方案 2：统一状态管理

**ToggleAbility**：
- 提供统一的状态管理接口
- 子类通过重写 `is_toggled_on()` 提供状态检查
- `_on_cast()` 根据 `is_toggled_on()` 的结果决定开启或关闭

**ChannelingAbility**：
- 继承自 `ToggleAbility`
- 使用 `_channeling_state` 管理状态，但通过 `is_toggled_on()` 暴露给父类
- `_on_cast()` 调用父类方法处理切换逻辑

### 方案 3：简化设计（最简单）

**ToggleAbility**：
- 移除 `_on_cast()` 中的状态系统逻辑
- 只提供切换框架：`is_toggled_on()`、`can_toggle_off()`、`_toggle_off()`
- 子类完全负责实现开启/关闭逻辑

**ChannelingAbility**：
- 不继承 `ToggleAbility`，直接继承 `ActiveAbility`
- 自己实现切换逻辑（如果需要）
- 更清晰、更独立

## 当前问题总结

1. **状态管理不一致**：`ToggleAbility` 使用 `_current_casting_ability_id`，`ChannelingAbility` 使用 `_channeling_state`
2. **职责不清晰**：两个类的职责边界模糊
3. **继承关系混乱**：`ChannelingAbility` 继承 `ToggleAbility`，但几乎完全独立实现
4. **`_on_cast()` 逻辑错误**：`ToggleAbility._on_cast()` 的逻辑有问题
   - `if not is_toggled_on()` 时认为是"关闭"，但实际上应该是"开启"
   - 这个逻辑是反的！
5. **`_on_cast()` 未被调用**：`ChannelingAbility` 完全重写了 `_on_cast()`，没有调用父类
6. **切换功能不完善**：切换逻辑复杂，容易出错
7. **设计理念冲突**：
   - `ToggleAbility` 设计为"基于状态的切换技能"（通过 Status 系统）
   - `ChannelingAbility` 设计为"引导技能"（通过 Timer 和状态管理）
   - 两者设计理念不同，强行继承导致混乱

## 建议

我建议采用**方案 1（分离关注点）**或**方案 3（简化设计）**：

- **方案 1** 更符合面向对象设计原则，职责清晰
- **方案 3** 更简单，更容易理解和维护

你更倾向于哪种方案？或者你有其他想法？

---

## 重构完成（采用方案 1 的"或者"部分）

根据用户选择，我们采用了**方案 1 的"或者"部分**：`ChannelingAbility` 继承 `ToggleAbility`，但只在 `stop_on_input_release = false` 时启用切换功能。

### 重构内容

1. **修复 `ToggleAbility._on_cast()` 的逻辑错误**
   - 移除了错误的切换逻辑
   - `_on_cast()` 现在只处理开启时的状态应用
   - 关闭逻辑在 `_toggle_off()` 中处理

2. **完善 `ToggleAbility._toggle_off()`**
   - 添加了状态系统的处理（移除开启状态，应用关闭状态）
   - 然后调用 `cancel_ability` 取消技能执行

3. **统一状态管理**
   - `ChannelingAbility` 通过 `is_toggled_on()` 暴露状态给父类
   - `is_toggled_on()` 检查 `_channeling_state.get("is_active", false)`
   - `can_toggle_off()` 只在 `stop_on_input_release = false` 时返回 `true`

4. **确保 `ChannelingAbility` 正确使用 `ToggleAbility` 的切换框架**
   - `_on_cast()` 调用父类方法处理状态系统
   - `_toggle_off()` 先中断引导，然后调用父类方法处理状态系统和取消技能

### 设计说明

- **切换式引导**（`stop_on_input_release = false`）：可以主动关闭，使用 `ToggleAbility` 的切换框架
- **按住维持式引导**（`stop_on_input_release = true`）：只能被动关闭（松开按键），不使用切换框架

这样的设计既保持了 `ChannelingAbility` 的灵活性，又充分利用了 `ToggleAbility` 的切换功能。

