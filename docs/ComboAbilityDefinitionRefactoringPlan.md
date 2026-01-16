# ComboAbilityDefinition 重构方案

## 问题分析

### 当前存在的问题

1. **资源污染问题** 🔴
   - 第15行：`execution_tree = _build_combo_tree()` - 直接修改 Definition
   - 第21行：`features.append(cost_feature)` - 直接修改 Definition
   - 第26行：`features.append(cooldown_feature)` - 直接修改 Definition
   - 第54行：`icon_feature.icon_map[key] = icon_map[key]` - 修改已存在的 Feature（如果存在）
   - 第61行：`features.append(icon_feature)` - 直接修改 Definition

2. **缺少配置验证** 🟡
   - 没有验证 `combo_steps` 是否为空
   - 没有验证 `window_duration` 是否为正数
   - 没有验证 `cooldown_duration` 是否非负

3. **代码组织问题** 🟡
   - Feature 注入逻辑分散在 `create_instance` 中
   - 没有统一的 Feature 注入方法

---

## 重构方案

### 核心原则

参考 `ActiveAbilityDefinition` 的重构方式：

1. ✅ **避免资源污染**：使用类变量缓存，临时设置后立即恢复
2. ✅ **在实例中注入 Feature**：不修改 Definition
3. ✅ **添加配置验证**：确保配置合理性
4. ✅ **保持灵活性**：支持手动配置行为树和 Feature

---

## 重构实现

### 1. 添加类变量缓存

```gdscript
# ========== 行为树缓存（享元模式） ==========
## 缓存的默认行为树（所有实例共享，避免重复构建）
var _cached_combo_tree: BTNode = null
```

### 2. 重构 `create_instance` 方法

```gdscript
func create_instance(owner: Node) -> GameplayAbilityInstance:
    # 1. 验证配置
    _validate_configuration()
    
    # 2. 获取执行树（优先使用用户配置，否则使用缓存的默认树）
    var tree_to_use = _get_execution_tree()
    
    # 3. 临时设置 execution_tree（仅用于创建 Instance，不污染资源）
    var original_tree = execution_tree
    execution_tree = tree_to_use
    
    # 4. 调用父类创建实例（这会复制 features 到 instance）
    var instance = super(owner)
    
    # 5. 立即恢复 execution_tree（避免资源污染）
    execution_tree = original_tree
    
    # 6. 初始化黑板变量
    _initialize_blackboard(instance)
    
    # 7. 在 Instance 中动态注入 Feature（不修改 Definition，避免资源污染）
    _inject_features_to_instance(instance)
    
    return instance
```

### 3. 添加 `_get_execution_tree` 方法

```gdscript
## 获取执行树（优先使用用户配置，否则使用缓存的默认树）
## 符合享元模式：所有实例共享同一个行为树
func _get_execution_tree() -> BTNode:
    # 如果用户手动配置了，使用用户的
    if is_instance_valid(execution_tree):
        return execution_tree
    
    # 如果已缓存，使用缓存的（享元模式）
    if is_instance_valid(_cached_combo_tree):
        return _cached_combo_tree
    
    # 构建并缓存（只构建一次，之后所有实例共享）
    _cached_combo_tree = _build_combo_tree()
    return _cached_combo_tree
```

### 4. 重构 Feature 注入逻辑

```gdscript
## 在 Instance 中注入 Feature（不修改 Definition，避免资源污染）
func _inject_features_to_instance(instance: GameplayAbilityInstance) -> void:
    # 注入 CostFeature（如果配置了消耗且不存在）
    if not costs.is_empty():
        if not _has_feature(instance, CostFeature):
            var cost_feature = CostFeature.new()
            cost_feature.costs = costs
            cost_feature.feature_name = cost_feature_name
            instance.add_feature(cost_feature.feature_name, cost_feature)
    
    # 注入 CooldownFeature（如果配置了冷却时间且不存在）
    if cooldown_duration > 0.0:
        if not _has_feature(instance, CooldownFeature):
            var cooldown_feature = CooldownFeature.new()
            cooldown_feature.cooldown_duration = cooldown_duration
            cooldown_feature.feature_name = cooldown_feature_name
            instance.add_feature(cooldown_feature.feature_name, cooldown_feature)
    
    # 注入 DynamicIconFeature（如果连击段有图标）
    _inject_icon_feature(instance)

## 注入图标 Feature
func _inject_icon_feature(instance: GameplayAbilityInstance) -> void:
    var icon_map: Dictionary = {}
    
    # 收集所有连击段的图标
    for i in range(combo_steps.size()):
        var step_def = combo_steps[i]
        if is_instance_valid(step_def) and is_instance_valid(step_def.icon):
            icon_map["combo_%d" % (i + 1)] = step_def.icon
    
    # 如果至少有一个图标，则注入 Feature
    if not icon_map.is_empty():
        # 检查是否已存在 DynamicIconFeature
        var existing_feature = _get_feature(instance, DynamicIconFeature)
        if is_instance_valid(existing_feature):
            # 如果已存在，更新图标映射（不修改 Definition，只更新实例的 Feature）
            # 注意：这里需要确保 Feature 是可修改的，或者创建新的 Feature
            var icon_feature = DynamicIconFeature.new()
            icon_feature.icon_map = icon_map.duplicate()
            icon_feature.icon_id_key = "current_icon_id"
            # 移除旧的，添加新的
            instance.remove_feature(existing_feature.feature_name)
            instance.add_feature(icon_feature.feature_name, icon_feature)
        else:
            # 创建新的 Feature
            var icon_feature = DynamicIconFeature.new()
            icon_feature.icon_map = icon_map.duplicate()
            icon_feature.icon_id_key = "current_icon_id"
            instance.add_feature(icon_feature.feature_name, icon_feature)
```

### 5. 添加辅助方法

```gdscript
## 检查 Instance 是否已有指定类型的 Feature
func _has_feature(instance: GameplayAbilityInstance, feature_type: GDScript) -> bool:
    var all_features = instance.get_features()
    for feature in all_features:
        if feature.get_script() == feature_type:
            return true
    return false

## 获取指定类型的 Feature
func _get_feature(instance: GameplayAbilityInstance, feature_type: GDScript) -> GameplayAbilityFeature:
    var all_features = instance.get_features()
    for feature in all_features:
        if feature.get_script() == feature_type:
            return feature
    return null

## 初始化黑板变量
func _initialize_blackboard(instance: GameplayAbilityInstance) -> void:
    instance.set_blackboard_var("combo_index", 0)
    instance.set_blackboard_var("combo_expiry_time", 0)
    instance.set_blackboard_var("combo_next_icon", null)
```

### 6. 添加配置验证

```gdscript
## 验证配置的合理性
func _validate_configuration() -> void:
    # 验证：连击段不能为空
    if combo_steps.is_empty():
        push_error("ComboAbilityDefinition [%s]: combo_steps 不能为空" % ability_id)
        return
    
    # 验证：连击窗口期应该为正数
    if window_duration <= 0.0:
        push_error("ComboAbilityDefinition [%s]: window_duration 必须为正数 (%.2f)" % [ability_id, window_duration])
        window_duration = 0.8  # 使用默认值
    
    # 验证：冷却时间应该非负
    if cooldown_duration < 0.0:
        push_error("ComboAbilityDefinition [%s]: cooldown_duration 不能为负数 (%.2f)" % [ability_id, cooldown_duration])
        cooldown_duration = 0.0
    
    # 验证：连击段的有效性
    for i in range(combo_steps.size()):
        var step = combo_steps[i]
        if not is_instance_valid(step):
            push_warning("ComboAbilityDefinition [%s]: combo_steps[%d] 无效" % [ability_id, i])
```

---

## 重构优势

### 1. 消除资源污染 ✅

- **修复前**：直接修改 `execution_tree` 和 `features`，污染资源文件
- **修复后**：使用缓存和临时设置，完全避免资源污染

### 2. 符合享元模式 ✅

- **行为树**：所有实例共享同一个缓存树
- **性能**：只构建一次，之后所有实例共享

### 3. 保持灵活性 ✅

- **手动配置行为树**：如果用户手动配置了 `execution_tree`，优先使用
- **手动配置 Feature**：如果用户手动配置了 Feature，不会被覆盖
- **业务层扩展**：业务层可以继承并重写方法来自定义行为

### 4. 提高易用性 ✅

- **配置验证**：自动检查配置合理性，提供清晰的错误提示
- **代码组织**：Feature 注入逻辑集中管理，易于维护

---

## 与 ActiveAbilityDefinition 的一致性

### 相同的设计模式

1. ✅ **类变量缓存**：`_cached_default_tree` / `_cached_combo_tree`
2. ✅ **临时设置**：临时设置 `execution_tree` 后立即恢复
3. ✅ **实例注入**：在实例中注入 Feature，不修改 Definition
4. ✅ **配置验证**：`_validate_configuration()` 方法

### 特殊处理

1. **连击段处理**：
   - 调用 `ActiveAbilityDefinition._build_default_behavior_tree(false)` 构建不带CD的树
   - 递归移除可能存在的CD节点

2. **图标收集**：
   - 从连击段的 `icon` 属性收集图标
   - 动态注入 `DynamicIconFeature`

3. **黑板初始化**：
   - 初始化连击相关的黑板变量（`combo_index`, `combo_expiry_time` 等）

---

## 使用示例

### 基础使用（模板模式）

```gdscript
# 创建 ComboAbilityDefinition 资源
var combo_def = ComboAbilityDefinition.new()
combo_def.ability_id = "combo_attack"
combo_def.combo_steps = [step1, step2, step3]
combo_def.window_duration = 0.8
combo_def.costs = [VitalCost.new()]
combo_def.cooldown_duration = 1.0

# 系统会自动：
# 1. 构建行为树（如果未手动配置）
# 2. 注入 CostFeature 和 CooldownFeature
# 3. 收集图标并注入 DynamicIconFeature
# 4. 初始化黑板变量
```

### 高级使用（自定义行为树）

```gdscript
# 业务层可以手动配置行为树
combo_def.execution_tree = custom_tree

# 系统会：
# 1. 优先使用手动配置的树
# 2. 仍然注入 Feature（如果不存在）
# 3. 仍然初始化黑板变量
```

### 业务层扩展

```gdscript
# 业务层可以继承并重写
extends ComboAbilityDefinition
class_name CustomComboAbilityDefinition

func _inject_features_to_instance(instance: GameplayAbilityInstance) -> void:
    # 调用父类方法
    super._inject_features_to_instance(instance)
    
    # 添加自定义 Feature
    var custom_feature = CustomFeature.new()
    instance.add_feature(custom_feature.feature_name, custom_feature)
```

---

## 总结

### 重构目标

1. ✅ **消除资源污染**：完全避免修改 Definition
2. ✅ **保持灵活性**：支持手动配置和业务层扩展
3. ✅ **提高易用性**：自动构建行为树和注入 Feature
4. ✅ **代码一致性**：与 `ActiveAbilityDefinition` 保持一致的设计模式

### 关键改进

- **资源安全**：使用缓存和临时设置，完全避免资源污染
- **性能优化**：享元模式，所有实例共享缓存树
- **代码质量**：配置验证、代码组织、错误处理

重构完成后，`ComboAbilityDefinition` 将成为一个安全、高效、易用的连击技能配置模板，同时保持足够的灵活性供业务层扩展。
