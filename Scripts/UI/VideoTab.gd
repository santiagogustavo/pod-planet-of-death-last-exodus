extends OptionsTab
class_name VideoTab

@onready var fullscreen_check: CheckButton = $VBoxContainer/FullscreenToggle/CheckButton
@onready var rendering_scale_slider: HSlider = $VBoxContainer/RenderingScaleSlider/HSlider

func _ready() -> void:
	bind_fullscreen_check()
	bind_resolution_scale_slider()

func _process(_delta: float) -> void:
	fullscreen_check.button_pressed = VideoSettingsManager.fullscreen
	rendering_scale_slider.value = VideoSettingsManager.rendering_scale

func bind_click_focus() -> void:
	tab_click_focused.connect(func (): 
		fullscreen_check.grab_focus()
	)

func bind_fullscreen_check() -> void:
	fullscreen_check.toggled.connect(func (value: bool):
		VideoSettingsManager.set_fullscreen(value)
	)

func bind_resolution_scale_slider() -> void:
	rendering_scale_slider.value_changed.connect(func (value: float):
		VideoSettingsManager.set_rendering_scale(value)
	)
