extends ShaderMaterial
class_name CircularProgressMaterial

## 环形进度条材质
## 封装了 shader 的参数设置

## 进度值（0.0 = 完成，1.0 = 刚开始）
var progress: float = 0.0:
	set(value):
		progress = clamp(value, 0.0, 1.0)
		if shader:
			set_shader_parameter("progress", progress)

## 圆环厚度（0.0-0.5）
var thickness: float = 0.15:
	set(value):
		thickness = clamp(value, 0.0, 0.5)
		if shader:
			set_shader_parameter("thickness", thickness)

## 冷却中的颜色
var progress_color: Color = Color(0.2, 0.2, 0.2, 0.8):
	set(value):
		progress_color = value
		if shader:
			set_shader_parameter("progress_color", progress_color)

## 冷却完成的颜色（通常透明）
var ready_color: Color = Color(1.0, 1.0, 1.0, 0.0):
	set(value):
		ready_color = value
		if shader:
			set_shader_parameter("ready_color", ready_color)

func _init() -> void:
	shader = load("res://ui/shaders/circular_progress.gdshader")
	# 设置默认值
	progress = 0.0
	thickness = 0.15
	progress_color = Color(0.2, 0.2, 0.2, 0.8)
	ready_color = Color(1.0, 1.0, 1.0, 0.0)
