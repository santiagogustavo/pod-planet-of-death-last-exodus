extends VehicleBody3D
class_name Car

signal gate_passed

@export var player_input: PlayerInput
@export var max_speed: float = 300.0
@export var engine_power = 500
@export var brake_force = 10
@export var max_brake: float = 50.0
@export var wheels: Array[VehicleWheel3D] = []
@export var brake_lights: Array[OmniLight3D] = []
@export var skid_marks: Array[SkidMarks] = []
@export var wind_trails: Array[GPUTrail3D] = []

@onready var sparks_prefab: PackedScene = load("res://Prefabs/Particles/HitSpark.tscn")

@onready var running_sfx: AudioStreamPlayer3D = $SFX/Running
@onready var brake_sfx: AudioStreamPlayer3D = $SFX/Brake
@onready var collision_road_sfx: AudioStreamPlayer3D = $SFX/CollisionRoad
@onready var collision_wall_sfx: AudioStreamPlayer3D = $SFX/CollisionWall
@onready var grinding_sfx: AudioStreamPlayer3D = $SFX/Grinding
var speed_kmh: float = 0.0
var speed_mph: float = 0.0
var acceleration: float = 0.0
var handbrake: bool = false

enum EngineStatus {
	Forward,
	Reverse,
	Stopped,
}

var engine_status: EngineStatus = EngineStatus.Stopped
var can_reverse: bool = false
var reverse_timeout: float = 1.0

func _ready() -> void:
	body_entered.connect(func (body: CollisionObject3D) -> void:
		match body.collision_layer:
			2:
				if !collision_road_sfx.playing:
					collision_road_sfx.play()
				InputManager.vibrate_controller(0, 0.5, 0.0, 0.1)
			1, 4:
				if !grinding_sfx.playing:
					grinding_sfx.play()
				if !collision_wall_sfx.playing:
					collision_wall_sfx.play()
				InputManager.vibrate_controller(0, 0.0, 1.0, 0.1)
	)
	body_exited.connect(func (_body: CollisionObject3D) -> void:
		grinding_sfx.stop()
	)

func _process(delta: float) -> void:
	update_sound()
	update_wind_trails()
	steering = move_toward(
		steering,
		player_input.steering if player_input else 0.0,
		delta * 5.0
	)
	handbrake = player_input.handbrake if player_input else false
	acceleration = player_input.acceleration if player_input and !handbrake else 0.0
	update_acceleration_and_brake()
	if acceleration == 0.0 and linear_velocity.length() < 1.0:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		engine_force = 0.0
		brake = max_brake

func _physics_process(_delta: float) -> void:
	var speed_ms = linear_velocity.length()
	speed_kmh = speed_ms * 3.6
	speed_mph = speed_ms * 2.23694
	update_engine_status()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if acceleration == 0.0:
		return
	var contact_count = state.get_contact_count()
	for i in range(contact_count):
		var collision_point = state.get_contact_local_position(i)
		var collision_normal = state.get_contact_local_normal(i)
		handle_car_collision(collision_point, collision_normal)

func update_acceleration_and_brake() -> void:
	if acceleration < 0.0 and engine_status == EngineStatus.Forward:
		update_brake(true)
	else:
		update_acceleration()
		update_brake(false)

func update_acceleration():
	engine_force = acceleration * engine_power
	brake = 0.0

func update_brake(is_braking: bool) -> void:
	if handbrake:
		if speed_kmh > 0.0 and !brake_sfx.playing:
			brake_sfx.play()
		brake = max_brake
		engine_force = 0.0
	for brake_light in brake_lights:
		brake_light.visible = is_braking
	if !is_braking:
		return
	brake = brake_force
	if !brake_sfx.playing:
		brake_sfx.play()

func update_engine_status() -> void:
	var forward_dir = -global_transform.basis.z
	var forward_speed = linear_velocity.dot(forward_dir)
	var threshold = 1.0
	
	if forward_speed > threshold:
		engine_status = EngineStatus.Forward
	elif forward_speed < -threshold:
		engine_status = EngineStatus.Reverse
	else:
		engine_status = EngineStatus.Stopped

func update_wind_trails() -> void:
	var current_speed = speed_kmh
	var intensity = clamp(current_speed / 200.0, 0.0, 1.0)
	var image = Image.create_empty(32, 32, false,Image.FORMAT_RGBA8)
	image.fill(Color(intensity, 0.0, 0.0))
	var texture = ImageTexture.create_from_image(image)
	texture.update(image)
	for wind_trail in wind_trails:
		wind_trail.visible = is_on_ground()
		wind_trail.texture = texture

func update_sound() -> void:
	var running_pitch: float = (linear_velocity.length() / 52) + 0.5
	running_sfx.pitch_scale = running_pitch
	var intensity = clamp(speed_kmh / 50.0, 0.0, 1.0)
	running_sfx.unit_size = 5.0 + intensity * 5.0

func handle_car_collision(point: Vector3, normal: Vector3) -> void:
	var sparks_instance: GPUParticles3D = sparks_prefab.instantiate()
	get_tree().root.add_child(sparks_instance)
	sparks_instance.global_position = point
	var look_at_pos = point + normal + Vector3(0.001, 0, 0)
	sparks_instance.look_at(look_at_pos)
	sparks_instance.emitting = true

func handle_gate_passed(gate_rid: RID, gate_index: int) -> void:
	gate_passed.emit(gate_rid, gate_index)

func is_on_ground() -> bool:
	for wheel in wheels:
		if wheel.is_in_contact():
			return true
	return false
