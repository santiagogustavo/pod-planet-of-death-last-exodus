extends Node3D
class_name Track

@export var track_name: String = ""
@export var circuit_gates: Array[CircuitGate] = []

func _ready() -> void:
	if !GameManager.race.track:
		GameManager.race.track = self
		GameManager.race.start_race()
	var gate_index: int = 0
	for gate in circuit_gates:
		gate.gate_index = gate_index
		gate_index += 1
