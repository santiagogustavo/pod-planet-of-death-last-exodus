extends MarginContainer
class_name InputTab

@onready var vibration_check: CheckButton = $VBoxContainer/VibrationToggle/CheckButton

func _ready() -> void:
	bind_vibration_check()

func _process(_delta: float) -> void:
	vibration_check.button_pressed = InputSettingsManager.vibration_enabled

func bind_vibration_check() -> void:
	vibration_check.toggled.connect(func (value: bool):
		InputSettingsManager.set_vibration_enabled(value)
	)
