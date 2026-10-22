extends Node3D
class_name Track


@export var track_name: String = ""

@export var start_gates: Array[StartGate] = []
@export var circuit_gates: Array[CircuitGate] = []

@export var default_racing_line: RacingLine
@export var racing_lines: Array[RacingLine] = []


var accumulate_distances: Array[float] = []

var active_racing_lines: Array[RacingLine] = []


func _ready() -> void:
	GameManager.race.start_race_countdown()

	if !GameManager.race.track:
		GameManager.race.track = self

	initialize_gates()
	initialize_racing_lines()
	compute_accumulate_distances()


# --------------------------------------------------------------------
# GATES
# --------------------------------------------------------------------

func initialize_gates() -> void:
	var gate_index: int = 0

	for gate in circuit_gates:
		if gate == null:
			continue

		gate.gate_index = gate_index

		var next_gate_index = (
			gate_index + 1
			if gate_index < circuit_gates.size() - 1
			else 0
		)

		if circuit_gates.size() > 1:
			gate.segment_distance = gate.global_position.distance_to(
				circuit_gates[next_gate_index].global_position
			)
		else:
			gate.segment_distance = 0.0

		gate_index += 1


# --------------------------------------------------------------------
# RACING LINES
# --------------------------------------------------------------------

func initialize_racing_lines() -> void:
	active_racing_lines.clear()

	# A linha oficial é usada como referência de progresso.
	if default_racing_line != null:
		default_racing_line.initialize_racing_line()

	for line in racing_lines:
		if line == null:
			continue

		line.initialize_racing_line()

		if !line.is_initialized:
			continue

		if !active_racing_lines.has(line):
			active_racing_lines.append(line)


func get_racing_lines_for_gate(
	_current_gate: int
) -> Array[RacingLine]:

	return active_racing_lines


# --------------------------------------------------------------------
# OTIMIZAÇÃO DA SELEÇÃO
# --------------------------------------------------------------------

func get_racing_line_candidates(
	car_position: Vector3,
	current_gate: int,
	candidate_count: int = 3,
	preferred_line: RacingLine = null
) -> Array[RacingLine]:

	var result: Array[RacingLine] = []

	if active_racing_lines.is_empty():
		return result

	candidate_count = max(candidate_count, 1)

	# Se temos poucas linhas, não há motivo para fazer
	# nenhum filtro adicional.
	if active_racing_lines.size() <= candidate_count:
		for line in active_racing_lines:
			result.append(line)

		return result

	# --------------------------------------------------------------
	# A RacingLine atual recebe prioridade.
	#
	# Isso ajuda a manter estabilidade quando duas linhas passam
	# muito próximas umas das outras.
	# --------------------------------------------------------------

	if (
		preferred_line != null
		and active_racing_lines.has(preferred_line)
	):
		result.append(preferred_line)

		if result.size() >= candidate_count:
			return result


	# --------------------------------------------------------------
	# Descobrimos aproximadamente onde o carro está no segmento
	# usando SOMENTE a RacingLine oficial.
	#
	# Essa é a única busca mais cara dessa etapa.
	# --------------------------------------------------------------

	if (
		default_racing_line == null
		or not default_racing_line.is_initialized
	):
		for line in active_racing_lines:
			if result.has(line):
				continue

			result.append(line)

			if result.size() >= candidate_count:
				break

		return result


	var reference_data = (
		default_racing_line.get_closest_point_to_car(
			car_position,
			current_gate
		)
	)

	if reference_data.is_empty():
		for line in active_racing_lines:
			if result.has(line):
				continue

			result.append(line)

			if result.size() >= candidate_count:
				break

		return result


	var reference_offset: float = reference_data.offset

	var reference_progress = (
		default_racing_line.get_segment_progress_from_offset(
			current_gate,
			reference_offset
		)
	)


	# --------------------------------------------------------------
	# Agora cada RacingLine é consultada apenas em UM ponto
	# correspondente ao mesmo progresso do segmento.
	#
	# Isso é muito mais barato que fazer uma busca completa em
	# cada curva.
	# --------------------------------------------------------------

	var scored: Array[Dictionary] = []

	for line in active_racing_lines:
		if result.has(line):
			continue

		var offset = (
			line.get_offset_at_segment_progress(
				current_gate,
				reference_progress
			)
		)

		var point = line.get_point_at_offset(offset)

		var distance_squared = (
			point.distance_squared_to(car_position)
		)

		scored.append({
			"line": line,
			"distance_squared": distance_squared
		})


	scored.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a["distance_squared"] < b["distance_squared"]
	)


	var remaining = candidate_count - result.size()

	for i in range(min(remaining, scored.size())):
		result.append(scored[i]["line"])


	return result


# --------------------------------------------------------------------
# DISTÂNCIAS DA PISTA
# --------------------------------------------------------------------

func compute_accumulate_distances() -> void:
	accumulate_distances.clear()

	var accumulate_distance: float = 0.0

	for gate in circuit_gates:
		accumulate_distances.append(
			accumulate_distance
		)

		accumulate_distance += gate.segment_distance


func get_total_distance() -> float:
	if accumulate_distances.is_empty():
		return 0.0

	if circuit_gates.is_empty():
		return 0.0

	return (
		accumulate_distances[accumulate_distances.size() - 1]
		+ circuit_gates.back().segment_distance
	)
