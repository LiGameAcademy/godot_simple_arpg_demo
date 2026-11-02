# 架构重构计划：分离 Status 和 AreaEffect

## 问题分析

当前架构将区域检测逻辑集成到 `GameplayStatusInstance` 中，导致：

1. **职责混乱**：Status 从"数据修改器"变成了"主动扫描器"
2. **概念混淆**：Status 应该依附实体，但区域效果需要依附位置
3. **性能隐患**：大量区域 Status 会导致频繁的物理查询
4. **调试困难**：区域范围隐藏在 Status 配置中，难以可视化

## 重构目标

### 核心原则
- **Status**：管理实体上的状态（Buff/Debuff），被动修改宿主数据
- **AreaEffect**：管理位置上的效果（AOE、魔法阵），主动检测周围目标

### 职责划分

| 系统 | 职责 | 依附对象 | 检测方式 |
|------|------|----------|----------|
| **Status** | 修改宿主属性/行为 | 实体（Entity） | 无（被动） |
| **AreaEffect** | 在位置持续检测并应用效果 | 位置（Position） | 物理触发器（事件驱动） |

## 实施方案

### 阶段1：创建 AreaEffectSystem（新增，不破坏现有）

#### 1.1 AreaEffectData (Resource)
```gdscript
extends Resource
class_name AreaEffectData

## 区域效果数据
## 定义位置效果的配置

@export var effect_id: StringName
@export var duration: float = 5.0
@export var period: float = 1.0  # 周期性触发间隔

## 效果列表（周期性应用）
@export var effects: Array[GameplayEffect] = []

## 目标检测
@export var hit_detector: HitDetectorBase = null
@export var targeting_strategy: TargetingStrategy = null

## 视觉表现
@export var cue: GameplayCue = null  # 区域特效
```

#### 1.2 AreaEffectInstance (RefCounted)
```gdscript
extends RefCounted
class_name AreaEffectInstance

## 区域效果实例
## 管理位置效果的生命周期

var effect_data: AreaEffectData
var position: Vector3
var instigator: Node
var _timer: Timer
var _area_node: Area3D  # 物理触发器（事件驱动）

## 使用 Area3D 的 body_entered/body_exited 信号维护目标列表
var _targets_in_area: Array[Node] = []
```

#### 1.3 AreaEffectComponent (Node)
```gdscript
extends Node
class_name AreaEffectComponent

## 区域效果组件
## 管理场景中的区域效果

var _active_effects: Dictionary[StringName, AreaEffectInstance] = {}

func spawn_area_effect(data: AreaEffectData, position: Vector3, instigator: Node) -> AreaEffectInstance:
    # 创建区域效果实例
    # 使用 Area3D 进行事件驱动的目标检测
```

### 阶段2：重构 ProjectileAbility（使用 AreaEffect）

```gdscript
# 投射物爆炸时，不再使用 Status，而是使用 AreaEffect
func _on_projectile_impact(...):
    if is_instance_valid(explosion_area_effect_data):
        var area_comp = get_area_effect_component()
        area_comp.spawn_area_effect(
            explosion_area_effect_data,
            hit_position,
            instigator
        )
```

### 阶段3：保持 Status 的向后兼容

- 保留 Status 的 `hit_detector` 和 `target_mode` 功能
- 标记为 `@deprecated`，提供迁移指南
- 新项目推荐使用 AreaEffectSystem

## 迁移策略

### 现有配置迁移

**旧方式（Status 区域效果）**：
```gdscript
# explosion_status.tres (GameplayStatusData)
hit_detector: AreaHitDetector
target_mode: DETECTED_TARGETS
period: 0.5
periodic_effects: [GE_Damage]
```

**新方式（AreaEffect）**：
```gdscript
# explosion_area_effect.tres (AreaEffectData)
hit_detector: AreaHitDetector
period: 0.5
effects: [GE_Damage]
```

## 性能优化

### AreaEffect 的优势

1. **事件驱动**：使用 `Area3D` 的 `body_entered/body_exited` 信号，避免轮询
2. **目标列表维护**：只在目标进入/离开时更新，而不是每帧检测
3. **物理优化**：利用引擎的物理系统优化，而非手动查询

## 总结

### 重构收益

✅ **职责清晰**：Status 专注实体状态，AreaEffect 专注位置效果  
✅ **性能提升**：事件驱动替代轮询检测  
✅ **易于调试**：Area3D 节点可视化区域范围  
✅ **符合标准**：遵循行业最佳实践  

### 实施建议

1. **渐进式迁移**：先实现 AreaEffectSystem，新功能使用新系统
2. **向后兼容**：保留 Status 的区域功能，标记为 deprecated
3. **文档完善**：提供迁移指南和示例

