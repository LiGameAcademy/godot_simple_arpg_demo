extends Area3D

signal passage_requested(body: CharacterBody3D)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		passage_requested.emit(body as CharacterBody3D)
