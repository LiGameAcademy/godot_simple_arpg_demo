# 游戏手感系统 (Game Feel System)

## 概述

`GameFeelManager` 是一个业务层单例管理器（位于 `scripts/systems/`），负责增强战斗中的手感反馈，包括：

- **顿帧 (HitStop)**：在命中瞬间暂停游戏时间，增强打击感
- **屏幕震动 (Screen Shake)**：在命中时震动相机，增强冲击感

## 功能特性

### 1. 顿帧 (HitStop)

顿帧通过在命中瞬间降低 `Engine.time_scale` 来实现，让游戏短暂"暂停"，增强打击感。

**自动触发**：
- 当玩家造成伤害时，自动根据伤害值触发顿帧
- 伤害越大，顿帧时间越长

**手动触发**：
```gdscript
# 触发 0.1 秒的顿帧（完全暂停）
GameFeelManager.trigger_hit_stop(0.1, 0.0)

# 触发 0.15 秒的慢动作（50% 速度）
GameFeelManager.trigger_hit_stop(0.15, 0.5)
```

### 2. 屏幕震动 (Screen Shake)

屏幕震动通过随机偏移相机位置来实现，增强冲击感。

**自动触发**：
- 当玩家造成伤害时，自动根据伤害值触发屏幕震动
- 伤害越大，震动强度越大

**手动触发**：
```gdscript
# 触发默认强度的屏幕震动
GameFeelManager.trigger_screen_shake()

# 触发自定义强度和时长的屏幕震动
GameFeelManager.trigger_screen_shake(1.0, 0.3)
```

## 配置参数

在 `GameFeelManager` 中可以配置以下参数：

- `enable_hit_stop: bool = true` - 是否启用顿帧
- `enable_screen_shake: bool = true` - 是否启用屏幕震动
- `default_hit_stop_duration: float = 0.1` - 默认顿帧时长（秒）
- `default_shake_intensity: float = 0.5` - 默认屏幕震动强度
- `default_shake_duration: float = 0.2` - 默认屏幕震动时长（秒）
- `max_shake_intensity: float = 2.0` - 最大屏幕震动强度（防止过度震动）

## 项目实战：战斧命中顿帧

在战斧命中时，可以手动触发更强的顿帧效果：

```gdscript
# 在 GE_ApplyDamage 或技能效果中
func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
    # ... 应用伤害 ...
    
    # 如果是重击技能，触发更强的顿帧
    if ability_id == "heavy_attack":
        GameFeelManager.trigger_hit_stop(0.15, 0.0)  # 0.15 秒完全暂停
        GameFeelManager.trigger_screen_shake(1.2, 0.3)  # 更强的震动
```

## 架构设计

### 纯业务逻辑层

`GameFeelManager` 是纯业务逻辑层实现，不依赖具体场景结构：

- **顿帧**：直接操作 `Engine.time_scale`
- **屏幕震动**：通过 `AbilityEventBus` 发送事件，由场景层（`main.gd`）监听并应用

### 事件驱动

屏幕震动通过事件系统实现解耦：

1. `GameFeelManager` 触发 `camera_offset_update` 事件
2. `main.gd` 监听事件并应用相机偏移
3. 场景层负责实际的相机位置更新

## 注意事项

1. **顿帧叠加**：如果多个顿帧同时触发，会取较长的时长
2. **震动叠加**：如果多个震动同时触发，会取较大的强度
3. **性能影响**：顿帧会影响所有使用 `Engine.time_scale` 的系统，注意与其他系统的兼容性
4. **相机偏移**：屏幕震动需要场景层正确实现相机偏移应用逻辑

