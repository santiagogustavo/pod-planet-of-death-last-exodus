extends Node3D
class_name Player

enum PlayerType {
	Player1,
	Bot
}

@export var car_data: CarData
@export var player_details: PlayerDetails

@onready var chase_camera_prefab: PackedScene = load("res://Prefabs/Player/ChaseCamera.tscn")
@onready var hud_prefab: PackedScene = load("res://Prefabs/Player/PlayerHUD.tscn")
@onready var near_miss_detector: NearMissDetector = $NearMissDetector

var car_instance: Car
var hud_instance: PlayerHUD
var current_lap: int = 0
var current_gate: int = 0

var checkpoints: Array[Checkpoint] = []
var laps: Array[float] = []

func _ready() -> void:
	GameManager.race.started.connect(func ():
		handle_gate_passed(GameManager.race.track.circuit_gates[0].get_rid(), current_gate)
	)
	if !car_data:
		return
	car_instance = load(car_data.scene_path).instantiate()
	var player_input_instance = PlayerInput.new()
	car_instance.add_child(player_input_instance)
	car_instance.player_input = player_input_instance
	car_instance.gate_passed.connect(handle_gate_passed)
	add_child(car_instance)
	var chase_camera_instance: ChaseCamera = chase_camera_prefab.instantiate()
	chase_camera_instance.car = car_instance
	car_instance.add_child(chase_camera_instance)
	hud_instance = hud_prefab.instantiate()
	hud_instance.car = car_instance
	hud_instance.player_details = player_details
	add_child(hud_instance)
	GameManager.race.players.append(self)

func _process(_delta: float) -> void:
	near_miss_detector.global_position = car_instance.global_position
	near_miss_detector.global_rotation = car_instance.global_rotation
	hud_instance.current_lap = current_lap
	hud_instance.current_time_string = GameManager.format_lap_time(compute_lap_time(current_lap))
	hud_instance.best_time_string = GameManager.format_lap_time(get_best_lap_time())

func handle_gate_passed(gate_rid: RID, gate_index: int) -> void:
	if gate_index != current_gate:
		return
	if current_gate == 0:
		if current_lap != 0:
			laps.append(compute_lap_time(current_lap))
		current_lap += 1
	if checkpoints.filter(func (checkpoint: Checkpoint):
		return checkpoint.gate_rid == gate_rid and checkpoint.lap == current_lap
	).size():
		return
	var current_checkpoint: Checkpoint = Checkpoint.new()
	current_checkpoint.gate_rid = gate_rid
	current_checkpoint.lap = current_lap
	current_checkpoint.time_elapsed = GameManager.time_elapsed
	checkpoints.append(current_checkpoint)
	if current_gate < GameManager.race.track.circuit_gates.size() - 1:
		current_gate = current_gate + 1
	else:
		current_gate = 0

func compute_lap_time(lap: int) -> float:
	if lap == 0:
		return 0.0
	var lap_checks = checkpoints.filter(func (checkpoint: Checkpoint):
		return checkpoint.lap == lap
	)
	var elapsed_time = GameManager.time_elapsed - lap_checks[0].time_elapsed
	return elapsed_time

func get_best_lap_time() -> float:
	return laps.min() if laps.size() else 0.0
