extends CanvasLayer

@onready var save_button: Button = $Controls/Save
@onready var load_button: Button = $Controls/Load
@onready var feedback: Label = $Feedback

signal save_requested()
signal load_requested()

func _ready() -> void:
	save_button.pressed.connect(func() -> void: save_requested.emit())
	load_button.pressed.connect(func() -> void: load_requested.emit())

func set_available(can_save: bool, can_load: bool) -> void:
	save_button.disabled = not can_save
	load_button.disabled = not can_load

func show_message(message: String) -> void:
	feedback.text = message
