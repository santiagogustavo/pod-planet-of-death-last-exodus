extends Node

var is_paused: bool = false
var time_elapsed: float = 0.0
var time_string: String = "00'00\"00"

var race: RaceManager

var is_debug_mode: bool = false
var debug_cull_visible: bool = true

func _ready() -> void:
	#TranslationServer.set_locale("en")
	update_mouse_mode()

func _process(delta: float) -> void:
	update_race_time(delta)
	if Input.is_action_just_pressed("ui_toggle_debug"):
		is_debug_mode = !is_debug_mode
	if Input.is_action_just_pressed("ui_debug_cull"):
		debug_cull_visible = !debug_cull_visible

func toggle_pause() -> void:
	is_paused = !is_paused
	update_mouse_mode()

func update_mouse_mode() -> void:
	if is_paused:
		unlock_cursor()
	else:
		lock_cursor()

func lock_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func unlock_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func update_race_time(delta: float) -> void:
	if !race or !race.status == RaceManager.RaceStatus.Started:
		time_elapsed = 0.0
		return
	time_elapsed += delta
	time_string = format_lap_time(time_elapsed)

func clear_race() -> void:
	time_elapsed = 0.0
	race.clear_race()
	race = null

func format_lap_time(seconds: float) -> String:
	var mins := int(seconds / 60.0)
	var secs := int(fmod(seconds, 60.0))
	var msecs := int(fmod(seconds, 1.0) * 100)
	return "%02d'%02d\"%02d" % [mins, secs, msecs]
