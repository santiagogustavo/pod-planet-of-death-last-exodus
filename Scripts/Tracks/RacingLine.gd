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

@export_category("Debug")
@export var debug_enabled: bool = true
@export var debug_draw_distance: float = 100.0
@export var debug_sample_spacing: float = 2.0

var spline_length: float = 0.0

var gate_offsets: Array[float] = []
var gate_positions: Array[Vector3] = []

var is_initialized: bool = false


var debug_mesh_instance: MeshInstance3D
var debug_mesh: ImmediateMesh
var debug_material: StandardMaterial3D

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	call_deferred("initialize_racing_line")

func _process(_delta: float) -> void:
	if not debug_enabled:
		return
	if not is_initialized:
		return
	_update_debug_mesh()

func initialize_racing_line() -> void:
	is_initialized = false

	if curve == null:
		push_warning("RacingLine: nenhuma Curve3D foi encontrada.")
		return

	spline_length = curve.get_baked_length()
	if spline_length <= 0.0:
		push_warning("RacingLine: Curve3D possui comprimento inválido.")
		return

	_cache_gate_data()
	is_initialized = true
	_setup_debug()

func rebuild() -> void:
	initialize_racing_line()

# ============================================================
# GATES
# ============================================================

func _cache_gate_data() -> void:
	gate_offsets.clear()
	gate_positions.clear()

	if (GameManager.race == null or GameManager.race.track == null):
		return

	var gates = GameManager.race.track.circuit_gates
	if gates.is_empty():
		return

	for gate in gates:
		var gate_node = gate as Node3D
		if gate_node == null:
			gate_offsets.append(0.0)
			gate_positions.append(Vector3.ZERO)
			continue

		var gate_position = gate_node.global_position
		gate_positions.append(gate_position)

		var local_gate_position = to_local(gate_position)
		var offset = curve.get_closest_offset(local_gate_position)
		gate_offsets.append(offset)


# ============================================================
# PUBLIC TARGET API
# ============================================================

func get_bot_target(
	car_position: Vector3,
	current_gate: int,
	current_offset: float,
	current_speed: float
) -> Dictionary:
	if not is_initialized:
		initialize_racing_line()

	if not is_initialized:
		return {
			"position": car_position,
			"offset": current_offset
		}

	if gate_offsets.is_empty():
		return {
			"position": car_position,
			"offset": current_offset
		}

	if current_gate < 0 or current_gate >= gate_offsets.size():
		return {
			"position": car_position,
			"offset": current_offset
		}

	var segment_start = gate_offsets[current_gate]
	var segment_end = get_segment_end_offset(current_gate)

	var segment_length = _get_wrapped_distance(
		segment_start,
		segment_end
	)

	# Se acabamos de entrar no segmento,
	# garante que começamos no gate.
	if not _offset_inside_segment(
		current_offset,
		segment_start,
		segment_end
	):
		current_offset = segment_start

	# Procura somente à frente.
	var closest_offset = find_closest_offset_forward(
		car_position,
		current_offset,
		segment_end
	)

	var progress = _get_forward_distance(
		current_offset,
		closest_offset
	)

	# Nunca permite voltar.
	if progress <= segment_length:
		current_offset = closest_offset

	# --------------------------------------------------------
	# LOOK AHEAD
	# --------------------------------------------------------

	var speed_factor = clamp(
		current_speed / 25.0,
		0.0,
		1.0
	)

	var look_ahead = lerp(
		default_look_ahead,
		max_look_ahead,
		speed_factor
	)

	var curve_amount = get_curve_amount(
		current_offset
	)

	look_ahead *= lerp(
		1.0,
		curve_look_ahead_factor,
		curve_amount
	)

	# Nunca deixa o alvo ficar em cima do carro.
	look_ahead = max(
		look_ahead,
		5.0
	)

	var target_offset = _advance_offset(
		current_offset,
		look_ahead
	)

	var local_target = curve.sample_baked(
		target_offset,
		true
	)

	var global_target = to_global(
		local_target
	)

	return {
		"position": global_target,
		"offset": current_offset
	}

func get_target_for_gate_segment(
	current_offset: float,
	current_gate: int,
	look_ahead: float
) -> Dictionary:
	if not is_initialized:
		return {
			"position": global_position,
			"offset": current_offset
		}

	if gate_offsets.is_empty():
		return {
			"position": global_position,
			"offset": current_offset
		}

	if current_gate < 0 or current_gate >= gate_offsets.size():
		return {
			"position": global_position,
			"offset": current_offset
		}

	# ========================================================
	# current_gate É O GATE QUE AINDA PRECISAMOS PASSAR.
	#
	# Portanto:
	#
	# current_gate = 1
	# segmento = Gate 0 -> Gate 1
	#
	# current_gate = 2
	# segmento = Gate 1 -> Gate 2
	# ========================================================

	var previous_gate = current_gate - 1

	if previous_gate < 0:
		previous_gate = gate_offsets.size() - 1

	var segment_start = gate_offsets[previous_gate]
	var segment_end = gate_offsets[current_gate]

	var segment_length = _get_wrapped_distance(
		segment_start,
		segment_end
	)

	# --------------------------------------------------------
	# Progresso dentro do segmento.
	# --------------------------------------------------------

	var progress = _get_forward_distance(
		segment_start,
		current_offset
	)

	# --------------------------------------------------------
	# Se estamos fora do segmento atual, encontramos um ponto
	# inicial adequado.
	# --------------------------------------------------------

	if progress > segment_length:
		current_offset = segment_start
		progress = 0.0

	# --------------------------------------------------------
	# Avança pela RacingLine.
	# --------------------------------------------------------

	var target_progress = progress + look_ahead

	# Nunca deixa o alvo ultrapassar o Gate que precisa
	# ser validado.
	target_progress = min(
		target_progress,
		segment_length
	)

	# Mantemos uma pequena margem antes do Gate.
	var gate_margin = min(
		2.0,
		segment_length * 0.1
	)

	if segment_length > gate_margin:
		target_progress = min(
			target_progress,
			segment_length - gate_margin
		)

	var target_offset = _advance_offset(
		segment_start,
		target_progress
	)

	var local_target = curve.sample_baked(
		target_offset,
		true
	)

	return {
		"position": to_global(local_target),
		"offset": current_offset,
		"target_offset": target_offset
	}

# ============================================================
# FIND FORWARD POSITION
# ============================================================

func find_initial_offset_for_gate(
	car_position: Vector3,
	gate_index: int
) -> float:
	if not is_initialized:
		return 0.0

	if gate_offsets.is_empty():
		return 0.0

	var previous_gate = gate_index - 1

	if previous_gate < 0:
		previous_gate = gate_offsets.size() - 1

	var start_offset = gate_offsets[previous_gate]
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

	if segment_length <= 0.01:
		return start_offset

	var samples = max(
		int(segment_length / sample_step),
		8
	)

	var best_offset = start_offset
	var best_distance = INF

	for i in range(samples + 1):

		var t = float(i) / float(samples)

		var distance = segment_length * t

		var test_offset = _advance_offset(
			start_offset,
			distance
		)

		var local_point = curve.sample_baked(
			test_offset,
			true
		)

		var global_point = to_global(
			local_point
		)

		var distance_to_car = (
			global_point - car_position
		).length_squared()

		if distance_to_car < best_distance:

			best_distance = distance_to_car
			best_offset = test_offset

	return best_offset

func find_closest_offset_forward(
	car_position: Vector3,
	start_offset: float,
	end_offset: float
) -> float:
	var segment_length = _get_wrapped_distance(
		start_offset,
		end_offset
	)

	if segment_length <= 0.01:
		return start_offset

	var search_distance = min(
		segment_length,
		max_forward_search
	)

	var samples = max(
		int(search_distance / sample_step),
		4
	)

	var best_offset = start_offset
	var best_distance = INF

	for i in range(samples + 1):

		var t = float(i) / float(samples)

		var distance = search_distance * t

		var test_offset = _advance_offset(
			start_offset,
			distance
		)

		var local_point = curve.sample_baked(
			test_offset,
			true
		)

		var global_point = to_global(
			local_point
		)

		var distance_to_car = (
			global_point - car_position
		).length_squared()

		if distance_to_car < best_distance:

			best_distance = distance_to_car
			best_offset = test_offset

	return best_offset

# ============================================================
# SEGMENT
# ============================================================

func get_segment_end_offset(current_gate: int) -> float:
	if gate_offsets.is_empty():
		return 0.0

	if current_gate < 0 or current_gate >= gate_offsets.size():
		return 0.0

	return gate_offsets[current_gate]

func _offset_inside_segment(
	offset: float,
	start_offset: float,
	end_offset: float
) -> bool:
	var segment_length = _get_wrapped_distance(
		start_offset,
		end_offset
	)

	var distance = _get_forward_distance(
		start_offset,
		offset
	)

	return distance >= -0.01 and distance <= segment_length + 0.01

# ============================================================
# OFFSET MATH
# ============================================================

func _get_wrapped_distance(
	start_offset: float,
	end_offset: float
) -> float:
	if end_offset >= start_offset:
		return end_offset - start_offset

	return (
		spline_length
		- start_offset
		+ end_offset
	)

func _get_forward_distance(
	start_offset: float,
	end_offset: float
) -> float:
	var distance = end_offset - start_offset

	if distance < 0.0:
		distance += spline_length

	return distance

func get_distance_to_segment(
	car_position: Vector3,
	start_gate: int,
	end_gate: int
) -> Dictionary:
	var start_offset = gate_offsets[start_gate]
	var end_offset = gate_offsets[end_gate]

	var closest_offset = find_closest_offset_in_range(
		car_position,
		start_offset,
		end_offset
	)

	var closest_point = to_global(
		curve.sample_baked(
			closest_offset,
			true
		)
	)

	return {
		"offset": closest_offset,
		"distance": car_position.distance_to(closest_point),
		"position": closest_point
	}

func get_closest_point_to_car(
	car_position: Vector3,
	current_gate: int
) -> Dictionary:
	if gate_offsets.is_empty():
		return {}

	if current_gate < 0 or current_gate >= gate_offsets.size():
		return {}

	var previous_gate := current_gate - 1

	if previous_gate < 0:
		previous_gate = gate_offsets.size() - 1

	var start_offset := gate_offsets[previous_gate]
	var end_offset := gate_offsets[current_gate]

	var closest_offset := find_closest_offset_in_range(
		car_position,
		start_offset,
		end_offset
	)

	var local_point := curve.sample_baked(
		closest_offset,
		true
	)

	var global_point := to_global(
		local_point
	)

	return {
		"offset": closest_offset,
		"position": global_point,
		"distance": car_position.distance_to(global_point)
	}

func _advance_offset(
	offset: float,
	distance: float
) -> float:
	var result = offset + distance

	if spline_length <= 0.0:
		return result

	while result >= spline_length:
		result -= spline_length

	while result < 0.0:
		result += spline_length

	return result

# ============================================================
# CURVATURE
# ============================================================

func get_curve_amount(offset: float) -> float:
	if spline_length <= 0.0:
		return 0.0

	var sample_distance = 8.0

	var p0_offset = offset

	var p1_offset = _advance_offset(
		offset,
		sample_distance
	)

	var p2_offset = _advance_offset(
		offset,
		sample_distance * 2.0
	)

	var p0 = curve.sample_baked(
		p0_offset,
		true
	)

	var p1 = curve.sample_baked(
		p1_offset,
		true
	)

	var p2 = curve.sample_baked(
		p2_offset,
		true
	)

	var direction_a = p1 - p0
	var direction_b = p2 - p1

	direction_a.y = 0.0
	direction_b.y = 0.0

	if direction_a.length_squared() <= 0.001:
		return 0.0

	if direction_b.length_squared() <= 0.001:
		return 0.0

	direction_a = direction_a.normalized()
	direction_b = direction_b.normalized()

	var dot = clamp(
		direction_a.dot(direction_b),
		-1.0,
		1.0
	)

	return clamp(
		1.0 - dot,
		0.0,
		1.0
	)


# ============================================================
# DIRECTION
# ============================================================

func get_direction_at_offset(
	offset: float
) -> Vector3:
	var ahead_offset = _advance_offset(
		offset,
		1.0
	)

	var current_point = curve.sample_baked(
		offset,
		true
	)

	var ahead_point = curve.sample_baked(
		ahead_offset,
		true
	)

	var direction = ahead_point - current_point

	direction.y = 0.0

	if direction.length_squared() <= 0.001:
		return Vector3.FORWARD

	return direction.normalized()


func get_direction_for_gate(
	gate_index: int
) -> Vector3:
	if gate_offsets.is_empty():
		return Vector3.FORWARD

	if gate_index < 0 or gate_index >= gate_offsets.size():
		return Vector3.FORWARD

	return get_direction_at_offset(
		gate_offsets[gate_index]
	)


# ============================================================
# PROGRESS
# ============================================================

func get_spline_length() -> float:
	return spline_length

func get_gate_offset(gate_index: int) -> float:
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

func get_gate_count() -> int:
	return gate_offsets.size()

func get_progress_from_gate(
	gate_index: int,
	offset: float
) -> float:
	if gate_index < 0 or gate_index >= gate_offsets.size():
		return 0.0

	var start = gate_offsets[gate_index]

	var segment_length = _get_wrapped_distance(
		start,
		get_segment_end_offset(gate_index)
	)

	if segment_length <= 0.001:
		return 0.0

	var progress = _get_forward_distance(
		start,
		offset
	)

	return clamp(
		progress / segment_length,
		0.0,
		1.0
	)

func get_target_ahead(
	offset: float,
	distance: float
) -> Vector3:
	if not is_initialized:
		return global_position

	var target_offset = _advance_offset(
		offset,
		distance
	)

	var local_target = curve.sample_baked(
		target_offset,
		true
	)

	return to_global(local_target)

func get_point_at_offset(
	offset: float
) -> Vector3:
	var wrapped_offset = offset

	while wrapped_offset >= spline_length:
		wrapped_offset -= spline_length

	while wrapped_offset < 0.0:
		wrapped_offset += spline_length

	return to_global(
		curve.sample_baked(
			wrapped_offset,
			true
		)
	)

# ============================================================
# DEBUG
# ============================================================

func get_debug_target(
	car_position: Vector3,
	current_gate: int
) -> Vector3:
	var result = get_bot_target(
		car_position,
		current_gate,
		gate_offsets[current_gate] if not gate_offsets.is_empty() else 0.0,
		0.0
	)

	return result.position

func _update_debug_mesh() -> void:
	if debug_mesh == null:
		return

	debug_mesh.clear_surfaces()

	debug_mesh.surface_begin(
		Mesh.PRIMITIVE_LINES,
		debug_material
	)

	var distance = 0.0

	while distance < spline_length:

		var next_distance = min(
			distance + debug_sample_spacing,
			spline_length
		)

		var a = curve.sample_baked(
			distance,
			true
		)

		var b = curve.sample_baked(
			next_distance,
			true
		)

		debug_mesh.surface_set_color(
			Color(0.1, 0.8, 1.0, 1.0)
		)

		debug_mesh.surface_add_vertex(a)

		debug_mesh.surface_add_vertex(b)

		distance = next_distance

	debug_mesh.surface_end()

func _setup_debug() -> void:
	if not debug_enabled:
		return

	if debug_mesh_instance != null:
		debug_mesh_instance.queue_free()

	debug_mesh = ImmediateMesh.new()

	debug_material = StandardMaterial3D.new()
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.vertex_color_use_as_albedo = true

	debug_mesh_instance = MeshInstance3D.new()
	debug_mesh_instance.mesh = debug_mesh
	debug_mesh_instance.material_override = debug_material
	debug_mesh_instance.layers = VisibilityLayers.DEBUG

	add_child(debug_mesh_instance)

func get_debug_direction(
	offset: float
) -> Vector3:
	var point = get_point_at_offset(offset)

	var direction = get_direction_at_offset(
		offset
	)

	return point + direction * 5.0
