extends CanvasLayer

@onready var bars: Control = $Bars
@onready var title_label: Label = $Title

func _ready() -> void:
	bars.hide()
	title_label.hide()

func set_active(active: bool) -> void:
	bars.visible = active
	title_label.hide()

func show_title(title: String = "异化回响", subtitle: String = "封印留下的另一个你") -> void:
	title_label.text = title + "\n" + subtitle
	title_label.show()
