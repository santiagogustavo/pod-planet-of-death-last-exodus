extends CanvasLayer
class_name OptionsMenu

signal closed

@export var is_open: bool = false

@onready var tab_container: TabContainer = $Control/MarginContainer/Control/TabContainer

func _process(_delta: float) -> void:
	visible = is_open
	if !is_open:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		close_menu()

func open_menu() -> void:
	is_open = true
	tab_container.get_tab_bar().call_deferred("grab_focus")

func close_menu() -> void:
	is_open = false
	closed.emit()
	SettingsManager.save_settings()
