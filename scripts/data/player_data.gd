extends Resource
class_name PlayerData

@export var attribute_sets: Array[GameplayAttributeSet] ## 属性集
@export var vitals: Array[GameplayVital]
@export var initial_abilities: Array[ActiveAbility] = []  ## 初始技能列表（所有技能都通过技能系统管理）

@export_group("Shortcuts")
## 技能快捷键映射（技能 ID -> 快捷键字符串）
## 支持的快捷键：
## - 数字键: "1", "2", "3", ..., "9"
## - 字母键: "Q", "E", "R", "T", "F", "Z", "X", "C", "V"
## - 鼠标按键: "MOUSE_LEFT", "MOUSE_RIGHT", "MOUSE_MIDDLE", "MOUSE_X1", "MOUSE_X2"
## 示例：
## {
##   "slash": "1",
##   "dash": "2",
##   "fireball": "Q",
##   "heal": "E",
##   "special_attack": "MOUSE_RIGHT"
## }
@export var ability_shortcuts: Dictionary[StringName, String] = {}
