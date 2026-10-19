extends Node3D
class_name Track

@export var track_name: String = ""
@export var start_gates: Array[StartGate] = []
@export var circuit_gates: Array[CircuitGate] = []
@export var default_racing_line: RacingLine
@export var racing_lines: Array[RacingLine] = []

var accumulate_distances: Array[float] = []

func _ready() -> void:
	GameManager.race.start_race_countdown()
	if !GameManager.race.track:
		GameManager.race.track = self
	initialize_gates()
	initialize_racing_lines()
	compute_accumulate_distances()

func initialize_gates() -> void:
	var gate_index: int = 0
	for gate in circuit_gates:
		gate.gate_index = gate_index
		var next_gate_index = gate_index + 1 if gate_index < circuit_gates.size() - 1 else 0
		gate.segment_distance = gate.global_position.distance_to(circuit_gates[next_gate_index].global_position)
		gate_index += 1

func initialize_racing_lines() -> void:
	for line in racing_lines:
		line.initialize_racing_line()

func get_racing_lines_for_gate(_current_gate: int) -> Array[RacingLine]:
	var result: Array[RacingLine] = []

	for line in racing_lines:
		if line == null:
			continue

		if not line.is_initialized:
			continue

		result.append(line)

	return result

func compute_accumulate_distances() -> void:
	var accumulate_distance: float = 0.0
	for gate in circuit_gates:
		accumulate_distances.append(accumulate_distance)
		accumulate_distance += gate.segment_distance

func get_total_distance() -> float:
	return accumulate_distances[accumulate_distances.size() - 1]
