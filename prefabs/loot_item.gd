extends RigidBody3D

@onready var loot_area: Area3D = $LootArea
@export var item_def: GameplayItem


func _ready() -> void:
	loot_area.body_entered.connect(_on_body_entered)


func collect(target_inventory: InventoryComponent) -> void:
	if not is_instance_valid(item_def) or not is_instance_valid(target_inventory):
		return
	var item: GameplayItemInstance = GameplayEquipInstance.new(item_def as GameplayEquip) if item_def is GameplayEquip else GameplayItemInstance.new(item_def)
	if target_inventory.add_item(item):
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		collect((body as Player).get_inventory())
