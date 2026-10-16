extends Node3D
class_name Player

@export var player_type: PlayerDetails.PlayerType = PlayerDetails.PlayerType.Player1
@export var player_details: PlayerDetails
@export var start_gate_index: int

@onready var chase_camera_prefab: PackedScene = load("res://Prefabs/Player/ChaseCamera.tscn")
@onready var hud_prefab: PackedScene = load("res://Prefabs/Player/PlayerHUD.tscn")
@onready var near_miss_detector: NearMissDetector = $NearMissDetector

var player_bot_ai: PlayerBotAI

var car_instance: Car
var hud_instance: PlayerHUD
var next_gate_indicator: Node3D = Node3D.new()
var current_lap: int = 0
var current_gate: int = 0

var checkpoints: Array[Checkpoint] = []
var laps: Array[float] = []

var wrong_way_time_buffer: float = 0.0

func _ready() -> void:
	GameManager.race.started.connect(func ():
		handle_gate_passed(GameManager.race.track.circuit_gates[0].get_rid(), current_gate)
	)
	if !player_details:
		return
	car_instance = load(player_details.car_data.scene_path).instantiate()
	car_instance.add_child(next_gate_indicator)
	car_instance.gate_passed.connect(handle_gate_passed)
	add_child(car_instance)
	var start_gate: StartGate = GameManager.race.track.start_gates[start_gate_index]
	car_instance.global_position = start_gate.global_position
	car_instance.global_rotation = start_gate.global_rotation
	if player_details.player_type == PlayerDetails.PlayerType.Bot:
		player_bot_ai = load("res://Prefabs/Player/PlayerBotAI.tscn").instantiate()
		car_instance.add_child(player_bot_ai)
	if player_details.player_type == PlayerDetails.PlayerType.Player1:
		var player_input_instance = PlayerInput.new()
		car_instance.add_child(player_input_instance)
		car_instance.player_input = player_input_instance
		var chase_camera_instance: ChaseCamera = chase_camera_prefab.instantiate()
		chase_camera_instance.car = car_instance
		car_instance.add_child(chase_camera_instance)
		hud_instance = hud_prefab.instantiate()
		hud_instance.car = car_instance
		hud_instance.player_resource_name = name
		hud_instance.player_details = player_details
		add_child(hud_instance)
	GameManager.race.add_player(self)

func _process(delta: float) -> void:
	# Atualiza o status de contramão usando produto escalar
	if hud_instance:
		if check_if_wrong_way():
			# Só liga o HUD se o jogador persistir na contramão por mais de 0.8 segundos
			wrong_way_time_buffer += delta
			if wrong_way_time_buffer >= 0.8:
				hud_instance.is_wrong_way = true
		else:
			wrong_way_time_buffer = 0.0
			hud_instance.is_wrong_way = false

	near_miss_detector.global_position = car_instance.global_position
	near_miss_detector.global_rotation = car_instance.global_rotation
	next_gate_indicator.look_at(GameManager.race.track.circuit_gates[current_gate].global_position)
	if hud_instance:
		hud_instance.current_lap = current_lap
		hud_instance.current_time_string = GameManager.format_lap_time(compute_lap_time(current_lap))
		hud_instance.best_time_string = GameManager.format_lap_time(get_best_lap_time())
		hud_instance.next_gate_rotation = next_gate_indicator.rotation

func check_if_wrong_way() -> bool:
	var gates = GameManager.race.track.circuit_gates
	if gates.size() < 2:
		return false
		
	# 1. Descobre o index do gate anterior
	var prev_gate_idx = current_gate - 1 if current_gate > 0 else gates.size() - 1
	
	var current_gate_pos = gates[current_gate].global_position
	var prev_gate_pos = gates[prev_gate_idx].global_position
	
	# 2. Vetor da direção correta da pista neste trecho
	var track_direction = (current_gate_pos - prev_gate_pos).normalized()
	
	# 3. Vetor para onde o carro está olhando/andando (frente do carro)
	var car_forward = -car_instance.global_transform.basis.z
	
	# 4. Produto Escalar
	var dot_product = car_forward.dot(track_direction)
	
	# -------------------------------------------------------------
	# AJUSTE DE LIMIAR (THRESHOLD)
	# -------------------------------------------------------------
	#  1.0 = Perfeitamente alinhado para frente.
	#  0.0 = Perfeitamente de lado (90 graus da pista).
	# -1.0 = Perfeitamente na contramão (180 graus).
	#
	# Usar um valor positivo (ex: 0.25) significa que se você ficar de lado 
	# ou levemente diagonal contra o fluxo (ângulo > ~75°), já acusa contramão.
	# -------------------------------------------------------------
	var wrong_way_threshold: float = 0.25
	
	return dot_product < wrong_way_threshold

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
	if player_bot_ai:
		player_bot_ai.update_gate_target(current_gate)

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

func compute_total_traveled_distance() -> float:
	var total_gates = GameManager.race.track.circuit_gates.size()
	
	var last_index = current_gate - 1
	if last_index < 0:
		last_index = total_gates - 1

	var base_distance = 0.0
	# Se o portão atual for o 0, a distância base na volta é zero (ele está calculando o segmento final)
	if current_gate > 0:
		base_distance = GameManager.race.track.accumulate_distances[last_index]

	var last_gate = GameManager.race.track.circuit_gates[last_index]
	var next_gate = GameManager.race.track.circuit_gates[current_gate]

	var segment_distance = last_gate.segment_distance
	var current_distance = car_instance.global_position.distance_to(next_gate.global_position)

	var segment_traveled_distance = segment_distance - current_distance
	segment_traveled_distance = max(0.0, segment_traveled_distance) 

	return base_distance + segment_traveled_distance
