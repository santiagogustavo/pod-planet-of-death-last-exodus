extends CanvasLayer
class_name PlayerHUD

@export var visor_bulge: float = -0.15
@export var sway_factor: float = 7.5
@export var sway_speed: float = 10.0
@export var sway_shake_intensity: float = 1.0
@export var car: Car
@export var player_resource_name: String
@export var player_details: PlayerDetails
@export var best_time_string: String = "0'00\"00"
@export var current_time_string: String = "0'00\"00"
@export var current_position: int = 1
@export var current_lap: int = 0
@export var next_gate_rotation: Vector3 = Vector3.ZERO
@export var is_wrong_way: bool = false

@onready var scoreboard_item_prefab: PackedScene = load("res://Prefabs/UI/ScoreboardItem.tscn")
@onready var race_start_countdown_prefab: PackedScene = load("res://Prefabs/UI/RaceStartCountdown.tscn")

@onready var subviewport_container: SubViewportContainer = $SwayContainer
@onready var sway_viewport_container: SubViewport = $SwayContainer/SubViewport
@onready var hud_container: MarginContainer = $SwayContainer/SubViewport/MarginContainer

@onready var scoreboard_container: VBoxContainer = $SwayContainer/SubViewport/MarginContainer/Control/Scoreboard
@onready var scoreboard_item_debug_1: ScoreboardItem = $SwayContainer/SubViewport/MarginContainer/Control/Scoreboard/ScoreboardItemDebug
@onready var scoreboard_item_debug_2: ScoreboardItem = $SwayContainer/SubViewport/MarginContainer/Control/Scoreboard/ScoreboardItemDebug2
@onready var player_avatar: PlayerAvatar = $SwayContainer/SubViewport/MarginContainer/Control/PlayerAvatar
@onready var next_gate_indicator: TextureRect = $SwayContainer/SubViewport/MarginContainer/Control/NextGateIndicator
@onready var speed_label: Label = $SwayContainer/SubViewport/MarginContainer/Control/Speedometer/SpeedLabel
@onready var speed_gauge: TextureRect = $SwayContainer/SubViewport/MarginContainer/Control/Speedometer/SpeedGauge
@onready var race_time_label: Label = $SwayContainer/SubViewport/MarginContainer/Control/RaceTime/Label
@onready var current_position_label: Label =  $SwayContainer/SubViewport/MarginContainer/Control/RaceStats/PositionLabel/CurrentPositionlabel
@onready var total_positions_label: Label =  $SwayContainer/SubViewport/MarginContainer/Control/RaceStats/PositionLabel/TotalPositionsLabel
@onready var current_lap_label: Label =  $SwayContainer/SubViewport/MarginContainer/Control/RaceStats/LapLabel/CurrentLapLabel
@onready var total_laps_label: Label =  $SwayContainer/SubViewport/MarginContainer/Control/RaceStats/LapLabel/TotalLapsLabel
@onready var race_current_time: Label = $SwayContainer/SubViewport/MarginContainer/Control/RaceStats/CurrentLap/Value
@onready var race_best_time: Label = $SwayContainer/SubViewport/MarginContainer/Control/RaceStats/BestLap/Value
@onready var wrong_way_animation_tree: AnimationTree = $SwayContainer/SubViewport/MarginContainer/Control/WrongWayLabel/AnimationTree

var scoreboard_items: Array[ScoreboardItem] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	scoreboard_item_debug_1.queue_free()
	scoreboard_item_debug_2.queue_free()
	GameManager.race.player_added.connect(instantiate_scoreboard_item)
	if GameManager.race.status == RaceManager.RaceStatus.Countdown:
		instantiate_race_countdown()
	else:
		GameManager.race.countdown.connect(instantiate_race_countdown)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		GameManager.toggle_pause()
	if GameManager.race.status != RaceManager.RaceStatus.Started:
		hud_container.visible = false
	else:
		hud_container.visible = true
	get_tree().paused = GameManager.is_paused
	update_visor()
	update_sway(delta)
	update_scoreboard()
	update_player_details()
	update_next_gate_indicator()
	update_speedometer()
	update_race_time()
	update_race_stats()
	update_wrong_way_animation_tree()

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

func instantiate_race_countdown() -> void:
	var race_start_countdown_instance = race_start_countdown_prefab.instantiate()
	sway_viewport_container.add_child(race_start_countdown_instance)

func instantiate_scoreboard_item(added_player: Player) -> void:
	var added_player_details: PlayerDetails = added_player.player_details
	var scoreboard_item: ScoreboardItem = scoreboard_item_prefab.instantiate()
	scoreboard_item.player_resource_name = added_player.name
	scoreboard_item.player_position = scoreboard_items.size() + 1
	scoreboard_item.player_details = added_player_details
	scoreboard_item.is_current_player = (
		added_player.name == player_resource_name
	)
	scoreboard_items.append(scoreboard_item)
	scoreboard_container.add_child(scoreboard_item)

func update_scoreboard() -> void:
	var player_positions = GameManager.race.sort_players_by_distance_to_next_gate()
	for item in scoreboard_items:
		var position = player_positions.find(item.player_resource_name) + 1
		item.player_position = position
		scoreboard_container.move_child(item, position - 1)
		if item.player_resource_name == player_resource_name:
			current_position = position
			item.par_time = 0.0
		else:
			item.par_time = GameManager.race.get_par_time_between_players(current_position, position)
		item.par_time *= -1 if current_position < position else 1

func update_player_details() -> void:
	if player_details:
		player_avatar.character_image = player_details.player_avatar

func update_next_gate_indicator() -> void:
	next_gate_indicator.rotation = -next_gate_rotation.y

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

func update_wrong_way_animation_tree() -> void:
	wrong_way_animation_tree.set("parameters/conditions/is_wrong_way", is_wrong_way)
	wrong_way_animation_tree.set("parameters/conditions/is_not_wrong_way", !is_wrong_way)
