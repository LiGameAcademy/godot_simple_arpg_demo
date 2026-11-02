# 技能执行流程设计文档

## 概述

本文档描述了重构后的技能系统执行流程，明确了各层级的职责和调用关系。

## 调用链概览

```
GameplayAbilityComponent.commit_cast()
  ↓
GameplayAbility.commit_cast() (检查消耗)
  ↓
GameplayAbilityComponent.apply_ability_effect()
  ↓
GameplayAbility.cast()
  ↓
ActiveAbility._on_cast()
  ↓
ActiveAbility._apply_initial_statuses() (应用状态)
  ↓
ActiveAbility._start_execution_timer() (启动计时器，可选)
  ↓
ActiveAbility._check_ability_completion() (完成检查)
  ↓
GameplayAbilityComponent._on_ability_completed()
  ↓
GameplayAbilityComponent._end_ability()
```

## 各层级职责

### 1. GameplayAbilityComponent（技能组件层）

**职责：**
- 管理技能列表和状态
- 处理输入和外部调用
- 管理 `_current_casting_ability_id`
- 处理前摇（cast_point）计时器
- 订阅技能完成信号

**关键方法：**
- `commit_cast()`: 提交施法请求，检查冷却、消耗，设置 `_current_casting_ability_id`
- `apply_ability_effect()`: 应用技能效果，调用 `ability_data.cast()`
- `_on_ability_completed()`: 处理技能完成信号，调用 `_end_ability()`

### 2. GameplayAbility（技能基类）

**职责：**
- 定义技能的基础接口
- 管理技能状态（冷却、标签等）
- 提供技能完成信号

**关键方法：**
- `commit_cast()`: 检查消耗（子类可重写）
- `cast()`: 清理旧状态，调用 `_on_cast()`

### 3. ActiveAbility（主动技能基类）

**职责：**
- 应用状态（Status）
- 管理执行时间（execution_duration）
- 自动完成技能（通过执行计时器）

**关键方法：**
- `_on_cast()`: **核心方法**，负责应用状态和启动执行计时器
  - 调用 `_apply_initial_statuses()` 应用状态
  - 根据 `execution_duration` 决定是否启动计时器或立即完成
- `_apply_initial_statuses()`: **提取的独立方法**，应用初始状态
  - 构建状态上下文
  - 遍历 `statuses` 数组，调用 `_apply_status()` 应用每个状态
- `_start_execution_timer()`: 启动执行计时器，在时间到期时自动完成
- `_apply_status()`: 应用单个状态到施法者

**设计原则：**
- `_on_cast()` 只负责应用状态，不直接调用完成检查
- 完成检查由 `_start_execution_timer()` 或子类自己管理
- 状态应用逻辑提取为 `_apply_initial_statuses()`，便于子类复用

### 4. ChannelingAbility（引导技能）

**职责：**
- 管理引导状态（开启/关闭）
- 处理周期性消耗（tick_costs）
- 处理中断逻辑

**关键方法：**
- `_on_cast()`: 重写父类方法
  - 调用 `_apply_initial_statuses()` 应用状态（**不调用 super._on_cast()**）
  - 启动引导逻辑（`_start_channeling()`）
  - **不启动执行计时器**（引导技能自己管理生命周期）
- `_start_execution_timer()`: 重写为空方法，阻止基类启动计时器
- `stop_channeling()`: 手动停止引导，调用 `_check_ability_completion()`

**设计原则：**
- 不调用 `super._on_cast()`，避免触发基类的执行计时器
- 使用 `_apply_initial_statuses()` 复用状态应用逻辑
- 自己管理生命周期，通过 `stop_channeling()` 完成技能

## 关键设计决策

### 1. 状态应用逻辑提取

**问题：** 子类需要应用状态，但不希望触发基类的完成检查逻辑。

**解决方案：** 将状态应用逻辑提取为 `_apply_initial_statuses()` 独立方法。

**优势：**
- 子类可以复用状态应用逻辑，无需复制代码
- 基类保持职责单一（`_on_cast()` 只负责应用状态）
- 子类可以灵活控制完成检查时机

### 2. 完成检查分离

**问题：** `_on_cast()` 中直接调用 `_check_ability_completion()` 导致副作用。

**解决方案：** 
- `_on_cast()` 只负责应用状态
- 完成检查由 `_start_execution_timer()` 或子类自己管理
- 瞬时技能（`execution_duration == 0.0`）在 `_on_cast()` 中立即完成

**优势：**
- 调用链更清晰，职责分离
- 子类可以灵活控制完成时机
- 避免副作用（如 `_current_casting_ability_id` 被过早清空）

### 3. 引导技能的特殊处理

**问题：** 引导技能需要保持 `_current_casting_ability_id` 直到手动停止。

**解决方案：**
- `ChannelingAbility._on_cast()` 不调用 `super._on_cast()`
- 使用 `_apply_initial_statuses()` 复用状态应用逻辑
- 重写 `_start_execution_timer()` 为空方法，阻止自动完成
- 通过 `stop_channeling()` 手动完成技能

**优势：**
- 引导技能可以正确保持 `_current_casting_ability_id`
- 可以正常取消引导
- 代码复用，无需复制状态应用逻辑

## 执行流程示例

### 普通主动技能

```
1. Player 按下快捷键
2. AbilityShortcutManager 发出 cast_ability_requested 信号
3. PlayerController 调用 ability_comp.try_cast_ability()
4. GameplayAbilityComponent.commit_cast()
   - 检查冷却、消耗
   - 设置 _current_casting_ability_id
   - 启动前摇计时器（如果有）
5. GameplayAbilityComponent.apply_ability_effect()
   - 调用 ability_data.cast()
6. ActiveAbility._on_cast()
   - 调用 _apply_initial_statuses() 应用状态
   - 启动执行计时器（如果 execution_duration > 0）
7. 执行计时器到期
   - 调用 _check_ability_completion()
   - 发出 ability_completed 信号
8. GameplayAbilityComponent._on_ability_completed()
   - 调用 _end_ability()
   - 清空 _current_casting_ability_id
```

### 引导技能

```
1. Player 按下快捷键（如 Sacrifice）
2. AbilityShortcutManager 发出 cast_ability_requested 信号
3. PlayerController 调用 ability_comp.try_cast_ability()
4. GameplayAbilityComponent.commit_cast()
   - 检查冷却、消耗（skip_cooldown = true）
   - 设置 _current_casting_ability_id
   - skip_cast_point_timer = true，直接应用效果
5. GameplayAbilityComponent.apply_ability_effect()
   - 调用 ability_data.cast()
6. ChannelingAbility._on_cast()
   - 调用 _apply_initial_statuses() 应用状态
   - 启动引导逻辑（_start_channeling()）
   - **不启动执行计时器**
7. 引导技能持续运行
   - 周期性扣除消耗（tick_costs）
   - 周期性应用效果（通过 Status 的 periodic_effects）
8. Player 释放按键或满足中断条件
   - 调用 stop_channeling()
   - 移除状态
   - 调用 _check_ability_completion()
   - 发出 ability_completed 信号
9. GameplayAbilityComponent._on_ability_completed()
   - 调用 _end_ability()
   - 清空 _current_casting_ability_id
```

## 最佳实践

### 对于子类开发者

1. **重写 `_on_cast()` 时：**
   - 如果需要应用状态，调用 `_apply_initial_statuses()` 而不是复制代码
   - 如果需要阻止自动完成，重写 `_start_execution_timer()` 为空方法
   - 如果需要自己管理生命周期，在适当时机调用 `_check_ability_completion()`

2. **状态应用：**
   - 使用 `_apply_initial_statuses()` 复用基类逻辑
   - 如果需要自定义上下文，可以重写此方法或直接调用 `_apply_status()`

3. **完成检查：**
   - 瞬时技能：在 `_on_cast()` 中立即调用 `_check_ability_completion()`
   - 定时技能：让基类的 `_start_execution_timer()` 处理
   - 引导技能：在 `stop_channeling()` 中调用 `_check_ability_completion()`

## 总结

重构后的调用链具有以下优势：

1. **职责清晰**：每个方法只负责一个明确的任务
2. **易于扩展**：子类可以灵活重写和组合方法
3. **代码复用**：状态应用逻辑提取为独立方法，避免重复
4. **副作用可控**：完成检查与状态应用分离，避免意外副作用
5. **调用链清晰**：从输入到完成的整个流程一目了然

