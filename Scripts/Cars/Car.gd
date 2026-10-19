extends VehicleBody3D
class_name Car

signal gate_passed
signal collided

@export var player_input: PlayerInput
@export var max_speed: float = 300.0
@export var engine_power = 500
@export var brake_force = 10
@export var max_brake: float = 50.0
@export var wheels: Array[VehicleWheel3D] = []
@export var brake_lights: Array[OmniLight3D] = []
@export var skid_marks: Array[SkidMarks] = []
@export var wind_trails: Array[GPUTrail3D] = []

@export_category("Custom SFX")
@export var custom_running_sfx: AudioStream

@onready var sparks_prefab: PackedScene = load("res://Prefabs/Particles/HitSpark.tscn")
@onready var debris_prefab: PackedScene = load("res://Prefabs/Particles/Debris.tscn")

@onready var running_sfx: AudioStreamPlayer3D = $SFX/Running
@onready var brake_sfx: AudioStreamPlayer3D = $SFX/Brake
@onready var collision_road_sfx: AudioStreamPlayer3D = $SFX/CollisionRoad
@onready var collision_wall_sfx: AudioStreamPlayer3D = $SFX/CollisionWall
@onready var grinding_sfx: AudioStreamPlayer3D = $SFX/Grinding

var speed_ms: float = 0.0
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
var collided_bodies: Array[Node3D] = []

var flipped_timer: float = 0.0
var need_physics_reset: bool = false
const TIME_TO_TRIGGER_RESET: float = 2.0

func _ready() -> void:
	can_sleep = false
	engine_force = 0.0
	brake = max_brake
	if custom_running_sfx:
		running_sfx.stream = custom_running_sfx
		running_sfx.play()
	body_entered.connect(func (body: CollisionObject3D) -> void:
		match body.collision_layer:
			2:
				if !collision_road_sfx.playing:
					collision_road_sfx.play()
				if player_input:
					InputManager.vibrate_controller(0, 0.5, 0.0, 0.1)
			1, 4:
				if !grinding_sfx.playing:
					grinding_sfx.play()
				if !collision_wall_sfx.playing:
					collision_wall_sfx.play()
				if player_input:
					InputManager.vibrate_controller(0, 0.0, 1.0, 0.1)
	)
	body_exited.connect(func (body: CollisionObject3D) -> void:
		if collided_bodies.find(body) != -1:
			collided_bodies.remove_at(collided_bodies.find(body))
		grinding_sfx.stop()
	)

func _process(delta: float) -> void:
	update_sound()
	update_wind_trails()
	update_brake_lights_and_sfx()
	if player_input:
		update_player_input(delta)

func _physics_process(delta: float) -> void:
	speed_ms = linear_velocity.length()
	speed_kmh = speed_ms * 3.6
	speed_mph = speed_ms * 2.23694
	check_flipped_car(delta)
	update_engine_status()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var ai_node = get_node_or_null("PlayerBotAI")
	if ai_node and ai_node.has_method("car_custom_integrate_forces"):
		ai_node.car_custom_integrate_forces(state)

	if need_physics_reset:
		var reset_position = global_position + Vector3(0, 0.5, 0)
		var new_transform = Transform3D(Basis.IDENTITY, reset_position)
		
		var chase_camera_node = get_node_or_null("ChaseCamera")
		if chase_camera_node:
			var look_target = (chase_camera_node as ChaseCamera).camera.global_position
			look_target.y = reset_position.y
			if reset_position.distance_to(look_target) > 1.0:
				new_transform = new_transform.looking_at(look_target, Vector3.UP)
				new_transform.basis = new_transform.basis.rotated(Vector3.UP, PI)
		state.transform = new_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		engine_force = 0.0
		steering = 0.0
		brake = 0.0
		flipped_timer = 0.0
		need_physics_reset = false

	var contact_count = state.get_contact_count()
	for i in range(contact_count):
		var collision_point = state.get_contact_local_position(i)
		var collision_normal = state.get_contact_local_normal(i)
		var collision_body = state.get_contact_collider_object(i)
		handle_car_collision(collision_point, collision_normal, collision_body)
		handle_car_grinding_collision(collision_point, collision_normal)

func check_flipped_car(delta: float) -> void:
	var car_up_vector = global_transform.basis.y
	if car_up_vector.dot(Vector3.UP) < 0.2: 
		if has_method("set_sleeping"):
			sleeping = false
		flipped_timer += delta
		if flipped_timer >= TIME_TO_TRIGGER_RESET:
			need_physics_reset = true
			return
	else:
		flipped_timer = max(0.0, flipped_timer - delta * 2)

func update_player_input(delta: float) -> void:
	steering = move_toward(
		steering,
		player_input.steering if player_input else 0.0,
		delta * 5.0
	)
	handbrake = player_input.handbrake if player_input else false
	acceleration = player_input.acceleration if player_input and !handbrake else 0.0
	need_physics_reset = need_physics_reset or player_input.reset_car
	update_acceleration_and_brake()
	if acceleration == 0.0 and linear_velocity.length() < 1.0:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		engine_force = 0.0
		brake = max_brake

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
	if !is_braking:
		return
	brake = brake_force

func update_brake_lights_and_sfx() -> void:
	var is_braking: bool = brake > 0.0 and is_on_ground()
	for brake_light in brake_lights:
		brake_light.visible = is_braking
	if (
		is_braking
		and !brake_sfx.playing
		and GameManager.race.status == RaceManager.RaceStatus.Started
	):
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

func handle_car_collision(point: Vector3, normal: Vector3, collision_body: Node3D) -> void:
	if collided_bodies.find(collision_body) != -1:
		return
	collided.emit(speed_kmh, (collision_body as CollisionObject3D).collision_layer)
	collided_bodies.append(collision_body)
	var debris_instance: GPUParticles3D = debris_prefab.instantiate()
	get_tree().root.add_child(debris_instance)
	debris_instance.global_position = point
	var look_at_pos = point + normal + Vector3(0.001, 0, 0)
	debris_instance.look_at(look_at_pos)
	debris_instance.emitting = true

func handle_car_grinding_collision(point: Vector3, normal: Vector3) -> void:
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
