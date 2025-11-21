extends RigidBody3D

@onready var loot_area: Area3D = $LootArea

func _ready() -> void:
	loot_area.body_entered.connect(_on_body_entered)

func collect() -> void:
	print(">>> 捡到了 [红药水]！")
	print(">>> 系统提示：由于背包系统尚未开发，物品已消失在虚空中...")
	
	# 播放音效 (可选)
	# Audio.play("pop")
	
	queue_free()

func _on_body_entered(body) -> void:
	if body.is_in_group("Player"):
		collect()
