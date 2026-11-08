extends OptionsTab
class_name SoundTab

@onready var master_slider: HSlider = $VBoxContainer/MasterVolume/HSlider
@onready var music_slider: HSlider = $VBoxContainer/MusicVolume/HSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SFXVolume/HSlider

func _ready() -> void:
	bind_master_slider()
	bind_music_slider()
	bind_sfx_slider()

func _process(_delta: float) -> void:
	master_slider.value = AudioSettingsManager.get_volume("Master")
	music_slider.value = AudioSettingsManager.get_volume("Music")
	sfx_slider.value = AudioSettingsManager.get_volume("SoundEffects")

func bind_click_focus() -> void:
	tab_click_focused.connect(func ():
		master_slider.grab_focus()
	)

func bind_master_slider() -> void:
	master_slider.value_changed.connect(func (value: float):
		AudioSettingsManager.set_volume("Master", value)
	)

func bind_music_slider() -> void:
	music_slider.value_changed.connect(func (value: float):
		AudioSettingsManager.set_volume("Music", value)
	)

func bind_sfx_slider() -> void:
	sfx_slider.value_changed.connect(func (value: float):
		AudioSettingsManager.set_volume("SoundEffects", value)
	)
