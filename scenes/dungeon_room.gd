extends Node3D
class_name DungeonRoom
## Owns room enemies and forwards their events to the level.
signal room_exit_requested(body: CharacterBody3D)
signal enemy_defeated(enemy_id: String)
signal loot_requested(scene: PackedScene, position: Vector3, impulse: Vector3)
@export var camera_marker: Marker3D
@export var enemies_container: Node3D
@export var exit_trigger: Area3D
func _ready() -> void:
	if is_instance_valid(exit_trigger):
		exit_trigger.passage_requested.connect(_on_exit_requested)
	if is_instance_valid(enemies_container):
		for enemy: Enemy in enemies_container.get_children():
			enemy.defeated.connect(func(id: String) -> void: enemy_defeated.emit(id))
			enemy.loot_requested.connect(_on_loot_requested)
func on_player_enter() -> void:
	if is_instance_valid(enemies_container):
		for enemy: Enemy in enemies_container.get_children():
			enemy.awaken()
func _on_exit_requested(body: CharacterBody3D) -> void:
	room_exit_requested.emit(body)
func _on_loot_requested(scene: PackedScene, position: Vector3, impulse: Vector3) -> void:
	loot_requested.emit(scene, position, impulse)
