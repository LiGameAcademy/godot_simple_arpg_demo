extends CanvasLayer

@onready var bars: Control = $Bars
@onready var title_label: Label = $Title
@onready var hint: Label = $Hint
@onready var progress: ProgressBar = $Progress
@onready var combat_label: Label = $CombatStatus
@onready var boss_health: ProgressBar = $BossHealth

@export var hold_seconds: float = 0.6

var _hold_time: float = 0.0
var _active: bool = false
var _skippable: bool = true
var _held: bool = false

signal skip_requested()

func _ready() -> void:
	hold_seconds = maxf(hold_seconds, 0.1)
	var binding: String = "跳过键"
	for event: InputEvent in InputMap.action_get_events(&"skip_cutscene"):
		if event is InputEventKey:
			var key: InputEventKey = event as InputEventKey
			binding = OS.get_keycode_string(key.physical_keycode if key.physical_keycode != 0 else key.keycode)
			break
	hint.text = "按住 %s 跳过 - Enter 继续对白" % binding
	bars.hide()
	title_label.hide()
	hint.hide()
	progress.hide()

func _process(delta: float) -> void:
	if not _active or not _held:
		return
	_hold_time += delta
	progress.value = minf(_hold_time / hold_seconds, 1.0) * progress.max_value
	if _hold_time >= hold_seconds:
		_held = false
		skip_requested.emit()

func _input(event: InputEvent) -> void:
	if _active and _skippable and event.is_action("skip_cutscene"):
		if event.is_action_pressed("skip_cutscene") and not event.is_echo():
			_held = true
		elif event.is_action_released("skip_cutscene"):
			_held = false
			_hold_time = 0.0
			progress.value = 0.0
		get_viewport().set_input_as_handled()

func set_active(active: bool) -> void:
	_active = active
	_held = false
	_hold_time = 0.0
	progress.value = 0.0
	bars.visible = active
	hint.visible = active
	progress.visible = active
	title_label.hide()
	if active:
		combat_label.hide()
		boss_health.hide()

func set_skippable(enabled: bool) -> void:
	_skippable = enabled
	hint.visible = _active and enabled
	progress.visible = _active and enabled

func show_title(title: String = "异化回响", subtitle: String = "封印留下的另一个你") -> void:
	title_label.text = title + "\n" + subtitle
	title_label.show()

func show_combat_status(text: String) -> void:
	combat_label.text = text
	combat_label.visible = not text.is_empty()
	
func show_boss_health(current: int, maximun: int) -> void:
	boss_health.max_value = maximun
	boss_health.value = current
	boss_health.show()
