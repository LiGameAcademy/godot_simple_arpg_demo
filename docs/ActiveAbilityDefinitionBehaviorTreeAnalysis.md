# ActiveAbilityDefinition 行为树创建分析

## 问题分析

### 当前实现

```gdscript
func create_instance(owner: Node) -> GameplayAbilityInstance:
    # 2. 动态构建行为树 (如果用户没在编辑器里手动拖树)
    if execution_tree == null:
        execution_tree = _build_default_behavior_tree()  # ⚠️ 修改 Definition
```

### 发现的问题

#### 1. **资源污染风险** 🔴

**问题**：
- 直接修改 `execution_tree` 会污染资源文件
- 如果 Definition 是 `.tres` 资源文件，修改后保存会永久改变资源

**影响**：
- ❌ 资源文件被意外修改
- ❌ 版本控制冲突
- ❌ 多人协作问题

#### 2. **享元模式使用不当** 🟡

**分析**：
- ✅ **Feature**：享元模式（无状态 Resource，可共享）
- ⚠️ **行为树**：理论上也是享元（BTNode extends Resource），但：
  - 第一次创建实例时构建，之后共享（符合享元）
  - 但修改 Definition 有资源污染风险

**当前行为**：
```
第一次 create_instance():
  execution_tree == null → 构建 → 赋值给 Definition → 共享 ✅

后续 create_instance():
  execution_tree != null → 直接使用 → 共享 ✅
```

**问题**：
- 虽然共享了（符合享元），但修改了 Definition（资源污染风险）

#### 3. **性能影响** 🟢

**分析**：
- ✅ 行为树只构建一次（第一次创建实例时）
- ✅ 之后所有实例共享（符合享元模式）
- ✅ 性能开销很小（只在第一次）

**性能开销**：
- 第一次：创建 5-10 个 BTNode 对象（约 0.1-0.5ms）
- 后续：0ms（直接共享）

**结论**：性能影响很小，不是主要问题

---

## 解决方案

### 方案一：延迟构建 + 缓存（推荐）⭐

**核心思路**：不在 Definition 上修改，而是在第一次创建时缓存到类变量

```gdscript
# 类变量：缓存构建好的行为树（享元）
var _cached_behavior_tree: BTNode = null

func create_instance(owner: Node) -> GameplayAbilityInstance:
    # 1. 验证配置
    _validate_configuration()
    
    # 2. 构建或获取缓存的行为树（不修改 Definition）
    var tree_to_use = _get_or_build_behavior_tree()
    
    # 3. 创建实例（使用缓存的行为树）
    var instance = super(owner)
    
    # 4. 如果实例使用的是默认行为树，临时设置（不修改 Definition）
    if execution_tree == null and is_instance_valid(tree_to_use):
        # 临时设置，仅用于创建 BTInstance
        var original_tree = execution_tree
        execution_tree = tree_to_use
        # 重新创建 BTInstance（如果需要）
        # 注意：这里需要确保 BTInstance 使用正确的树
        execution_tree = original_tree  # 恢复
    
    # 5. 注入 Feature
    _inject_features_to_instance(instance)
    
    return instance

func _get_or_build_behavior_tree() -> BTNode:
    # 如果用户手动配置了，使用用户的
    if is_instance_valid(execution_tree):
        return execution_tree
    
    # 如果已缓存，使用缓存的
    if is_instance_valid(_cached_behavior_tree):
        return _cached_behavior_tree
    
    # 构建并缓存
    _cached_behavior_tree = _build_default_behavior_tree()
    return _cached_behavior_tree
```

**问题**：这个方案比较复杂，因为 `BTInstance` 在 `GameplayAbilityInstance._init()` 中创建，需要传入树。

---

### 方案二：在 Instance 中构建（更简单）⭐⭐

**核心思路**：不在 Definition 中构建，而是在 Instance 创建后动态设置

```gdscript
func create_instance(owner: Node) -> GameplayAbilityInstance:
    # 1. 验证配置
    _validate_configuration()
    
    # 2. 调用父类创建实例
    var instance = super(owner)
    
    # 3. 如果用户没配置行为树，动态构建并设置到 Instance
    if execution_tree == null:
        var default_tree = _build_default_behavior_tree()
        # 在 Instance 中设置行为树（不修改 Definition）
        instance._set_execution_tree(default_tree)
    
    # 4. 注入 Feature
    _inject_features_to_instance(instance)
    
    return instance
```

**问题**：需要修改 `GameplayAbilityInstance`，添加 `_set_execution_tree()` 方法。

---

### 方案三：使用临时 Definition 副本（最简单）⭐⭐⭐

**核心思路**：创建 Definition 副本，在副本上修改

```gdscript
func create_instance(owner: Node) -> GameplayAbilityInstance:
    # 1. 验证配置
    _validate_configuration()
    
    # 2. 创建 Definition 副本（避免修改原资源）
    var definition_copy = duplicate(true)
    
    # 3. 在副本上构建行为树
    if definition_copy.execution_tree == null:
        definition_copy.execution_tree = _build_default_behavior_tree()
    
    # 4. 使用副本创建实例
    var instance = GameplayAbilityInstance.new(owner, definition_copy)
    
    # 5. 注入默认黑板数据
    for key in blackboard_defaults:
        instance.set_blackboard_var(key, blackboard_defaults[key])
    
    # 6. 初始化特性
    for feature in features:
        if is_instance_valid(feature):
            instance.add_feature(feature.feature_name, feature)
    
    # 7. 注入额外 Feature
    _inject_features_to_instance(instance)
    
    return instance
```

**优势**：
- ✅ 不修改原 Definition
- ✅ 每个实例独立（如果需要）
- ✅ 实现简单

**劣势**：
- ⚠️ 需要深拷贝 Definition（性能略差）
- ⚠️ 但技能实例通常不会频繁创建

---

### 方案四：类变量缓存（最佳平衡）⭐⭐⭐⭐

**核心思路**：使用类变量缓存构建好的行为树，所有实例共享

```gdscript
# 类变量：缓存构建好的行为树（享元，所有实例共享）
var _cached_default_tree: BTNode = null

func create_instance(owner: Node) -> GameplayAbilityInstance:
    # 1. 验证配置
    _validate_configuration()
    
    # 2. 获取或构建行为树（使用缓存，不修改 Definition）
    var tree_to_use = _get_execution_tree()
    
    # 3. 临时设置 execution_tree（仅用于创建 Instance）
    var original_tree = execution_tree
    execution_tree = tree_to_use
    
    # 4. 创建实例
    var instance = super(owner)
    
    # 5. 恢复 execution_tree（不污染资源）
    execution_tree = original_tree
    
    # 6. 注入 Feature
    _inject_features_to_instance(instance)
    
    return instance

## 获取执行树（优先使用用户配置，否则使用缓存的默认树）
func _get_execution_tree() -> BTNode:
    # 如果用户手动配置了，使用用户的
    if is_instance_valid(execution_tree):
        return execution_tree
    
    # 如果已缓存，使用缓存的
    if is_instance_valid(_cached_default_tree):
        return _cached_default_tree
    
    # 构建并缓存（只构建一次）
    _cached_default_tree = _build_default_behavior_tree()
    return _cached_default_tree
```

**优势**：
- ✅ 不修改 Definition（临时设置后恢复）
- ✅ 符合享元模式（所有实例共享缓存树）
- ✅ 性能最优（只构建一次）
- ✅ 实现简单

**劣势**：
- ⚠️ 需要临时修改 `execution_tree`（但会立即恢复）

---

## 推荐方案

**推荐使用方案四（类变量缓存）**，原因：

1. ✅ **完全避免资源污染**：临时设置后立即恢复
2. ✅ **符合享元模式**：所有实例共享缓存树
3. ✅ **性能最优**：只构建一次
4. ✅ **实现简单**：改动最小

---

## 性能对比

### 当前实现（有资源污染风险）

| 场景 | 性能 |
|------|------|
| 第一次创建实例 | 构建树（~0.1-0.5ms） |
| 后续创建实例 | 0ms（共享） |
| **资源污染** | ❌ 有风险 |

### 方案四（类变量缓存）

| 场景 | 性能 |
|------|------|
| 第一次创建实例 | 构建树（~0.1-0.5ms） |
| 后续创建实例 | 0ms（共享缓存） |
| **资源污染** | ✅ 无风险 |

**结论**：性能相同，但消除了资源污染风险。

---

## 享元模式分析

### Feature（当前实现）✅

- **状态**：无状态 Resource
- **共享**：所有实例共享同一个 Feature 实例
- **内存**：高效

### 行为树（当前实现）⚠️

- **状态**：Resource（BTNode）
- **共享**：所有实例共享（符合享元）
- **问题**：修改 Definition 有资源污染风险

### 行为树（方案四）✅

- **状态**：Resource（BTNode）
- **共享**：所有实例共享缓存树（符合享元）
- **优势**：不修改 Definition，无资源污染风险

---

## 实施建议

### 立即修复（P0）

使用方案四，修复资源污染问题：

```gdscript
# 类变量：缓存构建好的行为树
var _cached_default_tree: BTNode = null

func _get_execution_tree() -> BTNode:
    if is_instance_valid(execution_tree):
        return execution_tree
    if is_instance_valid(_cached_default_tree):
        return _cached_default_tree
    _cached_default_tree = _build_default_behavior_tree()
    return _cached_default_tree
```

---

## 总结

### 当前问题

1. ❌ **资源污染风险**：修改 `execution_tree` 可能污染资源文件
2. ⚠️ **享元模式使用不当**：虽然共享了，但修改了 Definition

### 性能影响

- ✅ **很小**：行为树只构建一次，之后共享
- ✅ **符合享元模式**：所有实例共享同一个树

### 解决方案

- ✅ **方案四（类变量缓存）**：完全消除资源污染，保持享元模式，性能最优

**建议**：立即实施方案四，修复资源污染问题。
