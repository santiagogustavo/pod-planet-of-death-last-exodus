extends PanelContainer
class_name ScoreboardItem

@export var player_position: int = 1
@export var player_resource_name: String
@export var player_details: PlayerDetails
@export var is_current_player: bool = false
@export var is_player_ahead: bool = false
@export var par_time: float = 0.0

@onready var position_label: Label = $MarginContainer/HBoxContainer/Position
@onready var player_avatar: PlayerAvatar = $MarginContainer/HBoxContainer/PlayerAvatar
@onready var name_or_time_label: Label = $MarginContainer/HBoxContainer/NameOrTime

@onready var initial_panel_bg_color: Color = (get("theme_override_styles/panel") as StyleBoxFlat).bg_color

var show_name: bool = true
const PAR_TIME_TIMEOUT: float = 5.0

func _ready() -> void:
	if is_current_player:
		return
	create_name_or_time_timeout()

func _process(_delta: float) -> void:
	position_label.text = str(player_position)
	player_avatar.character_image = player_details.player_avatar
	name_or_time_label.text = player_details.player_name if show_name else format_par_time()
	if is_current_player:
		var active_color: Color = Color.hex(0xefa002aa)
		(get("theme_override_styles/panel") as StyleBoxFlat).bg_color = active_color
	else:
		(get("theme_override_styles/panel") as StyleBoxFlat).bg_color = initial_panel_bg_color

func create_name_or_time_timeout() -> void:
	get_tree().create_timer(PAR_TIME_TIMEOUT).timeout.connect(show_name_or_time_timeout)

func show_name_or_time_timeout() -> void:
	show_name = !show_name
	create_name_or_time_timeout()

func format_par_time() -> String:
	var prefix: String = "-" if is_player_ahead else "+"
	return prefix + GameManager.format_lap_time(absf(par_time))
