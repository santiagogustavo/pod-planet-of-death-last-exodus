extends Node

@export var engine_version: String = Engine.get_version_info().string

var file = ConfigFile.new()
var path = "user://settings.cfg"

func _ready():
	var file_status = file.load(path)
	if file_status == OK:
		load_audio_settings()
		load_input_settings()
	else:
		save_settings()

func save_settings():
	save_audio_settings()
	save_input_settings()
	save_settings_file()

func load_audio_settings():
	AudioSettingsManager.set_volume("Master", file.get_value("audio", "master_volume", AudioSettingsManager.volumes["Master"]))
	AudioSettingsManager.set_volume("Music", file.get_value("audio", "music_volume", AudioSettingsManager.volumes["Music"]))
	AudioSettingsManager.set_volume("SoundEffects", file.get_value("audio", "sfx_volume", AudioSettingsManager.volumes["SoundEffects"]))

func load_input_settings():
	InputSettingsManager.set_vibration_enabled(file.get_value("input", "vibration_enabled", InputSettingsManager.vibration_enabled))

func save_audio_settings():
	file.set_value("audio", "master_volume", AudioSettingsManager.volumes["Master"])
	file.set_value("audio", "music_volume", AudioSettingsManager.volumes["Music"])
	file.set_value("audio", "sfx_volume", AudioSettingsManager.volumes["SoundEffects"])

func save_input_settings():
	file.set_value("input", "vibration_enabled", InputSettingsManager.vibration_enabled)

func save_settings_file():
	file.save(path)
