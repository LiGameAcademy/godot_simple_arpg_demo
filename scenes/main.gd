extends Node3D

# 运镜时间 (秒)
const TRANSITION_TIME = 1.5 
const DIALOGUE_PATH = "res://data/dialogues/dialogue.json"
const RANDOM_CHATTER_PATH = "res://data/dialogues/random_chatter.json"
const VARIABLE_TEST_PATH = "res://data/dialogues/variable_test.json"

@onready var player: CharacterBody3D = $RoomLobby/Player
@onready var inventory_ui: MarginContainer = $UILayer/HUD/inventory
@onready var camera: Camera3D = $Camera3D
@onready var save_test_ui: Control = $UILayer/SaveTestUI

@export var registered_quests: Array[Quest] = []

func _ready() -> void:
	_register_actions()
	_register_conditions()
	_register_quests()
	_init_dialogue()
	# 初始化：游戏开始时，把摄像机瞬间定格在第一个房间
	var start_room = $RoomLobby
	camera.global_position = start_room.camera_marker.global_position
	# 我们获取 Player 身上的组件，传给 UI
	var player_inventory : C_Inventory = player.get_inventory() # 确保你在player脚本中实现了这个方法
	inventory_ui.initialize(player_inventory)
	
func _unhandled_input(event) -> void:
	if event.is_action_pressed("toggle_inventory"):
		if inventory_ui.visible:
			inventory_ui.hide()
		else:
			inventory_ui.open()
	
	# 按 F5 打开/关闭存档测试面板
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		if save_test_ui.visible:
			save_test_ui.hide()
		else:
			save_test_ui.show()

func transition_to_room(target_room: DungeonRoom, target_position: Vector3) -> void:
   # 1. 冻结玩家 (禁止乱动)
	player.set_physics_process(false)
	
	# 2. 视觉魔术：先隐藏玩家 (仿佛进入了传送通道)
	# 如果你有传送特效，应该在这里播放
	player.visible = false
	
	# 3. 创建运镜 Tween
	var tween = create_tween()
	# 设置缓动曲线：Cubic In/Out 会让起步和刹车非常平滑，很有电影感
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# 4. 移动摄像机：从当前位置飞向目标房间的机位
	# 并行执行：同时改变位置
	tween.tween_property(camera, "global_position", target_room.camera_marker.global_position, TRANSITION_TIME)
	
	# 5. 等待运镜结束
	await tween.finished
	
	target_room.on_player_enter()
	
	# 6. 搬运玩家
	player.reparent(target_room)
	player.global_position = target_position
	player.visible = true # 显示玩家
	
	# 7. 恢复控制
	player.set_physics_process(true)

func _register_quests() -> void:
	for quest in registered_quests:
		GameState.register_quest(quest)

func _register_actions() -> void:
	DialogueManager.register_action("give_item", ActionAddItem.new())
	DialogueManager.register_action("remove_item", ActionRemoveItem.new())
	DialogueManager.register_action("give_reward", ActionGiveReward.new())
	DialogueManager.register_action("affinity_change", ActionChangeAffinity.new())

func _register_conditions() -> void:
	DialogueManager.register_condition("has_item", ConditionHasItem.new())

func _init_dialogue() -> void:
	DialogueManager.load_dialogue_file(DIALOGUE_PATH)
	DialogueManager.load_dialogue_file(RANDOM_CHATTER_PATH)
	DialogueManager.load_dialogue_file(VARIABLE_TEST_PATH)
