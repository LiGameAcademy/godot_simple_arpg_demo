# 伤害飘字 Cue 实装指南

## 快速开始

伤害飘字系统已经配置完成，只需要在 Godot 编辑器中验证配置即可。

## 验证配置

### 1. 检查 Cue 资源

打开 `data/cues/hit_cue_physical.tres`，确认：
- ✅ 包含 `CueFloatingText` 组件
- ✅ `attachment_point` 设置为 `"head"`
- ✅ `text_format` 包含 `{value}` 占位符

### 2. 检查技能配置

打开 `data/abilities/basic_attack.tres`，确认：
- ✅ `GE_ApplyDamage` 效果的 `cue` 字段已引用 `hit_cue_physical.tres`

### 3. 运行测试

1. 运行游戏
2. 攻击敌人
3. 观察敌人头顶是否出现白色飘字（如 "-10"）

## 系统工作流程

```
玩家攻击
    ↓
ActiveAbility._on_cast()
    ↓
GE_ApplyDamage._apply()
    ↓
health_vital.apply_damage() → 返回 final_damage
    ↓
context["final_damage"] = final_damage
    ↓
GameplayEffect._execute_cue() (自动调用)
    ↓
GameplayCueManager.execute_cue()
    ↓
计算挂点位置 (get_attachment_point("head"))
    ↓
CueFloatingText.execute()
    ↓
显示飘字: "-{value}" (value = final_damage)
```

## 配置说明

### Cue 资源结构

```gdscript
GameplayCue (hit_cue_physical.tres)
  └─ cues: Array[GameplayCueBase]
      └─ [0] CueFloatingText
          ├─ attachment_point: "head"
          ├─ text_color: Color(1, 1, 1, 1)  # 白色
          ├─ text_format: "-{value}"
          └─ text_duration: 1.0
```

### 伤害效果配置

```gdscript
GE_ApplyDamage (在 basic_attack.tres 中)
  ├─ damage_multiplier: 1.0
  └─ cue: GameplayCue (引用 hit_cue_physical.tres)
```

## 挂点系统

### 自动查找挂点

系统会按以下顺序查找挂点：

1. **优先**: 调用 `target.get_attachment_point("head")` 方法
2. **其次**: 查找 `Visuals/Head` 节点
3. **回退**: 使用目标节点的位置

### 为角色添加挂点（可选）

在 `CharacterBase` 中已经实现了 `get_attachment_point()` 方法，支持常见挂点：
- `"head"` → `Visuals/Head`
- `"body"` → `Visuals/Body`
- `"foot"` → `Visuals/Foot`
- 等等

如果角色场景中有对应的节点，系统会自动使用。

## 自定义配置

### 修改飘字颜色

在 `hit_cue_physical.tres` 中修改 `CueFloatingText` 的 `text_color`：
- 物理伤害：白色 `Color(1, 1, 1, 1)`
- 火焰伤害：红色 `Color(1, 0.2, 0.2, 1)`
- 冰霜伤害：蓝色 `Color(0.2, 0.5, 1, 1)`

### 修改飘字格式

修改 `text_format` 字符串：
- `"-{value}"` → 显示 "-10"
- `"{value} 伤害"` → 显示 "10 伤害"
- `"造成 {value} 点伤害"` → 显示 "造成 10 点伤害"

### 修改挂点位置

修改 `attachment_point`：
- `"head"` → 头顶
- `"body"` → 身体中心
- `"root"` → 根节点位置

### 微调显示位置（使用偏移量）

在 Cue 组件中配置 `offset` 字段，可以微调特效/飘字的精确位置：
- `Vector3(0, 0.2, 0)` → 在挂点上方 0.2 单位
- `Vector3(0, -0.1, 0)` → 在挂点下方 0.1 单位
- `Vector3(0.3, 0, 0)` → 在挂点右侧 0.3 单位

**示例**：如果飘字想显示在头顶稍微上方一点，可以设置：
- `attachment_point`: `"head"`
- `offset`: `Vector3(0, 0.3, 0)` （头顶上方 0.3 单位）

## 常见问题

### Q: 飘字不显示？

**检查清单**:
1. ✅ `basic_attack.tres` 中 `GE_ApplyDamage` 的 `cue` 字段是否已设置？
2. ✅ `hit_cue_physical.tres` 中是否包含 `CueFloatingText` 组件？
3. ✅ `text_format` 是否包含 `{value}` 占位符？
4. ✅ 游戏运行时是否真的造成了伤害？（检查控制台输出）

### Q: 飘字位置不对？

**解决方案**:
- 检查 `attachment_point` 设置
- 在角色场景中添加对应的挂点节点（如 `Visuals/Head`）
- 或者在角色脚本中实现 `get_attachment_point()` 方法

### Q: 飘字显示为 "-0" 或格式错误？

**解决方案**:
- 检查 `context["final_damage"]` 是否正确传递
- 确认 `text_format` 使用 `{value}` 而不是其他名称
- 检查 `CueFloatingText._execute()` 中的文本格式化逻辑

## 扩展：创建不同类型的伤害飘字

### 示例：火焰伤害飘字

1. 创建新资源：`data/cues/hit_cue_fire.tres`
2. 配置：
   - `text_color`: 红色 `Color(1, 0.2, 0.2, 1)`
   - `text_format`: `"-{value}"` (火焰伤害)
3. 在火焰技能的效果中引用此 Cue

### 示例：治疗飘字

1. 创建新资源：`data/cues/heal_cue.tres`
2. 配置：
   - `text_color`: 绿色 `Color(0.2, 1, 0.2, 1)`
   - `text_format`: `"+{value}"` (治疗数值)
3. 在治疗效果中引用此 Cue

## 完成！

现在伤害飘字系统已完全实装。运行游戏，攻击敌人，应该能看到白色飘字从敌人头顶飘出！
