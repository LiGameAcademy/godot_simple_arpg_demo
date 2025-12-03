extends Label3D

## 伤害飘字节点
## 用于显示伤害数值、治疗数值等浮动文本

func _ready() -> void:
	# 设置默认属性
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	no_depth_test = true

