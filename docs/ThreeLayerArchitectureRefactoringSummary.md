# 三层架构重构实施总结

## ✅ 已完成的工作

### 第一阶段：扩展 Status 系统

#### 1.1 扩展 `GameplayStatusData`
- ✅ 添加 `hit_detector: HitDetectorBase` - 用于目标检测
- ✅ 添加 `targeting_strategy: TargetingStrategy` - 用于目标筛选
- ✅ 添加 `target_filters: Array[GameplayFilterData]` - 用于进一步筛选
- ✅ 添加 `target_mode: TargetApplicationMode` 枚举：
  - `SELF` (0) - 应用到自己
  - `DETECTED_TARGETS` (1) - 应用到检测到的目标
  - `BOTH` (2) - 同时应用到自己和检测到的目标

#### 1.2 修改 `GameplayStatusInstance`
- ✅ 实现 `_resolve_targets()` - 根据配置检测和筛选目标
- ✅ 实现 `_passes_filters()` - 检查目标是否通过所有过滤器
- ✅ 修改 `apply()` - 使用目标检测逻辑，对每个目标应用效果
- ✅ 修改 `_apply_all_effects_to_target()` - 对单个目标应用所有效果
- ✅ 修改 `_on_periodic_effect()` - 周期性效果也重新检测目标
- ✅ 修改 `handle_event()` - 事件触发时也重新检测目标

### 第二阶段：简化 Effect 系统

- ✅ 标记 `GE_AreaDamage` 为已弃用
- ✅ 添加详细注释说明新的使用方式
- ✅ 保留 `GE_ApplyDamage`（纯效果执行，无目标检测）

### 第三阶段：重构 Ability 系统

#### 3.1 扩展 `ActiveAbility`
- ✅ 添加 `caster_statuses: Array[GameplayStatusData]` - 施法者状态
- ✅ 添加 `target_statuses: Array[GameplayStatusData]` - 目标状态
- ✅ 标记 `caster_effects` 和 `target_effects` 为已弃用（保持向后兼容）

#### 3.2 修改 `_on_cast()`
- ✅ 优先使用 Status 系统（如果配置了 `caster_statuses` 或 `target_statuses`）
- ✅ 回退到 Effect 系统（向后兼容）
- ✅ 传递上下文信息（包括 `input_target`、`ability_id`、`hit_detector`）

#### 3.3 添加 `_apply_status()`
- ✅ 应用状态到施法者
- ✅ 状态系统会自己处理目标检测、筛选和应用效果

## 📋 待完成的工作

### 第四阶段：迁移现有技能配置

需要手动迁移以下技能配置：

#### 4.1 献祭技能（Sacrifice）

**当前配置** (`sacrifice_toggle.tres`):
- 使用 `channeling_status: sacrifice_status.tres`
- `sacrifice_status.tres` 使用 `GE_AreaDamage`（已弃用）

**新配置**:
1. 修改 `sacrifice_status.tres`:
   - 移除 `GE_AreaDamage`
   - 添加 `hit_detector: AreaHitDetector` (radius: 4.0)
   - 设置 `target_mode: DETECTED_TARGETS`
   - 添加 `GE_ApplyDamage` (damage_multiplier: 0.8)

2. 或者创建新的状态：
   - `sacrifice_area_damage_status.tres`:
     - `hit_detector: AreaHitDetector` (radius: 4.0)
     - `target_mode: DETECTED_TARGETS`
     - `effects: [GE_ApplyDamage]` (damage_multiplier: 0.8)
     - `period: 1.0`
     - `duration: -1.0` (永久)

#### 4.2 火球术（Fireball）

**当前配置** (`fireball.tres`):
- 使用 `target_effects: [GE_Damage_Fire, GE_ApplyBurnStatus]`

**新配置**:
1. 创建 `fireball_damage_status.tres`:
   - `duration: 0.0` (瞬时)
   - `effects: [GE_Damage_Fire]`

2. 创建 `fireball_burn_status.tres`:
   - `duration: 0.0` (瞬时)
   - `effects: [GE_ApplyBurnStatus]`

3. 修改 `fireball.tres`:
   - 移除 `target_effects`
   - 添加 `target_statuses: [fireball_damage_status, fireball_burn_status]`

#### 4.3 其他技能

根据实际需要，迁移其他使用 `target_effects` 或 `caster_effects` 的技能。

## 🎯 新架构使用示例

### 示例 1：范围伤害状态

```gdscript
# sacrifice_area_damage_status.tres
status_id: "sacrifice_area_damage"
duration: -1.0  # 永久
period: 1.0  # 每秒触发一次

# 目标检测配置
hit_detector: AreaHitDetector
  - detection_radius: 4.0
  - detection_position_source: CASTER_POSITION
  - exclude_caster: true

target_mode: DETECTED_TARGETS  # 只应用到检测到的目标

# 效果配置
effects: [GE_ApplyDamage]
  - damage_multiplier: 0.8
  - vital_id: "health"
  - base_damage_attribute: "attack"
```

### 示例 2：瞬时伤害状态

```gdscript
# fireball_damage_status.tres
status_id: "fireball_damage"
duration: 0.0  # 瞬时（应用后立即移除）

# 目标检测配置（如果需要）
hit_detector: null  # 由 ProjectileAbility 处理目标检测

target_mode: SELF  # 应用到自己（实际上由 ProjectileAbility 传递目标）

# 效果配置
effects: [GE_ApplyDamage]
  - damage_multiplier: 1.0
```

### 示例 3：治疗术（对自己治疗，对敌人伤害）

```gdscript
# heal_self_status.tres
status_id: "heal_self"
duration: 0.0  # 瞬时
target_mode: SELF
effects: [GE_Heal]

# damage_enemy_status.tres
status_id: "damage_enemy"
duration: 0.0  # 瞬时
hit_detector: AreaHitDetector (radius: 3.0)
target_mode: DETECTED_TARGETS
effects: [GE_ApplyDamage]

# heal_ability.tres
target_statuses: [heal_self_status, damage_enemy_status]
```

## 📝 注意事项

1. **向后兼容性**：
   - 旧技能配置（使用 `target_effects` 和 `caster_effects`）仍然可以正常工作
   - 建议逐步迁移到新架构

2. **性能考虑**：
   - Status 系统会重新检测目标（周期性效果、事件触发时）
   - 对于高频触发的效果，考虑优化检测逻辑

3. **目标检测**：
   - Status 的目标检测在 `apply()` 时执行
   - 周期性效果和事件触发时也会重新检测目标
   - 确保 `hit_detector` 配置正确

4. **瞬时效果**：
   - 使用 `duration = 0.0` 的 Status 实现瞬时效果
   - Status 会在应用后立即移除

## 🔄 迁移步骤

1. **识别需要迁移的技能**：
   - 查找所有使用 `target_effects` 或 `caster_effects` 的技能

2. **分析技能需求**：
   - 是否需要目标检测？
   - 是否需要目标筛选？
   - 是瞬时效果还是持续效果？

3. **创建新的 Status 资源**：
   - 配置 `hit_detector`（如果需要）
   - 配置 `target_mode`
   - 配置 `effects`

4. **修改技能配置**：
   - 移除 `target_effects` 或 `caster_effects`
   - 添加 `target_statuses` 或 `caster_statuses`

5. **测试验证**：
   - 确保功能正常
   - 检查性能影响

## 🎉 重构完成

三层架构重构的核心代码已经完成！现在可以开始迁移现有技能配置了。

