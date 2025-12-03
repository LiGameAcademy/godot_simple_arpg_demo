# ScalableValue 使用指南

## 概述

`ScalableValue` 是一个支持随等级成长的数值系统，使用 Godot 的 `Curve` 资源定义成长曲线。这允许属性、技能伤害等数值随等级自动增长，而无需硬编码。

## 核心概念

### ScalableValue 资源

`ScalableValue` 是一个资源类，包含：
- **固定值模式**：使用 `fixed_value`（向后兼容）
- **成长曲线模式**：使用 `growth_curve` 定义数值随等级的变化

### 工作流程

```
角色升级
    ↓
GameplayAttributeComponent.set_level(new_level)
    ↓
更新所有属性实例的 current_level
    ↓
ScalableValue.get_value_at_level(level) 计算新值
    ↓
更新 base_value，触发属性重算
    ↓
发出 attribute_value_changed 信号
```

## 使用方法

### 1. 创建 Curve 资源

1. 在 Godot 编辑器中，右键点击项目资源
2. 选择 "新建资源" → "Curve"
3. 配置曲线：
   - **X 轴**：等级（相对于 `base_level`）
   - **Y 轴**：数值
   - 例如：
     - 点 (0, 10) → 等级 1 = 10
     - 点 (9, 50) → 等级 10 = 50
     - 点 (19, 100) → 等级 20 = 100

### 2. 创建 ScalableValue 资源

1. 右键点击项目资源
2. 选择 "新建资源" → "ScalableValue"
3. 配置：
   - `use_level_scaling`: `true`（启用等级成长）
   - `growth_curve`: 选择步骤 1 创建的 Curve
   - `base_level`: `1`（通常为 1）
   - `fixed_value`: `0.0`（如果使用曲线，此值会被忽略）

### 3. 在属性集中配置

在 `GameplayAttributeSet` 资源中：

**方式 1：使用固定值（向后兼容）**
```gdscript
attributes = {
    attack_attribute: 10.0  # 固定值
}
```

**方式 2：使用 ScalableValue（推荐）**
```gdscript
scalable_attributes = {
    attack_attribute: scalable_attack_value  # ScalableValue 资源
}
```

### 4. 在代码中设置等级

```gdscript
# 获取属性组件
var attr_comp = GameplayAbilitySystem.get_component_by_interface(entity, "GameplayAttributeComponent")

# 设置等级（会自动更新所有使用 ScalableValue 的属性）
attr_comp.set_level(10)

# 获取属性值（会根据当前等级自动计算）
var attack = attr_comp.get_value("attack")
```

## 配置示例

### 示例 1：线性成长

**Curve 配置**：
- 点 (0, 10) → 等级 1 = 10
- 点 (99, 100) → 等级 100 = 100
- 曲线类型：线性

**结果**：每级增长约 0.91

### 示例 2：指数成长

**Curve 配置**：
- 点 (0, 10) → 等级 1 = 10
- 点 (9, 20) → 等级 10 = 20
- 点 (19, 50) → 等级 20 = 50
- 点 (29, 150) → 等级 30 = 150
- 曲线类型：平滑（指数）

**结果**：前期增长慢，后期增长快

### 示例 3：分段成长

**Curve 配置**：
- 点 (0, 10) → 等级 1-10 = 10（平缓）
- 点 (9, 10) → 等级 10 = 10
- 点 (10, 50) → 等级 11 = 50（跳跃）
- 点 (19, 50) → 等级 11-20 = 50（平缓）
- 点 (20, 100) → 等级 21 = 100（跳跃）

**结果**：在特定等级有大幅提升

## API 参考

### ScalableValue

```gdscript
## 获取指定等级下的数值
func get_value_at_level(level: int) -> float

## 获取基础值（等级 1 时的值）
func get_base_value() -> float

## 获取最大等级时的值（用于预览）
func get_max_value(max_level: int = 100) -> float
```

### GameplayAttributeComponent

```gdscript
## 设置等级（会更新所有使用 ScalableValue 的属性）
func set_level(level: int) -> void

## 获取当前等级
func get_level() -> int

## 等级变化信号
signal level_changed(old_level: int, new_level: int)
```

### GameplayAttributeInstance

```gdscript
## 设置可扩展数值
func set_scalable_value(value: ScalableValue) -> void

## 设置等级（会重新计算 base_value）
var current_level: int = 1
```

## 向后兼容性

系统完全向后兼容：

1. **固定值属性**：如果属性使用 `attributes` 字典（固定值），行为不变
2. **未设置 ScalableValue**：如果 `scalable_value` 为 `null`，使用 `fixed_value`
3. **未启用等级成长**：如果 `use_level_scaling = false`，使用 `fixed_value`

## 最佳实践

### 1. 规划成长曲线

在创建 Curve 之前，先规划：
- 等级范围（如 1-100）
- 基础值（等级 1 的值）
- 最终值（最高等级的值）
- 成长类型（线性、指数、分段等）

### 2. 使用预览功能

在编辑器中，可以使用 `get_max_value()` 预览最高等级的值，确保数值平衡。

### 3. 测试不同等级

在游戏中测试多个等级，确保数值增长符合预期。

### 4. 组合使用

可以同时使用：
- **ScalableValue**：定义基础成长
- **Modifier**：添加临时加成（装备、Buff 等）

## 常见问题

### Q: 如何让属性在特定等级有跳跃式增长？

**A**: 在 Curve 中设置两个相邻点，Y 值差距较大。例如：
- 点 (9, 10) → 等级 10 = 10
- 点 (10, 50) → 等级 11 = 50

### Q: 可以同时使用固定值和 ScalableValue 吗？

**A**: 不可以。如果属性在 `scalable_attributes` 中，会优先使用 ScalableValue，忽略 `attributes` 中的固定值。

### Q: 等级变化会影响 Modifier 吗？

**A**: 不会。Modifier 是独立的加成系统，只影响最终值，不影响 base_value 的计算。

### Q: 如何实现技能等级成长？

**A**: 可以在 `GameplayAbility` 或 `GameplayEffect` 中使用 ScalableValue，但需要手动管理技能等级。属性系统的等级是角色等级。

## 完成！

现在你的属性系统支持随等级自动成长了！🎉

