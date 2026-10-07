extends GPUParticles3D
class_name SkidMarks

@export var wheel: VehicleWheel3D
var car: Car

func _ready() -> void:
	car = wheel.get_parent()

func _process(_delta: float) -> void:
	global_rotation.y = wheel.global_rotation.y

func _physics_process(_delta: float) -> void:
	emitting = (
		wheel.get_skidinfo() < 0.2
		or (car.acceleration < 0.0 and car.speed_kmh != 0.0)
		or (car.handbrake)
	)
