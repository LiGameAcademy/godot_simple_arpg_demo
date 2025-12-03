# 环形进度条 Shader 使用说明

## 概述

环形进度条使用 GPU Shader 实现，性能优异，视觉效果流畅。从顶部开始，顺时针填充，显示技能冷却进度。

## Shader 参数

### progress (float)
- **范围**: 0.0 - 1.0
- **说明**: 冷却进度值
  - `1.0` = 刚开始冷却（整个圆环显示冷却颜色）
  - `0.0` = 冷却完成（整个圆环透明）

### thickness (float)
- **范围**: 0.0 - 0.5
- **说明**: 圆环厚度（相对于半径）
- **默认值**: 0.15

### progress_color (Color)
- **说明**: 冷却中的颜色
- **默认值**: Color(0.2, 0.2, 0.2, 0.8) - 半透明灰色

### ready_color (Color)
- **说明**: 冷却完成的颜色（通常设置为透明）
- **默认值**: Color(1.0, 1.0, 1.0, 0.0) - 透明

## 使用示例

### 在 AbilityButton 中使用

```gdscript
# 更新进度
progress_material.set_shader_parameter("progress", 0.5)  # 50% 冷却中

# 自定义颜色
progress_material.set_shader_parameter("progress_color", Color(1.0, 0.0, 0.0, 0.8))  # 红色
progress_material.set_shader_parameter("thickness", 0.2)  # 更粗的圆环
```

## 视觉效果

- **填充方向**: 从顶部（12点方向）开始，顺时针填充
- **动画**: 平滑的进度变化，无闪烁
- **性能**: GPU 加速，不影响 CPU

## 自定义

可以通过修改 shader 参数来自定义：
- 圆环颜色（冷却中/完成）
- 圆环厚度
- 起始角度（需要修改 shader 代码）
