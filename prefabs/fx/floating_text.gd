extends Label3D

## 伤害飘字节点
## 用于显示伤害数值、治疗数值等浮动文本
## 通过 setup_from_context 方法从 Cue 传递的 context 中获取数据并设置自己

## 飘字文本颜色
@export var text_color: Color = Color.WHITE
## 飘字字体大小
@export var text_font_size: int = 48
## 飘字向上移动的距离
@export var text_float_distance: float = 2.0
## 飘字持续时间（秒）
@export var text_duration: float = 1.0
## 飘字格式字符串（支持 {value} 占位符）
@export var text_format: String = "-{value}"

func _ready() -> void:
	# 设置默认属性
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	no_depth_test = true
	
	# 设置字体大小（Label3D 直接使用 font_size 属性）
	font_size = text_font_size

## 从上下文设置飘字内容（由 CueAttachedParticle 调用）
## [param] context: Dictionary 上下文信息，可能包含：
##   - "final_damage": float 最终伤害值
##   - "value": float 数值（通用）
##   - "text": String 直接文本
func setup_from_context(context: Dictionary) -> void:
	# 设置文本内容
	var text_content: String = ""
	if context.has("final_damage"):
		var value = context["final_damage"]
		text_content = text_format.format({"value": int(value)})
	elif context.has("value"):
		var value = context["value"]
		text_content = text_format.format({"value": int(value)})
	elif context.has("text"):
		text_content = context["text"]
	else:
		text_content = text_format.replace("{value}", "")
	
	text = text_content
	modulate = text_color
	
	# 播放飘字动画
	_play_animation()

## 播放飘字动画
func _play_animation() -> void:
	# 使用全局单例 GameplayCueManager 创建 Tween
	var manager = GameplayCueManager
	if not is_instance_valid(manager):
		push_warning("FloatingText: Cannot create tween, GameplayCueManager not found")
		queue_free()
		return
	
	var tween = manager.create_tween()
	tween.set_parallel(true)
	
	# 向上移动
	var target_pos = global_position + Vector3(0, text_float_distance, 0)
	tween.tween_property(self, "global_position", target_pos, text_duration)
	
	# 淡出
	tween.tween_property(self, "modulate:a", 0.0, text_duration)
	
	# 添加轻微的随机偏移，避免重叠
	var random_offset = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	tween.tween_property(self, "global_position", target_pos + random_offset, text_duration)
	
	# 动画完成后销毁
	tween.tween_callback(queue_free).set_delay(text_duration)
