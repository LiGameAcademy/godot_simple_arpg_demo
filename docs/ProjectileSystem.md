# 投射物系统设计文档

## 📋 架构设计

### 核心思想：载具与弹头分离（Carrier-Payload Pattern）

**"投射物是 Effect 的快递员"**

- ✅ **Ability (发射者)**: 负责计算"怎么发"（数量、角度、枪口位置），并实例化投射物
- ✅ **Projectile (载具)**: 负责"怎么飞"（直线、追踪、抛物线），以及"撞到了谁"
- ✅ **Effect (弹头)**: 投射物身上携带的"配置清单"，撞击时应用给目标

### 为什么不用 `GE_SpawnProjectile`？

1. **职责错位**：
   - Effect 负责数值修改、状态施加（扣血、眩晕），它是"结果"
   - Projectile 负责把"弹头"运送到目标，它是"过程"
   - 如果用 Effect 来生成载具，逻辑就变成了"产生结果的过程产生了一个过程"

2. **物理与变换的噩梦**：
   - 投射物需要精确的出生点、飞行方向、散射角度
   - `GameplayEffect` 的 `apply` 方法通常只接收 `target` 和 `instigator`
   - 复杂的枪口坐标和旋转会让 Effect 系统变得臃肿

3. **生命周期管理**：
   - 投射物是一个 `Node` (Area3D)
   - Effect 是一个 `Resource`
   - 让资源去管理节点的实例化和销毁，违背了 Godot 的设计模式

## 🎯 组件说明

### ProjectileBase

**职责**：运动控制、碰撞检测、效果传递

**关键属性**：
- `speed`: 飞行速度
- `max_lifetime`: 最大生命周期
- `homing_acceleration`: 追踪加速度（0 为直线，>0 为追踪）
- `payload_effects`: 携带的弹头（Effect 列表）
- `target_reference`: 追踪目标（可选）

**关键方法**：
- `_handle_impact(target)`: 撞击结算，传递 Effect 给目标
- `_deliver_payload(target)`: 传递弹头，应用所有携带的 Effect

### ProjectileAbility

**职责**：计算发射参数，实例化投射物，注入弹头

**关键属性**：
- `projectile_scene`: 投射物场景（必须继承自 `ProjectileBase`）
- `projectile_count`: 发射数量（多重施法）
- `spread_angle`: 散射角度（度）
- `enable_homing`: 是否追踪目标
- `muzzle_node_path`: 枪口节点路径

**关键方法**：
- `_on_cast()`: 重写施放逻辑，生成投射物并注入弹头
- `_get_muzzle_transform()`: 获取枪口位置和朝向

## 📝 使用示例

### 案例 A：火球术 (Fireball)

#### 1. 创建投射物场景

**场景结构**：
```
Fireball (Area3D, ProjectileBase)
├── MeshInstance3D (火球模型)
├── CollisionShape3D (碰撞体)
└── GPUParticles3D (尾迹特效)
```

**脚本配置**：
```gdscript
# Fireball.gd (继承自 ProjectileBase)
extends ProjectileBase

func _ready() -> void:
    super._ready()
    speed = 15.0
    homing_acceleration = 0.0  # 直线飞行
    max_lifetime = 3.0
```

#### 2. 创建技能资源

**Fireball.tres** (ProjectileAbility):
- `projectile_scene`: `res://scenes/projectiles/fireball.tscn`
- `target_effects`: 
  - `GE_Damage_Fire` (火焰伤害)
  - `GE_Knockback` (击退)
  - `GE_Explosion_AOE` (爆炸范围伤害)
- `projectile_count`: 1
- `spread_angle`: 0
- `enable_homing`: false

#### 3. 配置效果

**GE_Damage_Fire.tres**:
- 伤害类型：火焰
- 伤害值：50

**GE_Explosion_AOE.tres**:
- 范围：3.0 米
- 伤害：30（范围伤害）

### 案例 B：奥术飞弹 (Arcane Missiles)

#### 1. 创建投射物场景

**场景结构**：
```
ArcaneBolt (Area3D, ProjectileBase)
├── MeshInstance3D (奥术球模型)
├── CollisionShape3D (碰撞体)
└── GPUParticles3D (奥术尾迹)
```

**脚本配置**：
```gdscript
# ArcaneBolt.gd (继承自 ProjectileBase)
extends ProjectileBase

func _ready() -> void:
    super._ready()
    speed = 10.0
    homing_acceleration = 20.0  # 开启追踪！
    max_lifetime = 5.0
```

#### 2. 创建技能资源

**ArcaneMissiles.tres** (ProjectileAbility):
- `projectile_scene`: `res://scenes/projectiles/arcane_bolt.tscn`
- `target_effects`: 
  - `GE_Damage_Arcane` (奥术伤害)
- `projectile_count`: 3 (多重施法)
- `spread_angle`: 45 (扇形散射)
- `enable_homing`: true

**逻辑说明**：
- 一出生先按散射角度飞
- 然后被 `_process_homing` 慢慢拉向目标
- 形成漂亮的曲线轨迹

### 案例 C：穿透箭 (Piercing Arrow)

#### 1. 投射物配置

```gdscript
# Arrow.gd
extends ProjectileBase

func _ready() -> void:
    super._ready()
    speed = 25.0
    homing_acceleration = 0.0
    max_lifetime = 4.0
    piercing = true  # 开启穿透
    max_pierce_count = 3  # 最多穿透3个目标
```

#### 2. 技能配置

**PiercingArrow.tres**:
- `projectile_scene`: `res://scenes/projectiles/arrow.tscn`
- `target_effects`: `GE_Damage_Physical`
- `projectile_count`: 1
- `spread_angle`: 0

## 🔧 高级用法

### 自定义枪口位置

在 `ProjectileAbility._on_cast()` 中，可以通过 Context 传递枪口信息：

```gdscript
# 在 player.gd 中
func try_cast_ability(ability_id: StringName, target: Node = null, context: Dictionary = {}) -> void:
    # 查找枪口节点
    var muzzle = $Weapon/Muzzle
    if is_instance_valid(muzzle):
        context["muzzle_transform"] = muzzle.global_transform
    
    super(ability_id, target, context)
```

### 传递额外上下文

投射物撞击时，会将 `impact_context` 传递给 Effect：

```gdscript
# 在 ProjectileAbility 中
projectile_base.impact_context = {
    "ability_id": ability_id,
    "instigator": instigator,
    "is_crit": true,  # 暴击信息
    "damage_multiplier": 1.5
}
```

Effect 可以在 `_apply()` 中读取这些信息：

```gdscript
# GE_Damage.gd
func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
    var base_damage = 50.0
    var multiplier = context.get("damage_multiplier", 1.0)
    var final_damage = base_damage * multiplier
    # ...
```

### 穿透逻辑

投射物支持穿透，可以在撞击后继续飞行：

```gdscript
# ProjectileBase._handle_impact()
if piercing and (max_pierce_count < 0 or _pierce_count < max_pierce_count):
    _pierce_count += 1
    return  # 继续飞行
```

## 📊 架构优势

### 1. 职责清晰

- **Ability**: 只负责"发射逻辑"
- **Projectile**: 只负责"飞行和碰撞"
- **Effect**: 只负责"数值修改"

### 2. 易于扩展

- 可以轻松添加新的投射物类型（抛物线、弹跳等）
- 可以组合不同的 Effect（伤害 + 状态 + 击退）
- 可以自定义发射逻辑（多重施法、散射等）

### 3. 符合 Godot 设计模式

- 投射物是 `Node`，由场景管理
- Effect 是 `Resource`，由资源系统管理
- 职责分离，各司其职

## 🎓 最佳实践

1. **投射物场景应该独立**：
   - 不要将投射物添加到角色的子节点
   - 应该添加到场景根节点或专门的容器

2. **Effect 应该深拷贝**：
   - 使用 `payload_effects.duplicate(true)` 避免引用问题

3. **枪口位置应该精确**：
   - 使用骨骼或 Marker3D 定位枪口
   - 避免使用角色中心点

4. **碰撞过滤要合理**：
   - 设置正确的 `collision_mask`
   - 在 `_should_impact()` 中过滤无效目标

## 📚 相关文档

- [GameplayEffect 系统文档](./EffectLifecycleSystem.md)
- [ActiveAbility 使用指南](../addons/godot_gameplay_abilities/docs/API.md)

