# 技能栏系统使用说明

## 概述

技能栏系统提供了完整的技能 UI 和快捷键支持，包括：
- **AbilityButton**: 单个技能按钮组件（显示图标、冷却进度、快捷键）
- **AbilityBar**: 技能栏容器（动态绑定已学会的技能）
- **AbilityShortcutManager**: 快捷键管理器（处理 1-9 数字键、Q/E/R 等字母键，以及鼠标按键）

## 使用方法

### 1. 在主场景中添加 AbilityBar

1. 打开主场景（如 `scenes/main.tscn`）
2. 在 UI 层添加 `AbilityBar` 节点：
   - 加载场景：`res://ui/ability_bar.tscn`
   - 或者直接创建 `Control` 节点，添加脚本 `res://ui/ability_bar.gd`

3. 在场景脚本中初始化：

```gdscript
@onready var ability_bar: AbilityBar = $UI/AbilityBar

func _ready():
    # 获取玩家的能力组件
    var player = $Player
    var ability_comp = player.get_ability_component()
    
    # 初始化技能栏
    ability_bar.initialize(ability_comp)
```

### 2. 快捷键配置

快捷键在 `PlayerData` 资源文件中配置（推荐方式）：

1. 打开 `data/player_data/barbarian.tres`
2. 在 `ability_shortcuts` 字典中添加快捷键映射

```gdscript
ability_shortcuts = {
    "basic_attack": "1",
    "dash": "2",
    "fireball": "Q",
    "heal": "E",
    "special_attack": "MOUSE_RIGHT"
}
```

### 3. 支持的快捷键

- **数字键**: "1", "2", "3", ..., "9"
- **字母键**: "Q", "E", "R", "T", "F", "Z", "X", "C", "V"
- **鼠标按键**: "MOUSE_LEFT", "MOUSE_RIGHT", "MOUSE_MIDDLE", "MOUSE_X1", "MOUSE_X2"

### 4. 错误处理

系统会自动处理以下错误情况：
- ✅ 无效的快捷键格式会被拒绝并显示错误
- ✅ 快捷键冲突会显示警告并自动替换
- ✅ 空值检查，防止崩溃
- ✅ 参数验证，确保数据有效性

## 功能特性

### AbilityButton 功能
- ✅ 显示技能图标
- ✅ 显示冷却进度（进度条和遮罩）
- ✅ 显示快捷键标签
- ✅ 点击按钮施放技能
- ✅ 冷却期间禁用按钮

### AbilityBar 功能
- ✅ 自动绑定已学会的技能
- ✅ 动态添加/移除技能按钮
- ✅ 响应技能学会/遗忘信号

### 快捷键系统
- ✅ 支持数字键 1-9
- ✅ 支持字母键 Q/E/R 等
- ✅ 支持鼠标按键（左键、右键、中键、侧键）
- ✅ 自动绑定到技能
- ✅ 在 `_unhandled_input` 中处理
- ✅ 完善的错误处理和参数验证
- ✅ 快捷键冲突检测和警告

## 注意事项

1. **技能学会时机**: 技能栏会在技能学会时自动添加按钮，确保在 `_ready()` 中先初始化技能栏，再学习技能。

2. **快捷键冲突**: 如果多个技能使用相同快捷键，后绑定的会覆盖先绑定的。

3. **向后兼容**: `_try_attack()` 方法仍然保留，用于鼠标左键攻击，内部调用 `try_cast_ability()`。

