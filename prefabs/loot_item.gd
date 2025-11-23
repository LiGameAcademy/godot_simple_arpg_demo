extends RigidBody3D

@onready var loot_area: Area3D = $LootArea

@export var item_def: Item 

func _ready() -> void:
	loot_area.body_entered.connect(_on_body_entered)

func collect(target_inventory: C_Inventory) -> void:
	if is_instance_valid(item_def):
		print("物品进入背包：", item_def.name)
		GameState.emit_game_event("item_added", {"item_id": item_def.id, "amount": item_def.quantity})
		# 调用组件的方法添加物品
		target_inventory.add_item(item_def.duplicate())
		
		# 播放音效...
		queue_free()
	else:
		printerr("错误：掉落物未配置 Item 数据")

func _on_body_entered(body) -> void:
	# 我们不管撞到的是 Player 还是 NPC，只要它身上有 InventoryComponent，就能捡！
	if not body.has_method("get_inventory"):
		return
	var inventory = body.get_inventory()
	
	if is_instance_valid(inventory):
		collect(inventory)
