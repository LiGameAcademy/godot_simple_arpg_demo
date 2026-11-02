extends Equip
class_name GameplayEquip

## 业务层装备类
## 继承自插件层的 Equip，添加业务相关的功能（如装备模型、挂点、技能等）
## 符合开闭原则：不修改插件层代码，通过继承扩展功能

## 装备模型场景（用于在角色身上显示装备）
@export var equip_model_scene: PackedScene = null
## 装备挂点名称（用于确定装备在哪个挂点上显示）
## 常见值：&"hand_right", &"hand_left", &"head", &"chest" 等
@export var attachment_point: StringName = &"hand_right"
## 装备携带的技能列表（装备时自动学会，卸下时自动遗忘）
@export var abilities: Array[GameplayAbilityDefinition] = []
