extends VehicleBody3D
class_name Car

@export var engine_power = 500
@export var brake_force = 10
@export var brake_lights: Array[OmniLight3D] = []

@onready var running_sfx: AudioStreamPlayer3D = $Running
@onready var brake_sfx: AudioStreamPlayer3D = $Brake
var speed_kmh: float = 0.0
var acceleration: float = 0.0

enum EngineStatus {
	Forward,
	Reverse,
	Stopped,
}

var engine_status: EngineStatus = EngineStatus.Stopped

func _process(delta: float) -> void:
	update_sound()
	steering = move_toward(
		steering,
		Input.get_axis("ui_right", "ui_left"),
		delta * 5.0
	)
	acceleration = Input.get_axis("ui_down", "ui_up")
	if acceleration < 0.0 and engine_status == EngineStatus.Forward:
		brake = -acceleration * brake_force
		engine_force = 0.0
		update_brake()
	else:
		for brake_light in brake_lights:
			brake_light.visible = false
		engine_force = acceleration * engine_power
		brake = 0.0

func _physics_process(_delta: float) -> void:
	var speed_ms = linear_velocity.length()
	speed_kmh = speed_ms * 3.6
	update_engine_status()

func update_brake() -> void:
	for brake_light in brake_lights:
		brake_light.visible = true
	if !brake_sfx.playing:
		brake_sfx.play()

func update_engine_status() -> void:
	var forward_dir = -global_transform.basis.z
	var forward_speed = linear_velocity.dot(forward_dir)
	var threshold = 0.1
	
	if forward_speed > threshold:
		engine_status = EngineStatus.Forward
	elif forward_speed < -threshold:
		engine_status = EngineStatus.Reverse
	else:
		engine_status = EngineStatus.Stopped

func update_sound() -> void:
	var running_pitch: float = (linear_velocity.length() / 52) + 0.5
	running_sfx.pitch_scale = running_pitch
	var intensity = clamp(speed_kmh / 50.0, 0.0, 1.0)
	running_sfx.unit_size = 5.0 + intensity * 5.0
