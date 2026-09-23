extends Node3D
class_name ChaseCamera

@export var fov_increase: float = 15.0
@export var camera_up_degrees: float = 7.5
@export var camera_tilt_x_position: float = 1.0
@export var camera_tilt_x_smooth: float = 5.0
@export_range(1.0, 10.0, 0.1) var smooth_speed: float = 2.5
var direction: Vector3 = Vector3.FORWARD

@onready var camera: Camera3D = $Camera3D
@onready var radial_blur: TextureRect = $Camera3D/Control/RadialBlur
@onready var initial_fov: float = camera.fov
@onready var initial_rotation_x: float = camera.rotation_degrees.x

func _physics_process(delta: float) -> void:
	update_direction_and_basis(delta)
	update_camera(delta)
	update_radial_blur_intensity()

func update_direction_and_basis(delta: float) -> void:
	var current_velocity = (get_parent() as Car).linear_velocity
	current_velocity.y = 0
	if current_velocity.length_squared() > 1:
		direction = lerp(direction, current_velocity.normalized(), delta * smooth_speed)
	global_transform.basis = get_rotation_from_direction(direction)

func get_rotation_from_direction(look_direction: Vector3) -> Basis:
	look_direction = look_direction.normalized()
	var x_axis = look_direction.cross(Vector3.UP)
	return Basis(x_axis, Vector3.UP, - look_direction)

func update_camera(delta: float) -> void:
	var current_speed = (get_parent() as Car).speed_kmh
	var intensity = clamp(current_speed ** 2 / 10000.0, 0.0, 1.0)
	camera.fov = initial_fov + fov_increase * intensity
	camera.rotation_degrees.x = initial_rotation_x + camera_up_degrees * intensity
	camera.position.x = lerp(
		camera.position.x,
		-(get_parent() as Car).steering * camera_tilt_x_position,
		delta * camera_tilt_x_smooth
	)

func update_radial_blur_intensity() -> void:
	var current_speed = (get_parent() as Car).speed_kmh
	var intensity = clamp(current_speed / 10000.0, 0.0, 0.01)
	radial_blur.material.set("shader_parameter/blur_power", intensity)
	
