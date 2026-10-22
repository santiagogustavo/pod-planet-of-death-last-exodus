extends Node3D
class_name PlayerBotAI


enum Difficulty {
	EASY,
	MEDIUM,
	HARD
}


@export_category("AI")
@export var difficulty: Difficulty = Difficulty.MEDIUM


@export_category("References")
@export var player_input: PlayerInput
@onready var car: Car = get_parent() as Car


@export_category("Steering")
@export var max_steer_angle: float = 0.6
@export var target_reach_radius: float = 5.0
@export var steering_speed: float = 5.0
@export var speed_steering_reduction: float = 0.005


@export_category("Racing Line")
@export var racing_line_look_ahead: float = 20.0


@export_category("Racing Line Selection")
@export_range(1, 8, 1)
var racing_line_candidate_count: int = 3

@export var racing_line_switch_margin: float = 3.0
@export var racing_line_direction_weight: float = 8.0


@export_category("Steering Smoothing")
@export var steering_smoothing: float = 5.0
@export var steering_deadzone: float = 0.03
@export var max_steering_change: float = 4.0


@export_category("Airborne")
@export var airborne_steering_factor: float = 0.5


@export_category("Stuck / Reverse")
@export var stuck_speed_threshold: float = 2.0
@export var stuck_time_threshold: float = 1.5
@export var reverse_duration: float = 1.0


var current_gate: int = 1

var current_racing_line: RacingLine
var racing_offset: float = 0.0

var racing_line_locked: bool = false

var stuck_timer: float = 0.0
var reverse_timer: float = 0.0
var is_reversing: bool = false


var difficulty_speed_multiplier: float = 1.0
var difficulty_steering_assist: float = 0.0
var difficulty_reverse_delay: float = 0.0


# --------------------------------------------------------------------
# INITIALIZATION
# --------------------------------------------------------------------

func _ready() -> void:
	_setup_difficulty()

	call_deferred("_initialize_ai")


func _initialize_ai() -> void:
	current_gate = 1

	select_racing_line(true)

	if current_racing_line != null:
		racing_offset = (
			current_racing_line.find_initial_offset_for_gate(
				car.global_position,
				current_gate
			)
		)


# --------------------------------------------------------------------
# DIFFICULTY
# --------------------------------------------------------------------

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


# --------------------------------------------------------------------
# PHYSICS
# --------------------------------------------------------------------

func _physics_process(delta: float) -> void:

	if GameManager.race == null:
		return

	if not GameManager.race.status == RaceManager.RaceStatus.Started:
		return

	if car == null:
		return


	# --------------------------------------------------------------
	# AIRBORNE
	# --------------------------------------------------------------

	if not car.is_on_ground():
		_handle_airborne(delta)
		return


	# --------------------------------------------------------------
	# REVERSE
	# --------------------------------------------------------------

	if is_reversing:
		_handle_reverse(delta)
		return


	# --------------------------------------------------------------
	# NORMAL RACING
	# --------------------------------------------------------------

	_handle_racing(delta)


# --------------------------------------------------------------------
# RACING
# --------------------------------------------------------------------

func _handle_racing(delta: float) -> void:

	if current_racing_line == null:
		select_racing_line()

	if current_racing_line == null:
		return


	var segment_end_offset = (
		current_racing_line.get_segment_end_offset(
			current_gate
		)
	)


	# --------------------------------------------------------------
	# Atualiza o offset somente em uma pequena região à frente.
	#
	# Isso impede que a IA pule para outra passagem da RacingLine
	# quando existem curvas/interseções próximas.
	# --------------------------------------------------------------

	var closest_offset = (
		current_racing_line.find_closest_offset_forward(
			car.global_position,
			racing_offset,
			segment_end_offset
		)
	)

	racing_offset = closest_offset


	# --------------------------------------------------------------
	# TARGET
	# --------------------------------------------------------------

	var target_result = (
		current_racing_line.get_target_for_gate_segment(
			racing_offset,
			current_gate,
			racing_line_look_ahead
		)
	)

	if target_result.is_empty():
		return


	var target_position: Vector3 = target_result.position


	# --------------------------------------------------------------
	# STEERING
	# --------------------------------------------------------------

	_handle_steering(
		target_position,
		delta
	)


	# --------------------------------------------------------------
	# ACCELERATION
	# --------------------------------------------------------------

	_handle_acceleration(
		target_result
	)


	# --------------------------------------------------------------
	# STUCK
	# --------------------------------------------------------------

	_handle_stuck(delta)


# --------------------------------------------------------------------
# STEERING
# --------------------------------------------------------------------

func _handle_steering(
	target_position: Vector3,
	delta: float
) -> void:

	var local_target = car.to_local(
		target_position
	)

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


	var smoothing_speed = steering_smoothing

	car.steering = move_toward(
		car.steering,
		desired_steering,
		smoothing_speed * delta
	)


# --------------------------------------------------------------------
# ACCELERATION
# --------------------------------------------------------------------

func _handle_acceleration(
	_target_result: Dictionary
) -> void:

	var speed = car.linear_velocity.length()

	var target_speed = (
		car.max_speed
		* difficulty_speed_multiplier
	)


	if speed < target_speed:
		car.engine_force = car.engine_power
	else:
		car.engine_force = 0.0

	car.brake = 0.0


# --------------------------------------------------------------------
# AIRBORNE
# --------------------------------------------------------------------

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


	var target_position: Vector3 = target_result.position

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

	# Mantém impulso durante o salto.
	car.engine_force = car.engine_power


# --------------------------------------------------------------------
# RACING LINE SELECTION
# --------------------------------------------------------------------

func select_racing_line(
	force: bool = false
) -> void:

	if racing_line_locked and not force:
		return


	var track: Track = GameManager.race.track

	if track == null:
		return


	# --------------------------------------------------------------
	# Em vez de analisar todas as RacingLines detalhadamente,
	# Track primeiro reduz a lista para poucas candidatas.
	# --------------------------------------------------------------

	var racing_lines = (
		track.get_racing_line_candidates(
			car.global_position,
			current_gate,
			racing_line_candidate_count,
			current_racing_line
		)
	)


	# --------------------------------------------------------------
	# Fallback
	# --------------------------------------------------------------

	if racing_lines.is_empty():

		current_racing_line = track.default_racing_line
		racing_line_locked = false

		if current_racing_line != null:
			racing_offset = (
				current_racing_line.find_initial_offset_for_gate(
					car.global_position,
					current_gate
				)
			)

		return


	var car_position = car.global_position


	var car_forward = (
		-car.global_transform.basis.z
	)

	car_forward.y = 0.0

	if car_forward.length_squared() > 0.001:
		car_forward = car_forward.normalized()


	var best_line: RacingLine = null
	var best_offset: float = 0.0
	var best_score = INF


	# --------------------------------------------------------------
	# BUSCA DETALHADA
	#
	# Aqui ainda fazemos a busca completa, mas somente nas
	# 2~3 linhas candidatas.
	# --------------------------------------------------------------

	for line in racing_lines:

		if line == null:
			continue

		if not line.is_initialized:
			continue


		var closest_data = (
			line.get_closest_point_to_car(
				car_position,
				current_gate
			)
		)


		if closest_data.is_empty():
			continue


		var distance: float = (
			closest_data.distance
		)

		var offset: float = (
			closest_data.offset
		)


		var line_direction = (
			line.get_direction_at_offset(
				offset
			)
		)

		line_direction.y = 0.0


		if line_direction.length_squared() <= 0.001:
			continue


		line_direction = line_direction.normalized()


		var direction_dot = (
			car_forward.dot(line_direction)
		)


		var direction_penalty = (
			1.0 - direction_dot
		) * racing_line_direction_weight


		var score = (
			distance
			+ direction_penalty
		)


		# Pequena preferência pela linha anterior.
		#
		# Isso é especialmente útil quando duas linhas ficam
		# praticamente sobrepostas em uma interseção.
		if line == current_racing_line:
			score -= racing_line_switch_margin


		if score < best_score:

			best_score = score
			best_line = line

			# IMPORTANTE:
			# reaproveitamos o offset já calculado.
			#
			# Antes fazíamos uma segunda busca através de
			# find_initial_offset_for_gate().
			best_offset = offset


	if best_line == null:
		return


	# --------------------------------------------------------------
	# RESULTADO
	# --------------------------------------------------------------

	current_racing_line = best_line
	racing_offset = best_offset

	racing_line_locked = true


# --------------------------------------------------------------------
# GATE
# --------------------------------------------------------------------

func update_gate_target(
	gate_index: int
) -> void:

	current_gate = gate_index

	racing_line_locked = false

	select_racing_line(true)


func set_next_gate_target(
	gate_index: int
) -> void:

	update_gate_target(
		gate_index
	)


# --------------------------------------------------------------------
# STUCK
# --------------------------------------------------------------------

func _handle_stuck(delta: float) -> void:

	var speed = car.linear_velocity.length()

	if speed < stuck_speed_threshold:
		stuck_timer += delta
	else:
		stuck_timer = 0.0


	if stuck_timer < stuck_time_threshold:
		return


	if difficulty_reverse_delay > 0.0:
		if stuck_timer < difficulty_reverse_delay:
			return


	is_reversing = true
	reverse_timer = reverse_duration
	stuck_timer = 0.0


# --------------------------------------------------------------------
# REVERSE
# --------------------------------------------------------------------

func _handle_reverse(delta: float) -> void:

	reverse_timer -= delta

	car.engine_force = -car.engine_power
	car.brake = 0.0

	car.steering = move_toward(
		car.steering,
		0.0,
		steering_speed * delta
	)


	if reverse_timer <= 0.0:
		is_reversing = false
		car.engine_force = 0.0
