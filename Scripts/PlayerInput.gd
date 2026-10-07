extends Node
class_name PlayerInput

var acceleration: float = 0.0
var steering: float = 0.0
var handbrake: bool = false

func _process(_delta: float) -> void:
	steering = Input.get_axis("steer_right", "steer_left")
	acceleration = Input.get_axis("brake", "accelerate")
	handbrake = Input.is_action_pressed("handbrake")
