# TargetingStrategy 使用指南

## 📖 概述

`TargetingStrategy` 是框架层提供的**目标获取策略系统**，用于替代 `TargetingType` 枚举，提供更好的扩展性和灵活性。

### 为什么需要策略模式？

**问题**：`TargetingType` 枚举混合了多个概念，扩展性差：
- ❌ 无法支持复杂场景（多目标、区域、链式等）
- ❌ 枚举值会不断膨胀
- ❌ 与现有的 `HitDetectorBase`、`TargetingScorer` 架构不一致

**解决方案**：使用策略模式，将目标获取逻辑完全抽象为独立的组件。

## 🎯 架构设计

```
GameplayAbility (基类)
    └── ActiveAbility
            ├── targeting_strategy: TargetingStrategy (推荐)
            └── targeting_type: TargetingType (已弃用，向后兼容)
```

### 组件关系

- **TargetingStrategy**: 负责"获取哪些目标"（策略层）
- **HitDetectorBase**: 负责"如何检测目标"（检测层）
- **TargetingScorer**: 负责"选择哪个目标"（选择层）

## 📝 使用方式

### 方式1：使用预设策略（推荐）

框架提供了4个预设策略类，覆盖常见场景：

#### 1. SelfTargetingStrategy（自身目标）
```gdscript
# 适用于：自身Buff、治疗自己、护盾等
@export var targeting_strategy: TargetingStrategy = SelfTargetingStrategy.new()
```

#### 2. UnitTargetingStrategy（单位目标）
```gdscript
# 适用于：指向性技能、治疗友军、攻击敌军等
# 优先级：input_target > context.target_unit > hit_detector
@export var targeting_strategy: TargetingStrategy = UnitTargetingStrategy.new()
```

#### 3. GroundTargetingStrategy（地面目标）
```gdscript
# 适用于：AOE技能、放置类技能、范围伤害等
# 通常配合 hit_detector 使用
@export var targeting_strategy: TargetingStrategy = GroundTargetingStrategy.new()
```

#### 4. NoTargetingStrategy（无目标）
```gdscript
# 适用于：战吼、光环、被动触发等
@export var targeting_strategy: TargetingStrategy = NoTargetingStrategy.new()
```

### 方式2：自定义策略（高级）

对于复杂场景，可以实现自定义策略：

```gdscript
extends TargetingStrategy
class_name ChainTargetingStrategy

## 链式目标策略
## 适用于：闪电链、弹射等技能

@export var max_chain_count: int = 3
@export var chain_range: float = 5.0

func _resolve_targets(instigator: Node, input_target: Node, context: Dictionary) -> Array[Node]:
	var targets: Array[Node] = []
	var current_target = input_target
	var visited: Array[Node] = []
	
	for i in range(max_chain_count):
		if not is_instance_valid(current_target):
			break
		
		targets.append(current_target)
		visited.append(current_target)
		
		# 查找下一个目标（在范围内，未访问过的）
		current_target = _find_next_chain_target(instigator, current_target, visited, context)
	
	return targets

func _find_next_chain_target(instigator: Node, from_target: Node, visited: Array[Node], context: Dictionary) -> Node:
	# 实现链式查找逻辑
	# ...
	return null
```

### 方式3：向后兼容（已弃用）

如果不想立即迁移，可以继续使用枚举：

```gdscript
# 不设置 targeting_strategy，使用 targeting_type
@export var targeting_type: TargetingType = TargetingType.UNIT_TARGET
```

**注意**：枚举方式已标记为已弃用，建议迁移到策略模式。

## 🔄 迁移指南

### 从枚举迁移到策略

**旧代码**：
```gdscript
@export var targeting_type: TargetingType = TargetingType.SELF_ONLY
```

**新代码**：
```gdscript
@export var targeting_strategy: TargetingStrategy = SelfTargetingStrategy.new()
```

### 映射关系

| 枚举值 | 对应策略 |
|--------|---------|
| `SELF_ONLY` | `SelfTargetingStrategy` |
| `UNIT_TARGET` | `UnitTargetingStrategy` |
| `GROUND_TARGET` | `GroundTargetingStrategy` |
| `NO_TARGET` | `NoTargetingStrategy` |

## 💡 最佳实践

### 1. 优先使用策略模式
- ✅ 提供更好的扩展性
- ✅ 符合"开闭原则"
- ✅ 与现有架构一致

### 2. 组合使用组件
```gdscript
# 示例：AOE技能
@export var targeting_strategy: TargetingStrategy = GroundTargetingStrategy.new()
@export var hit_detector: HitDetectorBase = AreaHitDetector.new()  # 范围检测
@export var target_filters: Array[GameplayFilterData] = [EnemyFilter.new()]  # 只选敌人
```

### 3. 自定义策略的命名
- 使用描述性名称：`ChainTargetingStrategy`、`DirectionalTargetingStrategy`
- 遵循命名规范：`*TargetingStrategy`

## 🎓 教学建议

### 对于初学者
1. 先使用预设策略，理解基本概念
2. 理解策略模式的优势
3. 逐步迁移现有技能

### 对于进阶开发者
1. 实现自定义策略，支持复杂场景
2. 组合多个组件，实现复杂目标获取逻辑
3. 考虑性能优化（对象池、缓存等）

## 📚 相关文档

- [TargetingType 分析文档](./TargetingTypeAnalysis.md)
- [HitDetectorBase API 文档](../addons/godot_gameplay_abilities/docs/API.md)
- [TargetingScorer API 文档](../addons/godot_gameplay_abilities/docs/API.md)

