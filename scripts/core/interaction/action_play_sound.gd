extends GameAction
class_name ActionPlaySound

@export var audio_stream: AudioStream
@export_range(-80, 24) var volume_db: float = 0.0

func execute(_initiator: Node, target: Node) -> void:
	if audio_stream == null: return
	
	# 在目标位置生成一个临时的音频播放器
	# 这里可以使用我们未来封装的 AudioManager，现在先简单实现
	var sfx = AudioStreamPlayer3D.new()
	sfx.stream = audio_stream
	sfx.volume_db = volume_db
	
	# 将播放器挂载到场景中 (target 是交互物体，比如宝箱)
	target.add_child(sfx) 
	sfx.finished.connect(sfx.queue_free) # 播完自毁
	sfx.play()
