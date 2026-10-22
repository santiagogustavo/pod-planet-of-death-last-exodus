extends Node3D
class_name ChaseCamera

@export var car: Car
@export var fov_increase: float = 15.0
@export var camera_distances: Array[float] = [0.0, 6.0, 7.5]
@export var default_distance: int = 1
@export var camera_up_degrees: float = 7.5
@export var camera_tilt_x_position: float = 5.0
@export var camera_tilt_x_smooth: float = 5.0
@export var camera_tilt_y_angle: float = 5.0
@export var camera_tilt_y_smooth: float = 2.0
@export_range(1.0, 10.0, 0.1) var smooth_speed: float = 2.5

@onready var direction: Vector3 = -global_basis.z

@onready var camera: Camera3D = $Camera3D
@onready var camera_debug_texture = $Camera3D/CameraEffects/Control/DebugTexture
@onready var radial_blur: TextureRect = $Camera3D/CameraEffects/Control/RadialBlur
@onready var speed_lines: ColorRect = $Camera3D/CameraEffects/Control/SpeedLines
@onready var initial_fov: float = camera.fov
@onready var initial_rotation_x: float = camera.rotation_degrees.x
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var spring_position: Node3D = $SpringArm3D/SpringPosition

@onready var oil_splatter: GPUParticles2D = $Camera3D/CameraEffects/Control/Splatters/Oil
@onready var green_sludge_splatter: GPUParticles2D = $Camera3D/CameraEffects/Control/Splatters/GreenSludge
@onready var current_distance: int = default_distance

var speed_lines_sampling: float = 0.9
const COLLISION_SPEED_THRESHOLD: float = 150.0

var direction_override_timer: float = 0.0
var look_back: bool = false

func _ready() -> void:
	camera_debug_texture.queue_free()
	car.collided.connect(handle_car_collision)
	set_speed_lines()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("change_camera"):
		if current_distance < camera_distances.size() - 1:
			current_distance += 1
		else:
			current_distance = 0
	look_back = Input.is_action_pressed("look_back")
	update_camera_cull_mask()
	update_spring_arm()

func _physics_process(delta: float) -> void:
	update_direction_and_basis(delta)
	update_camera_collision(delta)
	update_camera(delta)
	update_radial_blur_intensity()
	update_speed_lines()

func reset_direction(new_direction: Vector3) -> void:
	new_direction.y = 0.0

	if new_direction.length_squared() <= 0.001:
		return

	direction = new_direction.normalized()
	direction_override_timer = 0.15

	global_transform.basis = get_rotation_from_direction(direction)

func set_speed_lines() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(self, "speed_lines_sampling", 1.0, 1.0)
	tween.tween_property(self, "speed_lines_sampling", 0.95, 1.0)

func update_spring_arm() -> void:
	spring_arm.spring_length = camera_distances[current_distance]

func update_direction_and_basis(delta: float) -> void:
	if direction_override_timer > 0.0:
		direction_override_timer -= delta
		global_transform.basis = get_rotation_from_direction(direction)
		return

	var current_velocity = car.linear_velocity
	current_velocity.y = 0

	if current_velocity.length_squared() > 1:
		direction = lerp(
			direction,
			current_velocity.normalized(),
			delta * smooth_speed
		)

	global_transform.basis = get_rotation_from_direction(direction)

func get_rotation_from_direction(look_direction: Vector3) -> Basis:
	look_direction = look_direction.normalized()
	var x_axis = look_direction.cross(Vector3.UP)
	return Basis(x_axis, Vector3.UP, - look_direction)

func update_camera(delta: float) -> void:
	var current_speed = car.speed_kmh
	var intensity = clamp(current_speed ** 2 / 10000.0, 0.0, 1.0)
	var apply_tilt_and_rotation = car.is_on_ground() and !look_back
	var tilt_position = (
		-car.steering * camera_tilt_x_position * intensity
		if apply_tilt_and_rotation
		else 0.0
	)
	var rotation_y_angle = (
		-car.steering * camera_tilt_y_angle * intensity / 2
		if apply_tilt_and_rotation
		else 0.0
	)
	camera.fov = initial_fov + fov_increase * intensity
	camera.rotation_degrees.x = initial_rotation_x + camera_up_degrees * intensity
	camera.position.x = lerp(
		camera.position.x,
		tilt_position,
		delta * camera_tilt_x_smooth
	)
	if car.engine_status != Car.EngineStatus.Reverse:
		rotation.y = lerp_angle(
			rotation.y,
			rotation_y_angle,
			delta * camera_tilt_y_smooth
		)
	if look_back:
		rotation_degrees.y = 180

func update_camera_cull_mask() -> void:
	camera.set_cull_mask_value(VisibilityLayers.DEBUG, GameManager.is_debug_mode)

func update_camera_collision(delta: float) -> void:
	camera.global_transform.origin = lerp(
		camera.global_transform.origin,
		spring_position.global_transform.origin,
		50 * delta
	)

func update_radial_blur_intensity() -> void:
	var current_speed = car.speed_kmh
	var intensity = clamp(current_speed / 10000.0, 0.0, 0.01)
	radial_blur.material.set("shader_parameter/blur_power", intensity)

func update_speed_lines() -> void:
	var current_speed = car.speed_kmh
	var intensity = clamp(current_speed / 1000.0, 0.0, 0.4)
	speed_lines.material.set("shader_parameter/sample_radius", speed_lines_sampling)
	speed_lines.material.set("shader_parameter/transparency", intensity)

func handle_car_collision(collision_speed: float, collision_layer: int) -> void:
	if collision_speed < COLLISION_SPEED_THRESHOLD or collision_layer == CollisionLayers.ROAD:
		return
	emit_oil_splatter()

func emit_oil_splatter() -> void:
	oil_splatter.emitting = true

func emit_green_sludge_splatter() -> void:
	green_sludge_splatter.emitting = true
