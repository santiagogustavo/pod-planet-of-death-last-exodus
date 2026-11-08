extends Node
class_name PlayerInput

var acceleration: float = 0.0
var steering: float = 0.0
var handbrake: bool = false
var reset_car: bool = false

var camera_forward: Vector3 = Vector3.ZERO

func _process(_delta: float) -> void:
	if (
		!GameManager.race
		or GameManager.race.status != RaceManager.RaceStatus.Started
	):
		clear_variables()
		return
	steering = Input.get_axis("steer_right", "steer_left")
	acceleration = Input.get_axis("brake", "accelerate")
	handbrake = Input.is_action_pressed("handbrake")
	reset_car = Input.is_action_just_pressed("reset_car")

func clear_variables() -> void:
	acceleration = 0.0
	steering = 0.0
