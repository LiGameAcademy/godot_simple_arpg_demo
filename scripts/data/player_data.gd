extends Resource
class_name PlayerData

@export var attribute_sets: Array[GameplayAttributeSet] ## 属性集
@export var vitals: Array[GameplayVital]
@export var basic_attack_ability : ActiveAbility = load("res://data/abilities/basic_attack.tres")
