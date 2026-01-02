# 属性修改器 Source ID 重构总结

## 概述
将 `GameplayAttributeModifier` 的 `source: Node` 改为 `source_id: StringName`，并实现根据 `source_id` 批量移除属性修改器的功能，同时创建了对应的效果类。

---

## 改动内容

### 1. GameplayAttributeModifier ✅

**改动前：**
```gdscript
var source: Node = null  ## 来源（可选，用于追溯是谁施加的）

func _init(
    p_attribute_id: StringName = &"", 
    p_value: float = 1.0, 
    p_modifier_type: ModifierType = ModifierType.MULTIPLY,
    p_source: Node = null
) -> void:
    source = p_source
```

**改动后：**
```gdscript
@export var source_id: StringName = &""  ## 来源ID（可选，用于批量移除）

func _init(
    p_attribute_id: StringName = &"", 
    p_value: float = 1.0, 
    p_modifier_type: ModifierType = ModifierType.MULTIPLY,
    p_source_id: StringName = &""
) -> void:
    source_id = p_source_id
```

**优势：**
- ✅ 支持批量移除（通过 source_id）
- ✅ 不依赖 Node 引用，更灵活
- ✅ 与 `GameplayAbilityModifier` 的 `source` 字段保持一致（都是 String）

---

### 2. GameplayAttributeInstance ✅

**新增方法：**
```gdscript
## 根据 source_id 批量移除修改器
## [param] source_id: StringName 来源ID
func remove_modifiers_by_source(source_id: StringName) -> void:
    if source_id.is_empty():
        return
    
    var has_removed = false
    for modifier_type in _modifiers.keys():
        var mods: Array = _modifiers[modifier_type]
        var mods_to_remove: Array = []
        
        for mod in mods:
            if mod is GameplayAttributeModifier and mod.source_id == source_id:
                mods_to_remove.append(mod)
        
        for mod in mods_to_remove:
            mods.erase(mod)
            has_removed = true
    
    if has_removed:
        _on_data_changed()
```

**功能：**
- 遍历所有修改器类型（ADD、MULTIPLY、OVERRIDE）
- 找到匹配 `source_id` 的修改器并移除
- 触发重新计算

---

### 3. GameplayAttributeComponent ✅

**新增方法：**
```gdscript
## 根据 source_id 批量移除属性修改器
## [param] source_id: StringName 来源ID
func remove_modifiers_by_source(source_id: StringName) -> void:
    if source_id.is_empty():
        return
    
    # 遍历所有属性实例，移除匹配的修改器
    for attribute_id in _attributes.keys():
        var instance = _attributes[attribute_id]
        if is_instance_valid(instance):
            instance.remove_modifiers_by_source(source_id)
```

**功能：**
- 遍历所有属性实例
- 调用每个实例的 `remove_modifiers_by_source` 方法

---

### 4. GE_AttributeModifier 效果 ✅

**新文件：** `addons/godot_gameplay_abilities/scripts/effects/ge_attribute_modifier.gd`

**功能：**
- 在目标上应用属性修改器
- 支持通过 `source_id` 批量移除
- 自动设置 `source_id`（从 context 读取或使用默认值）

**关键特性：**
- 支持从 `context.custom_data["source_id"]` 读取 source_id
- 如果未设置，使用效果资源路径作为默认 source_id
- 支持层数计算（通过 context 中的 stacks）

**使用示例：**
```gdscript
# 在状态数据的 apply_effects 中
var modifier_effect = GE_AttributeModifier.new()
modifier_effect.modifiers = [strength_modifier]
modifier_effect.source_id = "status.strength_blessing"
```

---

### 5. GE_RemoveAttributeModifier 效果 ✅

**新文件：** `addons/godot_gameplay_abilities/scripts/effects/ge_remove_attribute_modifier.gd`

**功能：**
- 根据 `source_id` 批量移除属性修改器
- 支持从 context 读取 source_id

**使用示例：**
```gdscript
# 在状态数据的 remove_effects 中
var remove_effect = GE_RemoveAttributeModifier.new()
remove_effect.source_id = "status.strength_blessing"
```

---

## 使用方式

### 在状态系统中使用

**方式1：在状态数据中配置效果**
```gdscript
# GameplayStatusData
apply_effects = [
    GE_AttributeModifier (配置 modifiers 和 source_id)
]
remove_effects = [
    GE_RemoveAttributeModifier (配置 source_id)
]
```

**方式2：通过 context 传递 source_id**
```gdscript
# 应用状态时
var context = {
    "source_id": "status.strength_blessing"
}
status_component.apply_status(status_data, instigator, 1, context)

# 效果会自动从 context 读取 source_id
```

---

## 向后兼容性

⚠️ **破坏性改动**：
- `GameplayAttributeModifier.source: Node` → `source_id: StringName`
- 需要更新所有使用 `source` 字段的代码

**迁移建议：**
1. 如果之前使用 `source` 存储 Node 引用，改为使用 Node 的路径或唯一ID
2. 例如：`mod.source_id = "entity." + node.get_path()` 或使用唯一标识符

---

## 优势总结

1. **统一接口**：属性修改器和技能行为修改器都支持 `source_id` 批量移除
2. **性能优化**：批量移除比逐个移除更高效
3. **效果系统集成**：完全用效果实现，统一接口
4. **灵活性**：支持从 context 动态传递 source_id
5. **无状态设计**：Effect 无状态，符合设计理念

---

## 后续工作

1. **更新状态系统**：将状态系统中的属性修改器管理改为使用效果
2. **迁移现有数据**：更新所有使用旧 `source` 字段的状态数据
3. **文档更新**：更新使用文档和示例

---

## 相关文件

- `addons/godot_gameplay_abilities/scripts/attributes/gameplay_attribute_modifier.gd`
- `addons/godot_gameplay_abilities/scripts/attributes/gameplay_attribute_instance.gd`
- `addons/godot_gameplay_abilities/scripts/components/gameplay_attribute_component.gd`
- `addons/godot_gameplay_abilities/scripts/effects/ge_attribute_modifier.gd`
- `addons/godot_gameplay_abilities/scripts/effects/ge_remove_attribute_modifier.gd`

