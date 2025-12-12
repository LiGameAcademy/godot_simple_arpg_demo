# ChannelingAbility 重构方案

## 目标

1. 将 `ChannelingAbility` 和 `ToggleAbility` 整合成一个类
2. 使用状态系统管理每 tick 效果和资源消耗
3. 简化继承层级

## 设计方案

### 1. 整合 ToggleAbility 和 ChannelingAbility

**新架构**：
- `ChannelingAbility` 直接继承 `ActiveAbility`
- 整合 `ToggleAbility` 的切换功能到 `ChannelingAbility` 中
- 移除 `ToggleAbility` 类（或保留作为简单的切换技能基类）

### 2. 使用状态系统管理 Tick 效果和资源消耗

**引导状态（Channeling Status）**：
- 包含周期性效果（每 tick 的效果）
- 包含周期性资源消耗（通过 `GE_ApplyCost` 实现）
- 包含完成效果（引导完成时的效果，通过事件监听实现）

**实现方式**：
- `ChannelingAbility` 在开启时应用引导状态
- 状态系统负责管理 tick 和资源消耗
- 引导状态通过 `period` 实现周期性触发
- 完成效果通过状态移除时的事件或状态完成事件实现

### 3. 新的 ChannelingAbility 设计

**属性**：
- `channeling_status: GameplayStatusData` - 引导状态（包含 tick 效果、资源消耗、完成效果）
- `is_mobile: bool` - 是否允许移动引导
- `stop_on_input_release: bool` - 是否按住维持
- `channel_duration: float` - 引导持续时间（如果状态未设置 duration）

**逻辑**：
- `_on_cast()`: 应用引导状态
- `update()`: 检查中断条件（移动、按键松开）
- `_toggle_off()`: 移除引导状态
- `is_toggled_on()`: 检查是否有引导状态

## 实现步骤

1. 创建 `GE_ApplyCost` 效果（已完成）
2. 重构 `ChannelingAbility`，整合 `ToggleAbility` 功能
3. 创建引导状态资源示例
4. 更新 `sacrifice_toggle.tres` 使用新的实现

