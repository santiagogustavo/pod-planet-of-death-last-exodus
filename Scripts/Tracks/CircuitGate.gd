extends Area3D
class_name CircuitGate

var gate_index: int = 0

func _ready() -> void:
	body_entered.connect(handle_car_entered)

func handle_car_entered(node: Node3D) -> void:
	(node as Car).handle_gate_passed(get_rid(), gate_index)
