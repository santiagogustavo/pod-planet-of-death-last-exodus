extends Node

@onready var window: Window = get_window()
@onready var base_size: Vector2i = window.content_scale_size 

var window_mode: DisplayServer.WindowMode = 1 as DisplayServer.WindowMode
var fullscreen: bool = false
var viewport_width: int = DisplayServer.window_get_size().x
var viewport_height: int = DisplayServer.window_get_size().y
var rendering_scale: float = 1.0

func _init() -> void:
	if OS.has_feature("editor"):
		ProjectSettings.set("display/window/stretch/mode", "viewport")

func center_window():
	var screen_center = Vector2(DisplayServer.screen_get_size()) / 2
	var window_size = Vector2(get_window().get_size_with_decorations())
	DisplayServer.window_set_position(Vector2i(screen_center - (window_size / 2)))

func set_window_size(size: Vector2i) -> void:
	viewport_width = size.x
	viewport_height = size.y
	DisplayServer.window_set_size(size)
	get_viewport().content_scale_size = Vector2i(1280, 720)
	center_window()

func refresh_window() -> void:
	#set_window_size()
	center_window()

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	refresh_window()

func set_rendering_scale(scale: float) -> void:
	rendering_scale = scale
	get_viewport().scaling_3d_scale = scale
