extends GameplayEquip
class_name ArpgEquip

## 业务层装备类
## 扩展只读装备配置，运行数量、耐久等由插件实例持有。
## 符合开闭原则：不修改插件层代码，通过继承扩展功能

## 装备模型场景（用于在角色身上显示装备）
@export var equip_model_scene: PackedScene = null
## 装备挂点名称（用于确定装备在哪个挂点上显示）
## 常见值：&"hand_right", &"hand_left", &"head", &"chest" 等
@export var attachment_point: StringName = &"hand_right"
## 装备携带的技能列表（装备时自动学会，卸下时自动遗忘）
@export var abilities: Array[GameplayAbilityDefinition] = []

@export var attributes: Dictionary[String, float] = {}
