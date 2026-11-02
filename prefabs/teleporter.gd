extends Node3D
## Owns a configured destination and forwards child requests to the level.
signal transition_requested(initiator: Node, room: DungeonRoom, marker: Node3D)
@export_group("Teleport Settings")
@export var target_room: DungeonRoom
@export var target_marker: Node3D
@onready var _interaction: InteractionComponent = $InteractionComponent
func _ready() -> void:
	_interaction.teleport_requested.connect(_on_teleport_requested)
func _on_teleport_requested(initiator: Node) -> void:
	if is_instance_valid(target_room) and is_instance_valid(target_marker):
		transition_requested.emit(initiator, target_room, target_marker)
