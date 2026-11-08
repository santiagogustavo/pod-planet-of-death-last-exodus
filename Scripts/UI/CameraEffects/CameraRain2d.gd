extends Control
class_name CameraRain2d

@export var effect_enabled = false
@export var minimum_camera_rotation = 15

@onready var particle_droplets_1: GPUParticles2D = $Droplets1
@onready var particle_droplets_2: GPUParticles2D = $Droplets2

func _process(_delta: float) -> void:
	visible = (
		GameManager.race and GameManager.race.track.weather == Track.Weather.Rainy
	)
	if !visible:
		return
	var current_camera = get_viewport().get_camera_3d()
	if !current_camera:
		return
	var is_emitting = current_camera.global_rotation_degrees.x >= minimum_camera_rotation and effect_enabled
	particle_droplets_1.emitting = is_emitting
	particle_droplets_2.emitting = is_emitting
