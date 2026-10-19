extends Node3D
class_name PlayerBotAI

enum Difficulty {
	EASY,
	MEDIUM,
	HARD
}

@export_category("References")
@export var car: Car
@export var player_input: PlayerInput

@export_category("AI")
@export var difficulty: Difficulty = Difficulty.MEDIUM
@export var max_steer_angle: float = 0.6
@export var target_reach_radius: float = 5.0
@export var steering_speed: float = 5.0
@export var speed_steering_reduction: float = 0.005

@export_category("Racing Line")
@export var racing_line_look_ahead: float = 8.0

@export_category("Reverse / Stuck")
@export var stuck_speed_threshold: float = 0.8
@export var time_to_trigger_reverse: float = 1.5
@export var reverse_duration: float = 1.4

@export_category("Airborne")
@export var airborne_steering_factor: float = 0.5

@export_category("Steering Smoothing")
@export var steering_smoothing: float = 7.0
@export var steering_deadzone: float = 0.02
@export var max_steering_change: float = 0.12

var current_gate: int = 1

var current_racing_line: RacingLine
var racing_offset: float = 0.0

var stuck_timer: float = 0.0
var reverse_timer: float = 0.0
var is_reversing: bool = false

var difficulty_speed_multiplier: float = 1.0
var difficulty_steering_assist: float = 0.0
var difficulty_reverse_delay: float = 1.0

func _ready() -> void:
	_setup_difficulty()
	if car == null:
		car = get_parent() as Car
	call_deferred("_initialize_ai")

func _initialize_ai() -> void:
	if (
		car == null
		or GameManager.race == null
		or GameManager.race.track == null
	):
		return

	# Gate 0 registra a volta.
	# O primeiro destino da corrida é sempre Gate 1.
	current_gate = 1

	select_racing_line()

	if current_racing_line != null:
		racing_offset = current_racing_line.find_initial_offset_for_gate(
			car.global_position,
			current_gate
		)

func _physics_process(delta: float) -> void:
	if (
		car == null
		or GameManager.race == null
		or GameManager.race.track == null
		or GameManager.race.status != RaceManager.RaceStatus.Started
	):
		return

	if GameManager.race.track == null:
		return

	# Não consideramos o carro travado enquanto estiver no ar.
	if not car.is_on_ground():
		_handle_airborne(delta)
		return

	if is_reversing:
		_handle_reverse(delta)
		return

	_handle_racing(delta)

# ============================================================
# RACING
# ============================================================

func _handle_racing(delta: float) -> void:
	if current_racing_line == null:
		select_racing_line()

	if current_racing_line == null:
		_apply_basic_fallback_controls()
		return

	# --------------------------------------------------------
	# Encontra o ponto mais próximo SOMENTE à frente dentro
	# do segmento atual.
	# --------------------------------------------------------

	var segment_end_offset = current_racing_line.get_segment_end_offset(
		current_gate
	)

	var closest_offset = current_racing_line.find_closest_offset_forward(
		car.global_position,
		racing_offset,
		segment_end_offset
	)

	if closest_offset >= 0.0:
		racing_offset = closest_offset

	# --------------------------------------------------------
	# IMPORTANTE:
	# A assinatura é:
	#
	# get_target_for_gate_segment(
	#     current_offset,
	#     current_gate,
	#     look_ahead
	# )
	# --------------------------------------------------------

	var target_result = current_racing_line.get_target_for_gate_segment(
		racing_offset,
		current_gate,
		racing_line_look_ahead
	)

	if target_result.is_empty():
		_apply_basic_fallback_controls()
		return

	var target_position: Vector3 = target_result.position

	_steer_towards(
		target_position,
		delta
	)
	_handle_acceleration()
	_check_if_stuck(delta)

# ============================================================
# RACING LINE SELECTION
# ============================================================

func select_racing_line() -> void:
	if GameManager.race == null:
		return

	var track: Track = GameManager.race.track

	if track == null:
		return

	var available_lines: Array[RacingLine] = (
		track.get_racing_lines_for_gate(current_gate)
	)

	# --------------------------------------------------------
	# Se não houver múltiplas linhas, usa a principal.
	# --------------------------------------------------------

	if available_lines.is_empty():
		current_racing_line = track.default_racing_line
		return

	var best_line: RacingLine = null
	var best_distance: float = INF

	for line in available_lines:

		if line == null:
			continue

		var result = line.get_closest_point_to_car(
			car.global_position,
			current_gate
		)

		if result.is_empty():
			continue

		var distance: float = result.distance

		if distance < best_distance:
			best_distance = distance
			best_line = line

	if best_line != null:
		current_racing_line = best_line

# ============================================================
# GATE
# ============================================================

func update_gate_target(gate_index: int) -> void:
	if (
		GameManager.race == null
		or GameManager.race.track == null
	):
		return

	current_gate = gate_index

	# Nova seleção somente ao entrar em um novo segmento.
	select_racing_line()

	if current_racing_line != null:
		racing_offset = current_racing_line.find_initial_offset_for_gate(
			car.global_position,
			current_gate
		)


func set_next_gate_target(gate_index: int) -> void:
	update_gate_target(gate_index)

# ============================================================
# STEERING
# ============================================================

func _steer_towards(target_position: Vector3, delta: float) -> void:
	var local_target := car.to_local(target_position)
	local_target.y = 0.0

	if local_target.length_squared() <= 0.001:
		return

	var angle_to_target = atan2(
		-local_target.x,
		-local_target.z
	)

	var desired_steering = clamp(
		angle_to_target / deg_to_rad(45.0),
		-1.0,
		1.0
	)

	if abs(desired_steering) < steering_deadzone:
		desired_steering = 0.0

	var smoothing_speed := steering_smoothing

	car.steering = move_toward(
		car.steering,
		desired_steering,
		smoothing_speed * delta
	)

# ============================================================
# ACCELERATION
# ============================================================

func _handle_acceleration() -> void:
	if is_reversing:
		return

	var speed = car.linear_velocity.length()

	var target_speed = (
		car.max_speed *
		difficulty_speed_multiplier
	)

	if speed < target_speed:
		car.engine_force = car.engine_power
	else:
		car.engine_force = 0.0

	car.brake = 0.0

# ============================================================
# STUCK / REVERSE
# ============================================================

func _check_if_stuck(delta: float) -> void:
	var speed = car.linear_velocity.length()

	if speed < stuck_speed_threshold:
		stuck_timer += delta
	else:
		stuck_timer = 0.0

	if stuck_timer >= (
		time_to_trigger_reverse *
		difficulty_reverse_delay
	):
		_start_reverse()

func _start_reverse() -> void:
	if is_reversing:
		return

	is_reversing = true
	reverse_timer = reverse_duration
	stuck_timer = 0.0

	car.engine_force = 0.0
	car.brake = 1.0

func _handle_reverse(delta: float) -> void:
	reverse_timer -= delta

	car.steering = move_toward(
		car.steering,
		0.0,
		steering_speed * delta
	)

	car.brake = 0.0

	car.engine_force = -abs(
		car.engine_power
	)

	if reverse_timer <= 0.0:

		is_reversing = false
		stuck_timer = 0.0

# ============================================================
# AIRBORNE
# ============================================================

func _handle_airborne(delta: float) -> void:
	stuck_timer = 0.0

	if current_racing_line == null:
		return

	var target_result = (
		current_racing_line.get_target_for_gate_segment(
			racing_offset,
			current_gate,
			racing_line_look_ahead
		)
	)

	if target_result.is_empty():
		return

	var target_position: Vector3 = (
		target_result.position
	)

	var local_target = car.to_local(
		target_position
	)

	local_target.y = 0.0

	var angle_to_target = atan2(
		-local_target.x,
		-local_target.z
	)

	var steer_amount = clamp(
		angle_to_target / max_steer_angle,
		-1.0,
		1.0
	)

	steer_amount *= airborne_steering_factor

	car.steering = move_toward(
		car.steering,
		steer_amount,
		steering_speed * delta
	)

	car.brake = 0.0

# ============================================================
# FALLBACK
# ============================================================

func _apply_basic_fallback_controls() -> void:
	car.steering = move_toward(
		car.steering,
		0.0,
		0.1
	)

	car.brake = 0.0

# ============================================================
# DIFFICULTY
# ============================================================

func _setup_difficulty() -> void:
	match difficulty:
		Difficulty.EASY:
			difficulty_speed_multiplier = 0.65
			difficulty_steering_assist = 0.25
			difficulty_reverse_delay = 2.5
		Difficulty.MEDIUM:
			difficulty_speed_multiplier = 0.85
			difficulty_steering_assist = 0.1
			difficulty_reverse_delay = 1.0
		Difficulty.HARD:
			difficulty_speed_multiplier = 1.0
			difficulty_steering_assist = 0.0
			difficulty_reverse_delay = 0.0
