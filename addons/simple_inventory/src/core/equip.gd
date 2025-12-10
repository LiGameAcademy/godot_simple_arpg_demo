extends Item
class_name Equip

## 装备类型
enum EQUIP_TYPE {
	## 胸部
	CHEST,
	## 脚
	FEET,
	## 头
	HEAD,
	## 腿
	LEGS,
	## 项链
	NECKLACE,
	## 指环
	RING,
	## 武器
	WEAPON,
}

@export var equip_type : EQUIP_TYPE = EQUIP_TYPE.CHEST
## 装备模型场景（用于在角色身上显示装备）
@export var equip_model_scene: PackedScene = null
## 装备挂点名称（用于确定装备在哪个挂点上显示）
## 常见值：&"hand_right", &"hand_left", &"head", &"chest" 等
@export var attachment_point: StringName = &"hand_right"
