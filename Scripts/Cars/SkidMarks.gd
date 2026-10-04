extends GPUParticles3D
class_name SkidMarks

@export var wheel: VehicleWheel3D

func _process(_delta: float) -> void:
	global_rotation.y = wheel.global_rotation.y

func _physics_process(_delta: float) -> void:
	emitting = wheel.get_skidinfo() < 0.2
