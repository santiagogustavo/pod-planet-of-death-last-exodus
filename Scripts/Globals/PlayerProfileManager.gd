extends Node

signal loaded

var player_name: String = "Player 1"
var avatar_index: int = 0
var car_resource: String = "res://Resources/Cars/Saber.tres"

var file = ConfigFile.new()
var path = "user://player.cfg"

func _ready():
	var file_status = file.load(path)
	if file_status == OK:
		load_profile()
		loaded.emit()
	else:
		save_settings()

func save_settings():
	save_profile()
	save_settings_file()

func load_profile():
	player_name = file.get_value("profile", "player_name", player_name)
	avatar_index = file.get_value("profile", "avatar_index", player_name)
	car_resource = file.get_value("profile", "car_resource", car_resource)

func save_profile():
	file.set_value("profile", "player_name", player_name)
	file.set_value("profile", "avatar_index", avatar_index)
	file.set_value("profile", "car_resource", car_resource)

func save_settings_file():
	file.save(path)
