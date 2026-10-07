extends CanvasLayer
class_name PlayerHUD

@export var visor_bulge: float = -0.15
@export var sway_factor: float = 7.5
@export var sway_speed: float = 10.0
@export var sway_shake_intensity: float = 1.0
@export var car: Car
@export var player_details: PlayerDetails
@export var best_time_string: String = "0'00\"00"
@export var current_time_string: String = "0'00\"00"
@export var current_position: int = 1
@export var current_lap: int = 0

@onready var subviewport_container: SubViewportContainer = $SwayContainer
@onready var player_avatar: PlayerAvatar = $SwayContainer/SubViewport/MarginContainer/Control/PlayerAvatar
@onready var speed_label: Label = $SwayContainer/SubViewport/MarginContainer/Control/Speedometer/SpeedLabel
@onready var speed_gauge: TextureRect = $SwayContainer/SubViewport/MarginContainer/Control/Speedometer/SpeedGauge
@onready var race_time_label: Label = $SwayContainer/SubViewport/MarginContainer/Control/RaceTime/Label
@onready var current_position_label: Label =  $SwayContainer/SubViewport/MarginContainer/Control/RaceStats/PositionLabel/CurrentPositionlabel
@onready var total_positions_label: Label =  $SwayContainer/SubViewport/MarginContainer/Control/RaceStats/PositionLabel/TotalPositionsLabel
@onready var current_lap_label: Label =  $SwayContainer/SubViewport/MarginContainer/Control/RaceStats/LapLabel/CurrentLapLabel
@onready var total_laps_label: Label =  $SwayContainer/SubViewport/MarginContainer/Control/RaceStats/LapLabel/TotalLapsLabel
@onready var race_current_time: Label = $SwayContainer/SubViewport/MarginContainer/Control/RaceStats/CurrentLap/Value
@onready var race_best_time: Label = $SwayContainer/SubViewport/MarginContainer/Control/RaceStats/BestLap/Value

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		GameManager.toggle_pause()
	get_tree().paused = GameManager.is_paused
	update_visor()
	update_sway(delta)
	update_player_details()
	update_speedometer()
	update_race_time()
	update_race_stats()

func update_visor() -> void:
	subviewport_container.material.set("shader_parameter/bulge", visor_bulge)

func update_sway(delta: float) -> void:
	var clamped_input_look = car.steering
	var current_speed = car.speed_kmh
	var intensity = clamp(current_speed / 200.0, 0.0, 1.0)
	var sway_look = Vector2(
		(randf_range(-sway_shake_intensity, sway_shake_intensity) * intensity) + clamped_input_look,
		(randf_range(-sway_shake_intensity, sway_shake_intensity) * intensity)
	)
	subviewport_container.position = lerp(
		subviewport_container.position,
		sway_look * sway_factor,
		delta * sway_speed,
	)

func update_player_details() -> void:
	if player_details:
		player_avatar.character_image = player_details.player_avatar

func update_speedometer() -> void:
	speed_label.text = str(clamp(roundi(car.speed_kmh), 0, 999)).pad_zeros(3)
	speed_gauge.material.set("shader_parameter/current_val", car.speed_kmh)
	speed_gauge.material.set("shader_parameter/max_val", car.max_speed)

func update_race_time() -> void:
	race_time_label.text = GameManager.time_string

func update_race_stats() -> void:
	current_position_label.text = str(current_position)
	total_positions_label.text = "/" + str(GameManager.race.players.size())
	current_lap_label.text = str(current_lap)
	total_laps_label.text = "/" + str(GameManager.race.laps)
	race_current_time.text = current_time_string
	race_best_time.text = best_time_string
