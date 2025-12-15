extends Resource
class_name TalentTreeData

## 天赋树数据（业务层）
## 用于驱动天赋书 UI：包含一组天赋及其在界面上的布局信息

@export var talents: Array[TalentData] = []

## 天赋在 UI 中的布局位置（可选）
## key: talent_id, value: 网格坐标（行、列），用于自动生成天赋树
@export var grid_positions: Dictionary[StringName, Vector2i] = {}

## 根据 ID 获取天赋
func get_talent(talent_id: StringName) -> TalentData:
	for t in talents:
		if is_instance_valid(t) and t.talent_id == talent_id:
			return t
	return null
