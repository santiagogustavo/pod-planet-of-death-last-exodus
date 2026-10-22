extends Path3D
class_name RacingLine


@export_category("Racing Line")
@export var sample_step: float = 2.0

@export_category("Progress")
@export var max_backward_correction: float = 3.0
@export var max_forward_search: float = 20.0

@export_category("Look Ahead")
@export var default_look_ahead: float = 10.0
@export var max_look_ahead: float = 28.0
@export var curve_look_ahead_factor: float = 0.65

var debug_mesh_instance: MeshInstance3D
var debug_mesh: ImmediateMesh
var debug_material: StandardMaterial3D

var spline_length: float = 0.0

var gate_offsets: Array[float] = []
var gate_positions: Array[Vector3] = []
var segment_lengths: Array[float] = []

var is_initialized: bool = false


# --------------------------------------------------------------------
# CACHE DA CURVA
# --------------------------------------------------------------------

var cached_offsets: PackedFloat32Array = PackedFloat32Array()
var cached_positions: Array[Vector3] = []
var cached_directions: Array[Vector3] = []


# --------------------------------------------------------------------
# INITIALIZATION
# --------------------------------------------------------------------

func _ready() -> void:
	call_deferred("initialize_racing_line")


func initialize_racing_line() -> void:
	if is_initialized:
		return

	if curve == null:
		push_warning("RacingLine '%s' não possui Curve3D." % name)
		return

	spline_length = curve.get_baked_length()

	if spline_length <= 0.001:
		push_warning("RacingLine '%s' possui uma curva vazia." % name)
		return

	_cache_gate_data()
	_build_curve_cache()
	_build_debug_mesh()

	is_initialized = true


# --------------------------------------------------------------------
# CACHE DOS GATES
# --------------------------------------------------------------------

func _cache_gate_data() -> void:
	gate_offsets.clear()
	gate_positions.clear()
	segment_lengths.clear()

	var track: Track = GameManager.race.track

	if track == null:
		return

	for gate in track.circuit_gates:
		if gate == null:
			gate_offsets.append(0.0)
			gate_positions.append(Vector3.ZERO)
			continue

		var local_gate_position = to_local(gate.global_position)

		var offset = curve.get_closest_offset(local_gate_position)
		offset = clamp(offset, 0.0, spline_length)

		gate_offsets.append(offset)
		gate_positions.append(gate.global_position)

	# Cada segmento é:
	#
	# gate anterior -> gate atual
	#
	# Portanto segment_lengths[current_gate]
	# representa exatamente o segmento utilizado pelo BotAI.
	for gate_index in range(gate_offsets.size()):
		var start_offset = _get_segment_start_offset(gate_index)
		var end_offset = gate_offsets[gate_index]

		segment_lengths.append(
			_get_wrapped_distance(start_offset, end_offset)
		)


# --------------------------------------------------------------------
# CACHE PRINCIPAL DA CURVA
# --------------------------------------------------------------------

func _build_curve_cache() -> void:
	cached_offsets.clear()
	cached_positions.clear()
	cached_directions.clear()

	var spacing = max(sample_step, 0.25)

	var sample_count = max(
		int(ceil(spline_length / spacing)),
		2
	)

	cached_offsets.resize(sample_count + 1)
	cached_positions.resize(sample_count + 1)
	cached_directions.resize(sample_count + 1)

	for i in range(sample_count + 1):
		var offset = min(
			float(i) * spacing,
			spline_length
		)

		if i == sample_count:
			offset = spline_length

		cached_offsets[i] = offset

		var local_position = curve.sample_baked(offset, true)
		var cached_global_position = to_global(local_position)

		cached_positions[i] = cached_global_position

		var direction = _calculate_curve_direction(offset)
		cached_directions[i] = direction


func _calculate_curve_direction(offset: float) -> Vector3:
	var ahead_offset = _advance_offset(offset, 1.0)

	var current_point = curve.sample_baked(offset, true)
	var ahead_point = curve.sample_baked(ahead_offset, true)

	var direction = ahead_point - current_point
	direction.y = 0.0

	if direction.length_squared() <= 0.001:
		return Vector3.FORWARD

	return direction.normalized()


# --------------------------------------------------------------------
# CACHE LOOKUP
# --------------------------------------------------------------------

func _get_cached_index(offset: float) -> int:
	if cached_offsets.is_empty():
		return 0

	var clamped_offset = clamp(
		offset,
		0.0,
		spline_length
	)

	var spacing = max(sample_step, 0.25)

	var index = int(round(clamped_offset / spacing))

	return clamp(
		index,
		0,
		cached_offsets.size() - 1
	)


func _get_cached_position(offset: float) -> Vector3:
	if cached_positions.is_empty():
		return global_position

	if offset <= 0.0:
		return cached_positions[0]

	if offset >= spline_length:
		return cached_positions[cached_positions.size() - 1]

	var spacing = max(sample_step, 0.25)

	var float_index = offset / spacing
	var index_a = int(floor(float_index))
	var index_b = min(
		index_a + 1,
		cached_positions.size() - 1
	)

	var t = float_index - float(index_a)

	return cached_positions[index_a].lerp(
		cached_positions[index_b],
		t
	)


func _get_cached_direction(offset: float) -> Vector3:
	if cached_directions.is_empty():
		return Vector3.FORWARD

	if offset <= 0.0:
		return cached_directions[0]

	if offset >= spline_length:
		return cached_directions[cached_directions.size() - 1]

	var spacing = max(sample_step, 0.25)

	var float_index = offset / spacing
	var index_a = int(floor(float_index))
	var index_b = min(
		index_a + 1,
		cached_directions.size() - 1
	)

	var t = float_index - float(index_a)

	var direction = cached_directions[index_a].lerp(
		cached_directions[index_b],
		t
	)

	if direction.length_squared() <= 0.001:
		return Vector3.FORWARD

	return direction.normalized()


# --------------------------------------------------------------------
# TARGET
# --------------------------------------------------------------------

func get_bot_target(
	current_offset: float,
	current_gate: int,
	look_ahead: float = default_look_ahead
) -> Dictionary:

	if not is_initialized:
		return {}

	return get_target_for_gate_segment(
		current_offset,
		current_gate,
		look_ahead
	)


func get_target_for_gate_segment(
	current_offset: float,
	current_gate: int,
	look_ahead: float = default_look_ahead
) -> Dictionary:

	if not is_initialized:
		return {}

	if current_gate < 0 or current_gate >= gate_offsets.size():
		return {}

	var segment_start = _get_segment_start_offset(current_gate)
	var segment_length = get_segment_length(current_gate)

	if segment_length <= 0.001:
		return {}

	var progress = _get_forward_distance(
		segment_start,
		current_offset
	)

	progress = clamp(
		progress,
		0.0,
		segment_length
	)

	var remaining_distance = segment_length - progress

	var target_distance = min(
		look_ahead,
		remaining_distance
	)

	target_distance = clamp(
		target_distance,
		0.0,
		max_look_ahead
	)

	var target_offset = _advance_offset(
		current_offset,
		target_distance
	)

	var target_position = get_point_at_offset(target_offset)

	return {
		"position": target_position,
		"offset": target_offset,
		"progress": progress / segment_length,
		"remaining_distance": remaining_distance
	}


# --------------------------------------------------------------------
# CLOSEST POINT
# --------------------------------------------------------------------

func find_initial_offset_for_gate(
	car_position: Vector3,
	gate_index: int
) -> float:

	if gate_offsets.is_empty():
		return 0.0

	var start_offset = _get_segment_start_offset(gate_index)
	var end_offset = gate_offsets[gate_index]

	return find_closest_offset_in_range(
		car_position,
		start_offset,
		end_offset
	)


func find_closest_offset_in_range(
	car_position: Vector3,
	start_offset: float,
	end_offset: float
) -> float:

	var segment_length = _get_wrapped_distance(
		start_offset,
		end_offset
	)

	if segment_length <= 0.001:
		return start_offset

	var sample_count = max(
		int(ceil(segment_length / max(sample_step, 0.5))),
		8
	)

	var best_offset = start_offset
	var best_distance_squared = INF

	for i in range(sample_count + 1):
		var progress = float(i) / float(sample_count)

		var offset = _advance_offset(
			start_offset,
			progress * segment_length
		)

		var point = get_point_at_offset(offset)

		var distance_squared = point.distance_squared_to(
			car_position
		)

		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_offset = offset

	return best_offset


func find_closest_offset_forward(
	car_position: Vector3,
	start_offset: float,
	end_offset: float
) -> float:

	var available_distance = _get_forward_distance(
		start_offset,
		end_offset
	)

	var search_distance = min(
		available_distance,
		max_forward_search
	)

	if search_distance <= 0.001:
		return start_offset

	var sample_count = max(
		int(ceil(search_distance / max(sample_step, 0.5))),
		4
	)

	var best_offset = start_offset
	var best_distance_squared = INF

	for i in range(sample_count + 1):
		var distance = (
			float(i) / float(sample_count)
		) * search_distance

		var offset = _advance_offset(
			start_offset,
			distance
		)

		var point = get_point_at_offset(offset)

		var distance_squared = point.distance_squared_to(
			car_position
		)

		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_offset = offset

	return best_offset


func get_closest_point_to_car(
	car_position: Vector3,
	current_gate: int
) -> Dictionary:

	if gate_offsets.is_empty():
		return {}

	if current_gate < 0 or current_gate >= gate_offsets.size():
		return {}

	var start_offset = _get_segment_start_offset(current_gate)
	var end_offset = gate_offsets[current_gate]

	var closest_offset = find_closest_offset_in_range(
		car_position,
		start_offset,
		end_offset
	)

	var closest_point = get_point_at_offset(
		closest_offset
	)

	return {
		"offset": closest_offset,
		"position": closest_point,
		"distance": closest_point.distance_to(car_position)
	}


# --------------------------------------------------------------------
# SEGMENT PROGRESS
# --------------------------------------------------------------------

func get_offset_at_segment_progress(
	current_gate: int,
	progress: float
) -> float:

	if gate_offsets.is_empty():
		return 0.0

	if current_gate < 0 or current_gate >= gate_offsets.size():
		return 0.0

	var start_offset = _get_segment_start_offset(current_gate)
	var segment_length = get_segment_length(current_gate)

	if segment_length <= 0.001:
		return start_offset

	return _advance_offset(
		start_offset,
		clamp(progress, 0.0, 1.0) * segment_length
	)


func get_point_at_segment_progress(
	current_gate: int,
	progress: float
) -> Vector3:

	return get_point_at_offset(
		get_offset_at_segment_progress(
			current_gate,
			progress
		)
	)


func get_direction_at_segment_progress(
	current_gate: int,
	progress: float
) -> Vector3:

	return get_direction_at_offset(
		get_offset_at_segment_progress(
			current_gate,
			progress
		)
	)


func get_segment_progress_from_offset(
	current_gate: int,
	offset: float
) -> float:

	if gate_offsets.is_empty():
		return 0.0

	if current_gate < 0 or current_gate >= gate_offsets.size():
		return 0.0

	var start_offset = _get_segment_start_offset(current_gate)
	var segment_length = get_segment_length(current_gate)

	if segment_length <= 0.001:
		return 0.0

	var distance = _get_forward_distance(
		start_offset,
		offset
	)

	return clamp(
		distance / segment_length,
		0.0,
		1.0
	)


# --------------------------------------------------------------------
# POINT / DIRECTION
# --------------------------------------------------------------------

func get_point_at_offset(offset: float) -> Vector3:
	return _get_cached_position(offset)


func get_direction_at_offset(offset: float) -> Vector3:
	return _get_cached_direction(offset)


func get_direction_for_gate(gate_index: int) -> Vector3:
	if gate_offsets.is_empty():
		return Vector3.FORWARD

	if gate_index < 0 or gate_index >= gate_offsets.size():
		return Vector3.FORWARD

	return get_direction_at_offset(
		gate_offsets[gate_index]
	)


# --------------------------------------------------------------------
# CURVE / PROGRESS
# --------------------------------------------------------------------

func get_curve_amount(offset: float) -> float:
	var distance = 3.0

	var previous_offset = _advance_offset(
		offset,
		-distance
	)

	var next_offset = _advance_offset(
		offset,
		distance
	)

	var direction_a = get_direction_at_offset(
		previous_offset
	)

	var direction_b = get_direction_at_offset(
		next_offset
	)

	return 1.0 - clamp(
		direction_a.dot(direction_b),
		-1.0,
		1.0
	)


func get_spline_length() -> float:
	return spline_length


func get_gate_offset(gate_index: int) -> float:
	if gate_offsets.is_empty():
		return 0.0

	if gate_index < 0 or gate_index >= gate_offsets.size():
		return 0.0

	return gate_offsets[gate_index]


func get_next_gate_offset(gate_index: int) -> float:
	if gate_offsets.is_empty():
		return 0.0

	var next_gate = gate_index + 1

	if next_gate >= gate_offsets.size():
		next_gate = 0

	return gate_offsets[next_gate]


func get_segment_end_offset(current_gate: int) -> float:
	if gate_offsets.is_empty():
		return 0.0

	if current_gate < 0 or current_gate >= gate_offsets.size():
		return 0.0

	return gate_offsets[current_gate]


func get_segment_length(current_gate: int) -> float:
	if current_gate < 0 or current_gate >= segment_lengths.size():
		return 0.0

	return segment_lengths[current_gate]


func get_gate_count() -> int:
	return gate_offsets.size()


func get_progress_from_gate(
	gate_index: int,
	offset: float
) -> float:

	return get_segment_progress_from_offset(
		gate_index,
		offset
	)


func get_target_ahead(
	current_offset: float,
	distance: float
) -> Vector3:

	return get_point_at_offset(
		_advance_offset(
			current_offset,
			distance
		)
	)


func get_distance_to_segment(
	start_gate: int,
	end_gate: int
) -> float:

	if gate_offsets.is_empty():
		return 0.0

	var start_offset = get_gate_offset(start_gate)
	var end_offset = get_gate_offset(end_gate)

	return _get_forward_distance(
		start_offset,
		end_offset
	)


# --------------------------------------------------------------------
# INTERNAL OFFSET HELPERS
# --------------------------------------------------------------------

func _get_segment_start_offset(current_gate: int) -> float:
	if gate_offsets.is_empty():
		return 0.0

	var previous_gate = current_gate - 1

	if previous_gate < 0:
		previous_gate = gate_offsets.size() - 1

	return gate_offsets[previous_gate]


func _advance_offset(
	start_offset: float,
	distance: float
) -> float:

	if spline_length <= 0.001:
		return 0.0

	var result = start_offset + distance

	while result < 0.0:
		result += spline_length

	while result > spline_length:
		result -= spline_length

	return result


func _get_forward_distance(
	start_offset: float,
	end_offset: float
) -> float:

	if spline_length <= 0.001:
		return 0.0

	var distance = end_offset - start_offset

	if distance < 0.0:
		distance += spline_length

	return distance


func _get_wrapped_distance(
	start_offset: float,
	end_offset: float
) -> float:

	return _get_forward_distance(
		start_offset,
		end_offset
	)

func _build_debug_mesh() -> void:
	if cached_positions.size() < 2:
		return

	debug_mesh = ImmediateMesh.new()
	debug_material = StandardMaterial3D.new()

	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.vertex_color_use_as_albedo = true

	debug_mesh_instance = MeshInstance3D.new()
	debug_mesh_instance.mesh = debug_mesh
	debug_mesh_instance.material_override = debug_material
	debug_mesh_instance.set_layer_mask_value(VisibilityLayers.GENERAL, false)
	debug_mesh_instance.set_layer_mask_value(VisibilityLayers.DEBUG, true)

	add_child(debug_mesh_instance)

	debug_mesh.surface_begin(
		Mesh.PRIMITIVE_LINE_STRIP,
		debug_material
	)
	debug_mesh.surface_set_color(
		Color(0.1, 0.8, 1.0, 1.0)
	)

	for cached_position in cached_positions:
		debug_mesh.surface_add_vertex(
			to_local(cached_position)
		)

	debug_mesh.surface_end()
