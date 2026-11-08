extends Control
class_name MainMenu


@onready var logo_rect: TextureRect = $Control/Logo
@onready var press_button_animation_tree: AnimationTree = $Control/PressButton/AnimationTree
@onready var press_button_playback: AnimationNodeStateMachinePlayback = press_button_animation_tree.get("parameters/playback")
@onready var select_sfx: AudioStreamPlayer2D = $SelectSfx
@onready var focus_sfx: AudioStreamPlayer2D = $FocusSfx
@onready var menu_animation_tree: AnimationTree = $Menu/AnimationTree
@onready var options_menu: OptionsMenu = $OptionsMenu
@onready var instructions_container: Container = $Menu/MarginContainer/Control/InstructionsContainer

@onready var quick_race_button: Button = $Menu/MarginContainer/Control/VBoxContainer/QuickRaceButton
@onready var options_button: Button = $Menu/MarginContainer/Control/VBoxContainer/OptionsButton
@onready var quit_button: Button = $Menu/MarginContainer/Control/VBoxContainer/QuitButton

var is_open: bool = false

func _ready() -> void:
	bind_quick_race_button()
	bind_options_button()
	bind_quit_button()
	GameManager.unlock_cursor()

func _process(_delta: float) -> void:
	logo_rect.visible = !is_open
	instructions_container.visible = !options_menu.is_open
	press_button_animation_tree.set("parameters/conditions/is_open", is_open)
	menu_animation_tree.set("parameters/conditions/is_open", is_open)
	menu_animation_tree.set("parameters/conditions/is_closed", !is_open)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and !options_menu.is_open:
		is_open = false
		press_button_playback.travel("Start", true)
	elif event.is_pressed() and !is_open:
		is_open = true
		select_sfx.play()

func bind_quick_race_button() -> void:
	quick_race_button.pressed.connect(handle_quick_race)
	quick_race_button.focus_entered.connect(handle_focus_sfx)
	quick_race_button.mouse_entered.connect(func (): handle_focus_button(quick_race_button))

func bind_options_button() -> void:
	options_button.pressed.connect(handle_open_options)
	options_button.focus_entered.connect(handle_focus_sfx)
	options_button.mouse_entered.connect(func (): handle_focus_button(options_button))

func bind_quit_button() -> void:
	quit_button.pressed.connect(handle_quit)
	quit_button.focus_entered.connect(handle_focus_sfx)
	quit_button.mouse_entered.connect(func (): handle_focus_button(quit_button))

func handle_focus_button(button: Button) -> void:
	button.grab_focus()

func handle_focus_sfx() -> void:
	focus_sfx.play()

func handle_quick_race() -> void:
	GameManager.lock_cursor()
	SceneManager.load_scene_file("res://Scenes/Tracks/Beltane.tscn")

func handle_open_options() -> void:
	select_sfx.play()
	options_menu.open_menu()

func handle_quit() -> void:
	get_tree().quit()
