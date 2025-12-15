extends Resource
class_name TalentData

## 天赋数据（业务层）
## 描述一个可学习的天赋：消耗点数、前置条件、应用的技能修改器等

@export var talent_id: StringName
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D

## 学习消耗的天赋点数
@export var cost: int = 1

## 前置天赋 ID 列表（必须全部已学会才能解锁）
@export var prerequisites: Array[StringName] = []

## 关联的技能行为修改器（GameplayAbilityModifier）
## 学会天赋时，这些修改器会被注册到角色的 GameplayModifierComponent 上
@export var ability_modifiers: Array[GameplayAbilityModifier] = []


