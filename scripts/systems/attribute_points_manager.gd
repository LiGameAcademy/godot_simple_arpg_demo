extends RefCounted
class_name AttributePointsManager

## 属性点数管理器
## 管理玩家可用于分配属性点的资源，独立于属性系统

signal points_changed(new_points: int)

var _available_points: int = 0
var available_points: int:
	get:
		return _available_points
	set(value):
		var new_value = max(0, value)
		if _available_points != new_value:
			_available_points = new_value
			points_changed.emit(_available_points)

func _init(initial_points: int = 10) -> void:
	_available_points = initial_points

## 尝试消耗点数
## [param] amount: int 要消耗的点数
## [return] bool 是否成功消耗
func try_spend_points(amount: int) -> bool:
	if available_points < amount:
		return false
	available_points -= amount
	return true

## 增加点数
## [param] amount: int 要增加的点数
func add_points(amount: int) -> void:
	available_points += amount

## 是否有足够的点数
## [param] amount: int 需要的点数
## [return] bool 是否有足够的点数
func has_sufficient_points(amount: int) -> bool:
	return available_points >= amount
