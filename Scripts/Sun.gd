extends DirectionalLight3D
class_name Sun

static var effective_sun_direction: Vector3 = Vector3.ZERO
static var unprojected_sun_direction: Vector2 = Vector2.ZERO
static var is_sun_visible: bool = false

var camera: Camera3D

func _process(_delta: float) -> void:
	camera = get_viewport().get_camera_3d()
	if !camera:
		return
	effective_sun_direction = global_position
	is_sun_visible = not camera.is_position_behind(global_position) and !check_sun_occlusion()
	if is_sun_visible:
		unprojected_sun_direction = camera.unproject_position(global_position)

func check_sun_occlusion() -> bool:
	if not camera:
		return false

	var space_state = get_world_3d().direct_space_state
	var origin = camera.global_position
	var target = global_position

	# Create physics query parameters from camera to sun
	var query = PhysicsRayQueryParameters3D.create(origin, target)
	
	# Optional: Exclude the camera or sun from being hit if they have collision shapes
	# query.exclude = [self.get_rid()]

	var result = space_state.intersect_ray(query)

	if result:
		# An object was hit between the camera and the sun
		return true

	# Nothing is in the way
	return false
