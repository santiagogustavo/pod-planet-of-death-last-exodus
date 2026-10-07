extends Node3D
class_name ChaseCamera

@export var car: Car
@export var fov_increase: float = 15.0
@export var camera_up_degrees: float = 7.5
@export var camera_tilt_x_position: float = 5.0
@export var camera_tilt_y_angle: float = 1.0
@export var camera_tilt_x_smooth: float = 5.0
@export var camera_tilt_y_smooth: float = 5.0
@export_range(1.0, 10.0, 0.1) var smooth_speed: float = 2.5
var direction: Vector3 = Vector3.FORWARD

@onready var camera: Camera3D = $Camera3D
@onready var camera_debug_texture = $Camera3D/CameraEffects/Control/DebugTexture
@onready var radial_blur: TextureRect = $Camera3D/CameraEffects/Control/RadialBlur
@onready var speed_lines: ColorRect = $Camera3D/CameraEffects/Control/SpeedLines
@onready var initial_fov: float = camera.fov
@onready var initial_rotation_x: float = camera.rotation_degrees.x
@onready var spring_position: Node3D = $SpringArm3D/SpringPosition

var speed_lines_sampling: float = 0.9

func _ready() -> void:
	camera_debug_texture.queue_free()
	set_speed_lines()

func _physics_process(delta: float) -> void:
	update_direction_and_basis(delta)
	update_camera_collision(delta)
	update_camera(delta)
	update_radial_blur_intensity()
	update_speed_lines()

func set_speed_lines() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(self, "speed_lines_sampling", 1.0, 1.0)
	tween.tween_property(self, "speed_lines_sampling", 0.95, 1.0)

func update_direction_and_basis(delta: float) -> void:
	var current_velocity = car.linear_velocity
	current_velocity.y = 0
	if current_velocity.length_squared() > 1:
		direction = lerp(direction, current_velocity.normalized(), delta * smooth_speed)
	global_transform.basis = get_rotation_from_direction(direction)

func get_rotation_from_direction(look_direction: Vector3) -> Basis:
	look_direction = look_direction.normalized()
	var x_axis = look_direction.cross(Vector3.UP)
	return Basis(x_axis, Vector3.UP, - look_direction)

func update_camera(delta: float) -> void:
	var current_speed = car.speed_kmh
	var intensity = clamp(current_speed ** 2 / 10000.0, 0.0, 1.0)
	camera.fov = initial_fov + fov_increase * intensity
	camera.rotation_degrees.x = initial_rotation_x + camera_up_degrees * intensity
	camera.position.x = lerp(
		camera.position.x,
		-car.steering * camera_tilt_x_position * intensity,
		delta * camera_tilt_x_smooth
	)
	if car.engine_status != Car.EngineStatus.Reverse:
		rotation.y = lerp_angle(
			rotation.y,
			-car.steering * camera_tilt_y_angle * intensity / 2,
			delta * camera_tilt_y_smooth
		)

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
	
