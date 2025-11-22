# res://addons/laoli_dialogue_system/rich_text_effects/text_shake_effect.gd
extends RichTextEffect
class_name TextShakeEffect

var bbcode = "shake"

# 关键的自定义处理函数
func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# intensity_x 和 intensity_y 可以是在Inspector中导出的变量，用来控制抖动幅度
	var intensity_x = 2.0
	var intensity_y = 2.0
	
	# char_fx.offset 就是每个字符的偏移量
	# 我们给它加上一个随机值，就实现了抖动
	char_fx.offset.x += randf_range(-intensity_x, intensity_x)
	char_fx.offset.y += randf_range(-intensity_y, intensity_y)
	
	return true # 必须返回true来确认我们处理了效果
