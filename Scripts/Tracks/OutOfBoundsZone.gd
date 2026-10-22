extends Area3D
class_name OutOfBoundsZone

func _ready() -> void:
	body_entered.connect(handle_car_entered)

func handle_car_entered(node: Node3D) -> void:
	var car = node as Car
	car.need_physics_reset = true
