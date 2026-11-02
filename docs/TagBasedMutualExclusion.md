# 基于标签系统的互斥效果：免疫与强控制

**完成日期**: 2024  
**状态**: ✅ 全部完成

---

## 📋 概述

本文档描述了基于标签系统实现的互斥效果，包括免疫和强控制（眩晕、沉默、定身等）功能。

---

## ✅ 已完成的功能

### 1. 标签资源创建

#### 1.1 无敌标签 ✅
- **文件**: `data/tags/state_invulnerable.tres`
- **ID**: `state.invulnerable`
- **描述**: 免疫所有伤害
- **继承**: 继承自 `status` 标签
- **用途**: 用于冲锋、无敌技能等场景

#### 1.2 眩晕标签 ✅
- **文件**: `data/tags/state_stunned.tres`
- **ID**: `state.stunned`
- **描述**: 无法移动、无法释放技能
- **继承**: 继承自 `status.crowd_control` 标签
- **用途**: 用于控制效果，完全限制目标行动

#### 1.3 沉默标签 ✅
- **文件**: `data/tags/state_silenced.tres`
- **ID**: `state.silenced`
- **描述**: 无法释放技能
- **继承**: 继承自 `status.crowd_control` 标签
- **用途**: 用于限制技能释放，但不影响移动

#### 1.4 定身标签 ✅
- **文件**: `data/tags/state_rooted.tres`
- **ID**: `state.rooted`
- **描述**: 无法移动
- **继承**: 继承自 `status.crowd_control` 标签
- **用途**: 用于限制移动，但不影响技能释放

---

### 2. 状态系统集成

#### 2.1 冲锋无敌状态 ✅
- **文件**: `data/ability_status/dash_status.tres`
- **修改**: 添加 `tags = [&"state.invulnerable"]`
- **效果**: 冲锋期间（0.5秒）获得无敌标签，免疫所有伤害
- **实现**: 通过 `GameplayStatusInstance._apply_status_tags()` 自动应用标签

#### 2.2 眩晕状态 ✅
- **文件**: `data/ability_status/stunned_status.tres`
- **标签**: `tags = [&"state.stunned"]`
- **持续时间**: 2.0秒
- **效果**: 无法移动、无法释放技能
- **应用**: 通过重击技能（`heavy_attack`）应用

---

### 3. 技能系统集成

#### 3.1 重击技能增强 ✅
- **文件**: `data/abilities/heavy_attack.tres`
- **修改**:
  - 添加眩晕状态到 `statuses` 数组
  - 伤害效果添加 `target_blocked_tags = [&"state.invulnerable"]`
- **效果**: 
  - 对目标造成伤害并眩晕 2 秒
  - 伤害效果会检查目标是否无敌，如果无敌则不造成伤害

---

### 4. 效果系统集成

#### 4.1 伤害效果免疫检查 ✅
- **位置**: `GameplayEffect._check_filters()`
- **机制**: 
  - 如果效果的 `target_blocked_tags` 包含 `state.invulnerable`
  - 且目标拥有 `state.invulnerable` 标签
  - 则效果不会生效（免疫伤害）
- **示例**: `heavy_attack` 的伤害效果已配置 `target_blocked_tags = [&"state.invulnerable"]`

---

### 5. 移动系统集成

#### 5.1 移动禁用逻辑 ✅
- **位置**: `prefabs/player.gd._physics_process()`
- **检查标签**: `state.stunned`、`state.rooted`
- **效果**: 
  - 如果拥有眩晕或定身标签，停止移动
  - 保持重力效果（防止浮空）
  - 平滑减速到停止

```gdscript
# 【标签系统】检查是否被眩晕或定身（无法移动）
if TagManager.has_tag(self, &"state.stunned") or TagManager.has_tag(self, &"state.rooted"):
    # 眩晕/定身状态：停止移动，但保持重力
    velocity.x = move_toward(velocity.x, 0, acceleration * delta)
    velocity.z = move_toward(velocity.z, 0, acceleration * delta)
    _set_movement_blend_position(velocity.length())
    move_and_slide()
    return
```

---

### 6. 技能系统集成

#### 6.1 技能禁用逻辑 ✅
- **位置**: `addons/godot_gameplay_abilities/scripts/abilities/active_ability.gd._can_cast()`
- **检查标签**: `state.stunned`、`state.silenced`
- **效果**: 
  - 如果拥有眩晕或沉默标签，无法释放技能
  - 在 `_can_cast()` 中提前返回 `false`

```gdscript
# 【标签系统】检查是否被眩晕或沉默（无法释放技能）
if TagManager.has_tag(instigator, &"state.stunned") or TagManager.has_tag(instigator, &"state.silenced"):
    print("ActiveAbility: Caster is stunned or silenced, cannot cast ability %s" % ability_id)
    return false
```

---

## 🎯 使用场景

### 场景 1: 冲锋无敌
1. 玩家使用冲刺技能（`dash`）
2. 状态系统自动应用 `state.invulnerable` 标签
3. 期间所有伤害效果检查到无敌标签，不会生效
4. 0.5秒后状态结束，标签自动移除

### 场景 2: 重击眩晕
1. 玩家使用重击技能（`heavy_attack`）
2. 技能对目标造成伤害（如果目标无敌则免疫）
3. 同时应用眩晕状态，目标获得 `state.stunned` 标签
4. 目标无法移动和释放技能，持续 2 秒
5. 2 秒后状态结束，标签自动移除

### 场景 3: 沉默效果
1. 某个技能或状态应用 `state.silenced` 标签
2. 目标无法释放技能（`ActiveAbility._can_cast()` 检查失败）
3. 但可以正常移动（不受影响）

### 场景 4: 定身效果
1. 某个技能或状态应用 `state.rooted` 标签
2. 目标无法移动（`player._physics_process()` 检查失败）
3. 但可以正常释放技能（不受影响）

---

## 🔧 技术实现

### 标签系统集成检查

#### ✅ Ability 层
- `GameplayAbility` 有 `tags: Array[StringName]` 属性
- `ActiveAbility` 有 `caster_required_tags` 和 `caster_blocked_tags` 属性
- `ActiveAbility._can_cast()` 中检查标签要求

#### ✅ Status 层
- `GameplayStatusData` 有 `tags: Array[StringName]` 属性
- `GameplayStatusInstance` 在 `apply()` 时调用 `_apply_status_tags()`
- `GameplayStatusInstance` 在 `remove()` 时调用 `_remove_status_tags()`
- 标签生命周期与状态生命周期完全同步

#### ✅ Effect 层
- `GameplayEffect` 有 `target_required_tags` 和 `target_blocked_tags` 属性
- `GameplayEffect._check_filters()` 中检查标签要求
- 支持免疫检查（`target_blocked_tags`）和连携检查（`target_required_tags`）

---

## 📝 标签互斥机制

### 自动互斥
- `GameplayTagManager.add_tag()` 会自动处理互斥标签
- 如果标签 A 的 `mutually_exclusive_tags` 包含标签 B
- 添加标签 A 时，会自动移除标签 B（反之亦然）

### 手动互斥
- 通过 `blocked_tags` 实现效果级别的互斥
- 例如：伤害效果的 `target_blocked_tags = [&"state.invulnerable"]`
- 如果目标拥有阻止标签，效果不会生效

---

## 🚀 扩展建议

### 1. 更多控制效果
- **恐惧**: 强制目标向反方向移动
- **魅惑**: 目标攻击友军
- **缴械**: 无法使用近战技能
- **禁魔**: 无法使用魔法技能

### 2. 免疫系统扩展
- **物理免疫**: `state.physical_immune`
- **魔法免疫**: `state.magic_immune`
- **控制免疫**: `state.control_immune`

### 3. 状态优先级
- 实现状态优先级系统
- 高优先级状态可以覆盖低优先级状态
- 例如：无敌状态优先级高于眩晕状态

---

## 📚 相关文档

- [标签系统集成总结](./TagSystemIntegrationSummary.md)
- [标签系统评估](./TagSystemEvaluation.md)
- [技能执行流程](./AbilityExecutionFlow.md)

---

## ✅ 验证清单

- [x] 创建无敌标签资源
- [x] 创建眩晕标签资源
- [x] 创建沉默标签资源
- [x] 创建定身标签资源
- [x] 修改冲锋状态添加无敌标签
- [x] 创建眩晕状态资源
- [x] 修改重击技能添加眩晕状态
- [x] 伤害效果检查无敌标签
- [x] 移动系统检查眩晕/定身标签
- [x] 技能系统检查眩晕/沉默标签

---

**完成时间**: 2024  
**作者**: IndieOne (Godot 独立游戏全能助手)

