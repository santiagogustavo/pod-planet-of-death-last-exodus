extends Node

var is_paused: bool = false
var time_elapsed: float = 0.0
var time_string: String = "00'00\"00"

var race: RaceManager = RaceManager.new()

func _ready() -> void:
	#TranslationServer.set_locale("en")
	update_mouse_mode()

func _process(delta: float) -> void:
	time_elapsed += delta
	time_string = format_lap_time(time_elapsed)

func toggle_pause() -> void:
	is_paused = !is_paused
	update_mouse_mode()

func update_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_paused else Input.MOUSE_MODE_CAPTURED

func format_lap_time(seconds: float) -> String:
	var mins := int(seconds / 60.0)
	var secs := int(fmod(seconds, 60.0))
	var msecs := int(fmod(seconds, 1.0) * 100)
	return "%02d'%02d\"%02d" % [mins, secs, msecs]
