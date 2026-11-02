# 三层架构重构分析

## 当前架构

### 现状

1. **Ability（技能层）**
   - 职责：目标检测、目标筛选、效果应用
   - 直接调用 Effect 应用效果
   - 使用 `TargetingStrategy` 和 `HitDetectorBase` 进行目标检测

2. **Status（状态层）**
   - 职责：周期性效果、持续时间管理、层数管理
   - 依赖 Effect 执行具体逻辑
   - 目标检测能力有限（主要通过 Effect 内部实现，如 `GE_AreaDamage`）

3. **Effect（效果层）**
   - 职责：具体效果执行（伤害、治疗、状态施加等）
   - 不负责目标检测（除了特殊情况如 `GE_AreaDamage`）

### 当前问题

1. **目标检测逻辑分散**
   - Ability 层有目标检测（`TargetingStrategy`、`HitDetectorBase`）
   - Effect 层也有目标检测（`GE_AreaDamage` 内部使用 `AreaHitDetector`）
   - 导致逻辑重复，难以复用

2. **Status 系统能力受限**
   - Status 无法独立进行目标检测
   - 需要依赖 Effect 内部实现（如 `GE_AreaDamage`）
   - 限制了 Status 的灵活性

3. **架构不统一**
   - 瞬时效果：Ability -> Effect
   - 持续效果：Ability -> Status -> Effect
   - 两种路径导致维护成本高

## 提议的三层架构

### 新架构设计

1. **Effect（效果执行层）**
   - **职责**：只负责对**已确定的目标**应用具体效果
   - **不负责**：目标检测、目标筛选、生命周期管理
   - **特点**：纯函数式，输入目标，输出效果

2. **Status（状态层）**
   - **职责**：
     - 目标检测（使用 `HitDetectorBase`）
     - 目标筛选（使用 `TargetingStrategy`）
     - 生命周期管理（持续时间、周期、层数）
     - 应用 Effect 到检测到的目标
   - **特点**：从 Ability 层移植目标检测和筛选能力

3. **Ability（技能层）**
   - **职责**：
     - 支付消耗
     - 应用 Status（不再直接应用 Effect）
     - 技能级别的逻辑（冷却、前摇等）
   - **特点**：简化为"Status 应用器"

### 架构优势

#### 1. 统一性

**所有效果都通过 Status 系统**：
- 瞬时效果：`duration = 0` 的 Status
- 周期性效果：`period > 0` 的 Status
- 永久效果：`duration = -1` 的 Status

**统一的执行路径**：
```
Ability -> Status -> Effect
```

#### 2. 灵活性

**每个 Status 可以有独立的目标检测**：
```gdscript
# 火球术：对鼠标位置的目标应用伤害状态
fireball_status:
  - hit_detector: AreaHitDetector (检测鼠标位置)
  - effects: [GE_Damage]

# 献祭：对自己周围的目标应用伤害状态
sacrifice_status:
  - hit_detector: AreaHitDetector (检测自己周围)
  - effects: [GE_AreaDamage]  # 或者改为 Status 自己检测
```

**Ability 可以应用多个 Status**：
```gdscript
# 火球术：应用伤害状态 + 燃烧状态
fireball_ability:
  - statuses: [fireball_damage_status, fireball_burn_status]
```

#### 3. 可组合性

**不同 Status 可以有不同的目标**：
```gdscript
# 治疗术：对自己应用治疗状态，对敌人应用伤害状态
heal_ability:
  - statuses: [
      heal_self_status (target: self),
      damage_enemy_status (target: enemies_in_range)
    ]
```

#### 4. 解耦性

**Effect 不再需要知道如何检测目标**：
- `GE_AreaDamage` 不再需要内部使用 `AreaHitDetector`
- Effect 专注于效果执行，更易测试和维护

**Status 负责目标检测，Effect 负责效果执行**：
- 职责清晰，符合单一职责原则

## 实现方案

### 方案 1：完全重构（推荐）

#### 1.1 扩展 `GameplayStatusData`

```gdscript
# gameplay_status_data.gd
@export_group("Target Detection")
## 命中检测器（用于检测目标）
## 如果设置了，Status 会在应用时使用此检测器检测目标
## 如果未设置，Status 会应用到自己（target = instigator）
@export var hit_detector: HitDetectorBase = null

## 目标筛选策略（用于筛选检测到的目标）
## 如果设置了，Status 会使用此策略筛选目标
@export var targeting_strategy: TargetingStrategy = null

## 目标过滤器（用于进一步筛选目标）
@export var target_filters: Array[GameplayFilterData] = []

## 目标应用模式
enum TargetApplicationMode {
    SELF,              ## 应用到自己（默认）
    DETECTED_TARGETS,  ## 应用到检测到的目标
    BOTH               ## 同时应用到自己和检测到的目标
}
@export var target_mode: TargetApplicationMode = TargetApplicationMode.SELF
```

#### 1.2 修改 `GameplayStatusInstance`

```gdscript
# gameplay_status_instance.gd
func apply(context: Dictionary = {}) -> void:
    var target_entity = get_target_entity()
    if not is_instance_valid(target_entity):
        return
    
    # 1. 检测目标（如果配置了 hit_detector）
    var targets_to_apply: Array[Node] = []
    
    if is_instance_valid(status_data.hit_detector) and target_entity is Node3D:
        # 使用检测器检测目标
        var detected_targets = status_data.hit_detector.get_targets(
            target_entity as Node3D, 
            context
        )
        
        # 使用策略筛选目标
        if is_instance_valid(status_data.targeting_strategy):
            detected_targets = status_data.targeting_strategy.resolve_targets(
                instigator,
                null,
                context
            )
        
        # 应用过滤器
        for target in detected_targets:
            if _passes_filters(target, instigator, context):
                targets_to_apply.append(target)
    else:
        # 没有检测器，应用到自己
        targets_to_apply.append(target_entity)
    
    # 2. 根据 target_mode 决定应用目标
    match status_data.target_mode:
        TargetApplicationMode.SELF:
            targets_to_apply = [target_entity]
        TargetApplicationMode.DETECTED_TARGETS:
            # 使用检测到的目标（已设置）
            pass
        TargetApplicationMode.BOTH:
            if target_entity not in targets_to_apply:
                targets_to_apply.append(target_entity)
    
    # 3. 对每个目标应用效果
    for target in targets_to_apply:
        _apply_all_effects_to_target(target, context)
    
    # 4. 其他逻辑（周期性、事件监听等）
    # ...
```

#### 1.3 简化 `ActiveAbility`

```gdscript
# active_ability.gd
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
    var instigator = ability_comp.get_parent()
    if not is_instance_valid(instigator):
        return
    
    # 1. 应用自身效果（通过 Status）
    if not caster_statuses.is_empty():
        for status_data in caster_statuses:
            _apply_status(instigator, status_data, context)
    
    # 2. 应用目标状态（通过 Status）
    var statuses_to_apply = target_statuses if not target_statuses.is_empty() else statuses
    for status_data in statuses_to_apply:
        _apply_status(instigator, status_data, context)
    
    # 3. 检查完成
    _check_ability_completion()

func _apply_status(instigator: Node, status_data: GameplayStatusData, context: Dictionary) -> void:
    var status_comp = GameplayAbilitySystem.get_component_by_interface(
        instigator, 
        "GameplayStatusComponent"
    )
    if not is_instance_valid(status_comp):
        return
    
    # 传递上下文（包括 input_target）
    var status_context = context.duplicate()
    status_context["input_target"] = input_target
    status_context["ability_id"] = ability_id
    
    status_comp.apply_status(status_data, instigator, 1, status_context)
```

#### 1.4 简化 `GameplayEffect`

```gdscript
# gameplay_effect.gd
# 移除所有目标检测逻辑
# Effect 只负责对已确定的目标应用效果

# 移除 GE_AreaDamage，改为使用 Status + AreaHitDetector
```

### 方案 2：渐进式重构（保守）

#### 2.1 保持向后兼容

- 保留 `ActiveAbility` 直接应用 Effect 的能力
- 新增 `statuses` 属性，允许 Ability 应用 Status
- 逐步迁移现有技能

#### 2.2 双重路径

```gdscript
# active_ability.gd
@export var target_effects: Array[GameplayEffect] = []  # 旧方式（保留）
@export var target_statuses: Array[GameplayStatusData] = []  # 新方式

func _on_cast(...) -> void:
    # 优先使用新方式
    if not target_statuses.is_empty():
        # 应用 Status
        for status_data in target_statuses:
            _apply_status(...)
    else:
        # 回退到旧方式
        _apply_effects_to_targets(target_effects, ...)
```

## 挑战与解决方案

### 挑战 1：瞬时效果

**问题**：瞬时效果（如立即伤害）如何通过 Status 实现？

**解决方案**：
- 使用 `duration = 0` 的 Status
- Status 在 `apply()` 时立即应用效果，然后立即移除
- 或者：Status 检测到 `duration = 0` 时，不创建计时器，直接应用并移除

```gdscript
# gameplay_status_instance.gd
func apply(context: Dictionary = {}) -> void:
    # ... 检测目标和应用效果 ...
    
    # 如果是瞬时效果，立即移除
    if status_data.duration == 0.0:
        remove()
```

### 挑战 2：性能考虑

**问题**：每个 Status 都需要目标检测，可能比直接应用 Effect 更重

**解决方案**：
- 缓存检测结果（在同一帧内，相同检测器可以复用结果）
- 优化检测器实现（使用空间索引、减少物理查询等）
- 对于简单场景（如单体目标），可以跳过检测器，直接使用 `input_target`

### 挑战 3：向后兼容性

**问题**：现有的大量 Ability 需要重构

**解决方案**：
- 采用渐进式重构（方案 2）
- 提供迁移工具（自动将 Effect 转换为 Status）
- 保留旧 API，标记为 `@deprecated`

### 挑战 4：Effect 的复用性

**问题**：`GE_AreaDamage` 等 Effect 需要重构

**解决方案**：
- 移除 `GE_AreaDamage` 的目标检测逻辑
- 改为 `GE_Damage`（只负责伤害计算）
- 在 Status 层使用 `AreaHitDetector` 检测目标，然后应用 `GE_Damage`

## 具体示例

### 示例 1：火球术（瞬时伤害）

**当前方式**：
```gdscript
# fireball.tres (ProjectileAbility)
target_effects: [GE_Damage_Fire]
```

**新方式**：
```gdscript
# fireball_damage_status.tres (GameplayStatusData)
duration: 0.0  # 瞬时
hit_detector: null  # 由 ProjectileAbility 处理
effects: [GE_Damage_Fire]

# fireball.tres (ProjectileAbility)
target_statuses: [fireball_damage_status]
```

### 示例 2：献祭（周期性范围伤害）

**当前方式**：
```gdscript
# sacrifice_status.tres
effects: [GE_AreaDamage]  # Effect 内部检测目标
period: 1.0
```

**新方式**：
```gdscript
# sacrifice_status.tres
hit_detector: AreaHitDetector (radius: 4.0)
targeting_strategy: AreaTargetingStrategy
effects: [GE_Damage]  # 只负责伤害计算
target_mode: DETECTED_TARGETS
period: 1.0
```

### 示例 3：治疗术（对自己治疗，对敌人伤害）

**新方式**：
```gdscript
# heal_self_status.tres
target_mode: SELF
effects: [GE_Heal]

# damage_enemy_status.tres
hit_detector: AreaHitDetector
target_mode: DETECTED_TARGETS
effects: [GE_Damage]

# heal_ability.tres
target_statuses: [heal_self_status, damage_enemy_status]
```

## 结论

### 推荐方案

**采用方案 1（完全重构）**，原因：

1. ✅ **架构更清晰**：职责分离明确
2. ✅ **更易维护**：统一的执行路径
3. ✅ **更灵活**：每个 Status 可以有独立的目标检测
4. ✅ **更易扩展**：新增效果类型只需实现 Effect

### 实施建议

1. **第一阶段**：扩展 `GameplayStatusData` 和 `GameplayStatusInstance`
2. **第二阶段**：简化 `GameplayEffect`，移除目标检测逻辑
3. **第三阶段**：重构 `ActiveAbility`，改为应用 Status
4. **第四阶段**：迁移现有技能配置

### 注意事项

1. **性能优化**：确保目标检测不会成为性能瓶颈
2. **向后兼容**：提供迁移工具和文档
3. **测试覆盖**：确保重构后功能完整性

