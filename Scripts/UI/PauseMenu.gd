extends CanvasLayer

@export_category("Buttons")
@export var resume_button: Button
@export var restart_button: Button
@export var options_button: Button
@export var quit_button: Button

@onready var select_sfx: AudioStreamPlayer2D = $SelectSfx
@onready var focus_sfx: AudioStreamPlayer2D = $FocusSfx
@onready var options_menu: OptionsMenu = $OptionsMenu
@onready var instructions_container: HBoxContainer = $Control/MarginContainer/Control/InstructionsContainer
@onready var animation_tree: AnimationTree = $AnimationTree

func _ready() -> void:
	bind_resume_button()
	bind_restart_button()
	bind_options_button()
	bind_quit_button()
	bind_options_menu()

func _process(_delta: float) -> void:
	instructions_container.visible = !options_menu.visible
	if options_menu.is_open:
		return
	var can_pause = GameManager.race and GameManager.race.status == RaceManager.RaceStatus.Started
	if Input.is_action_just_pressed("pause") and can_pause:
		handle_toggle_pause()
		grab_first_button_focus()
	get_tree().paused = GameManager.is_paused
	animation_tree.set("parameters/conditions/is_open", GameManager.is_paused)
	animation_tree.set("parameters/conditions/is_closed", !GameManager.is_paused)

func grab_first_button_focus() -> void:
	resume_button.call_deferred("grab_focus")

func bind_resume_button() -> void:
	resume_button.pressed.connect(handle_toggle_pause)
	resume_button.focus_entered.connect(handle_focus_sfx)
	resume_button.mouse_entered.connect(func (): handle_focus_button(resume_button))

func bind_restart_button() -> void:
	restart_button.pressed.connect(handle_restart_race)
	restart_button.focus_entered.connect(handle_focus_sfx)
	restart_button.mouse_entered.connect(func (): handle_focus_button(restart_button))

func bind_options_button() -> void:
	options_button.pressed.connect(handle_open_options)
	options_button.focus_entered.connect(handle_focus_sfx)
	options_button.mouse_entered.connect(func (): handle_focus_button(options_button))

func bind_quit_button() -> void:
	quit_button.pressed.connect(handle_quit)
	quit_button.focus_entered.connect(handle_focus_sfx)
	quit_button.mouse_entered.connect(func (): handle_focus_button(quit_button))

func bind_options_menu() -> void:
	options_menu.closed.connect(grab_first_button_focus)

func handle_focus_button(button: Button) -> void:
	button.grab_focus()

func handle_focus_sfx() -> void:
	focus_sfx.play()

func handle_toggle_pause() -> void:
	select_sfx.play()
	GameManager.toggle_pause()

func handle_restart_race() -> void:
	GameManager.race.restart_race()
	GameManager.toggle_pause()

func handle_open_options() -> void:
	select_sfx.play()
	options_menu.open_menu()

func handle_quit() -> void:
	GameManager.is_paused = false
	GameManager.unlock_cursor()
	GameManager.clear_race()
	SceneManager.load_scene_file("res://Scenes/MainMenu.tscn")
