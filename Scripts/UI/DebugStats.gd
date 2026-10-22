extends CanvasLayer

@onready var fps_value: Label = $MarginContainer/Control/Panel/HBoxContainer/FPSValue

func _process(_delta: float) -> void:
	visible = GameManager.is_debug_mode
	fps_value.text = str(Engine.get_frames_per_second())
