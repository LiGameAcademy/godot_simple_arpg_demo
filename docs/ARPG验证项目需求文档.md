# 📘 Project Aether：ARPG 验证项目需求文档 (Wiki v1.0)

**负责人：** 老李
**引擎版本：** Godot 4.x
**核心目标：** 验证通用战斗插件 (Ability System Plugin) 的完整性、解耦性与数据驱动能力。

---

## 1. 角色与职业系统 (Character & Class)

为了节省美术资源并测试插件的**动态技能组切换**能力，我们将实现**“单主角 + 多武器”**模式。角色本身只有属性，技能完全由手中的武器决定。

### 1.1 主角：旅行者 (The Traveler)
* **基础设定：** 玩家控制的唯一角色。
* **特性：** 可以装备不同武器，装备武器后会替换整套 `SkillSet`（技能组）和属性修正。

### 1.2 武器/职业设计

#### ⚔️ 武器 A：大剑 (Greatsword) —— 狂战士风格
* **测试重点：** 物理判定 (Area3D)、连招 (Combo)、霸体状态 (Super Armor)、近战手感。
* **资源需求：** 1个模型，3个攻击动画，1个冲锋动画。

#### 🪄 武器 B：法杖 (Staff) —— 元素师风格
* **测试重点：** 投射物 (Projectile)、施法引导 (Channeling)、魔法消耗 (Mana)、元素反应 (Tags)。
* **资源需求：** 1个模型，1个施法动画，1个射击动画。

---

## 2. 属性系统设计 (Attribute System)

我们需要验证插件的 **属性集 (AttributeSet)** 和 **数值缩放 (ScalableValue)** 功能。

### 2.1 基础属性 (Primary Stats)
*这些属性随等级成长，并影响二级属性。*
| 属性名 (ID) | 基础值 | 成长系数/级 | 描述 | 插件验证点 |
| :--- | :--- | :--- | :--- | :--- |
| `strength` (力量) | 10 | +2.0 | 增加近战伤害 | 属性依赖计算 |
| `intelligence` (智力) | 10 | +2.0 | 增加法术伤害和蓝量上限 | 属性依赖计算 |
| `vitality` (体质) | 10 | +3.0 | 增加血量上限 | 属性依赖计算 |

### 2.2 衍生属性 (Derived Stats)
*这些属性由基础属性通过公式计算得出。*
| 属性名 (ID) | 计算公式 | 描述 |
| :--- | :--- | :--- |
| `max_hp` | `vitality * 10` | 生命上限 |
| `max_mp` | `intelligence * 10` | 魔法上限 |
| `melee_atk` | `strength * 2 + 5` | 近战攻击力 |
| `magic_atk` | `intelligence * 2.5` | 魔法攻击力 |
| `cooldown_reduction` | `0` (默认) | 冷却缩减 (通过装备/Buff改变) |

### 2.3 资源属性 (Current Resources)
| 属性名 (ID) | 初始逻辑 | 描述 |
| :--- | :--- | :--- |
| `hp` | `= max_hp` | 当前生命值，归零死亡 |
| `mp` | `= max_mp` | 当前魔法值，不足无法施法 |

---

## 3. 技能详细设计 (Skills Wiki)

所有技能必须使用 `SkillResource` + `EffectResource` 的组合来实现。

### 3.1 大剑系技能 (Greatsword Set)

#### Skill 1: 重斩三连 (Triple Slash)
* **类型：** 主动 / 无目标 / 即时
* **逻辑：**
    * **Combo 1:** 横扫 (Area: 扇形 120度, 半径 2m)。造成 `100% melee_atk` 伤害。
    * **Combo 2:** 横扫 (Area: 扇形 120度, 半径 2m)。造成 `100% melee_atk` 伤害。
    * **Combo 3:** 纵劈 (Area: 矩形 1x4m)。造成 `150% melee_atk` 伤害，并施加 **击退 (Knockback)** 效果。
* **插件验证：** 连招窗口期检测 (Combo Window)、多段 Area 判定。

#### Skill 2: 旋风斩 (Whirlwind)
* **类型：** 主动 / 引导 (Channeling)
* **消耗：** 10 MP / 秒
* **逻辑：**
    * 给自身施加 `Buff_Spinning`。
    * Buff 效果：每 0.25秒 对周围 (半径 3m 圆形) 造成 `30% melee_atk` 伤害。
    * Buff 期间：移动速度降低 20%，获得标签 `super_armor` (霸体，免疫击退)。
* **插件验证：** 周期性 Effect (Tick)、移动组件与 Tag 的交互。

#### Skill 3: 冲锋 (Charge)
* **类型：** 主动 / 目标点
* **逻辑：**
    * 向鼠标方向快速位移 5m (耗时 0.2秒)。
    * 位移过程中获得标签 `invulnerable` (无敌)。
* **插件验证：** 位移 Effect、无敌 Tag 的伤害免疫机制。

---

### 3.2 法杖系技能 (Staff Set)

#### Skill 1: 奥术飞弹 (Arcane Bolt)
* **类型：** 主动 / 指向性 (Target Unit) or 方向 (Direction)
* **逻辑：**
    * 发射一个投射物。速度 15m/s。
    * 命中造成 `80% magic_atk` 伤害。
    * **特性：** 如果鼠标悬停在敌人身上，投射物变为 **追踪 (Homing)**；如果是空地，变为 **直线 (Linear)**。
* **插件验证：** 智能施法目标判定、投射物运动策略切换。

#### Skill 2: 冰霜新星 (Frost Nova)
* **类型：** 主动 / 自身中心 AOE
* **冷却：** 8秒
* **逻辑：**
    * 对周围 4m 范围敌人造成 `50% magic_atk` 伤害。
    * 施加 Debuff `Frozen` (冰冻)：无法移动，持续 2秒。给敌人加上标签 `status_frozen`。
* **插件验证：** Debuff 施加、Tag 限制移动。

#### Skill 3: 豪火球之术 (Fireball)
* **类型：** 主动 / 弹道 (Projectile)
* **冷却：** 5秒
* **逻辑：**
    * 发射一枚大火球。
    * 命中或到达最大射程后 **爆炸**。
    * 爆炸生成一个 `Effect_Area`，对半径 3m 内造成 `200% magic_atk` 伤害。
    * 施加 Debuff `Burning` (燃烧)：每秒造成 10点 真实伤害，持续 5秒。给敌人加上标签 `status_burning`。
* **插件验证：** 投射物死亡触发 AOE、DoT 伤害。

---

## 4. 标签与元素反应系统 (Tag & Reaction)

这是测试插件数据驱动能力的核心。

### 4.1 核心状态标签
| 标签 ID | 显示名 | 效果逻辑 (由各系统监听) |
| :--- | :--- | :--- |
| `disable_move` | 禁锢 | 移动组件停止移动 |
| `disable_skill` | 沉默 | 技能组件禁止释放技能 |
| `invulnerable` | 无敌 | 伤害结算流程中将伤害置为 0 |
| `super_armor` | 霸体 | 免疫 `Effect_Knockback` (击退效果) |
| `status_wet` | 潮湿 | 易伤状态 (作为反应前置) |
| `status_burning`| 燃烧 | 持续扣血 |
| `status_frozen` | 冰冻 | 包含 `disable_move` |

### 4.2 元素反应机制 (Combo Logic)
*需要在 `EffectDamage` 的结算逻辑中配置连携规则。*

1.  **蒸发 (Vaporize):**
    * **触发：** 火属性伤害 命中 带有 `status_wet` 的目标。
    * **效果：** 伤害倍率 x 1.5，并移除 `status_wet`。
2.  **碎冰 (Shatter):**
    * **触发：** 物理伤害(大剑) 命中 带有 `status_frozen` 的目标。
    * **效果：** 造成额外 50 点真实伤害，并移除 `status_frozen` (解除冰冻)。

---

## 5. 敌人与 AI 设计 (Enemy & AI)

AI 必须通过调用插件的 `try_activate_skill` 接口来行动，模拟玩家操作。

### 5.1 杂兵：史莱姆 (Slime)
* **AI 逻辑 (State Machine):**
    * `Idle`: 随机徘徊。
    * `Chase`: 发现玩家，寻路靠近。
    * `Attack`: 距离 < 1m，停止移动，播放攻击前摇，调用 **普通攻击技能**。
* **技能：**
    * **撞击：** 前摇 0.5秒，对前方 1m 造成伤害。

### 5.2 精英：骷髅射手 (Skeleton Archer)
* **AI 逻辑:**
    * `Kiting`: 试图保持与玩家距离 5m-8m。如果太近就后退，太远就追。
    * `Attack`: 距离合适且 CD 就绪，调用 **射击技能**。
* **技能：**
    * **骨箭：** 直线投射物，可被玩家走位躲避。

### 5.3 BOSS：晶歌守卫 (Crystal Guardian)
* **阶段一 (100% - 50% HP):**
    * **技能 A：践踏 (Stomp):** 巨大的红色预警圈 (Decal)，2秒后造成全屏震动和高额 AOE 伤害。
* **阶段二 (50% HP - 触发剧情):**
    * **动作：** 走到场地中央，进入 `Invulnerable` 状态。
    * **机制：** 场地四周刷新 3 个 **能量水晶 (Energy Crystal)**。
    * **逻辑：** BOSS 身上挂载 `Buff_Shield` (给予 `invulnerable` 标签)。只有当 3 个水晶全部死亡，`Buff_Shield` 才会被移除。
    * **技能 B：激光扫射 (Laser Sweep):** 顺时针旋转的激光射线，玩家必须跟着跑。

---

## 6. 天赋树设计 (Talent System)

测试 `Modifier` 系统对技能的动态修改。

* **天赋 Tier 1 (通用):**
    * **迅捷 (Swiftness):** 移动速度 +10%。(修改 Attribute)
* **天赋 Tier 2 (大剑专精):**
    * **剑气 (Sword Wave):** “重斩三连”的第三段攻击现在会发射一个飞行波。(Skill Modifier: 向 Effect 列表追加一个 `Effect_Projectile`)
* **天赋 Tier 3 (法杖专精):**
    * **多重施法 (Multicast):** “奥术飞弹”现在一次发射 3 枚。(Skill Modifier: 修改 Spawn Count 属性)

---

## 7. 插件开发检查清单 (Dev Checklist)

在开发这个游戏时，时刻检查插件是否满足以下通用性：

* [ ] 玩家的控制代码 (Controller) 里是否包含伤害公式？ -> **如果有，重构！伤害公式必须在插件里。**
* [ ] 敌人的 AI 是否直接操作了动画播放器？ -> **如果有，重构！AI 只能调技能，技能调动画。**
* [ ] 标签 `status_frozen` 是否写死在了 `Unit.gd` 里？ -> **如果有，重构！必须用 `TagManager`。**
* [ ] 切换武器时，是否需要重启游戏或重置节点？ -> **验证：必须支持运行时的 Resource 热替换。**

---

老李，这份文档够详细吗？如果可以，你可以先着手搭建**角色控制 (Milestone 1)**，先把大剑挥起来！