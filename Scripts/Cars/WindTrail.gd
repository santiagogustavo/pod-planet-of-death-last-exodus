@tool
extends GPUTrail3D
class_name WindTrail

@export var car: Car

func _process(_delta: float) -> void:
	if !car:
		return
	var current_speed = car.speed_kmh
	var intensity = clamp(current_speed / 10000.0, 0.0, 0.01)
	transparency = intensity
