extends Node3D
class_name PlayerBotAI

enum Difficulty { EASY, MEDIUM, HARD }

@export_category("Dificuldade")
@export var difficulty: Difficulty = Difficulty.HARD

@export_category("Configurações Base")
@export var player_input: PlayerInput
@export var max_steer_angle: float = 0.6
@export var target_reach_radius: float = 5.0
@export var steering_speed: float = 5.0
@export var speed_steering_reduction: float = 0.005

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var car: Car = get_parent()

var current_gate: int = 0
var dynamic_safe_velocity: Vector3 = Vector3.ZERO

# --- MODIFICADORES DE DIFICULDADE (Calculados no _ready) ---
var speed_modifier: float = 1.0
var reaction_delay: float = 0.0
var error_offset: float = 0.0
var reaction_timer: float = 0.0
var current_target_offset: Vector3 = Vector3.ZERO

# --- SISTEMA DE RÉ (ANTI-FLICKER ATUALIZADO) ---
var stuck_timer: float = 0.0
var is_reversing: bool = false
var reverse_timer: float = 0.0
const STUCK_SPEED_THRESHOLD: float = 0.8
const TIME_TO_TRIGGER_REVERSE: float = 1.5
const REVERSE_DURATION: float = 1.4 

func _ready() -> void:
	navigation_agent.target_desired_distance = 6.0
	navigation_agent.path_desired_distance = 4.0 
	navigation_agent.path_max_distance = 5.0   
	navigation_agent.velocity_computed.connect(on_navigation_agent_3d_velocity_computed)
	_setup_difficulty_parameters()
	callable_num_frames_delay.call_deferred()

func _setup_difficulty_parameters() -> void:
	match difficulty:
		Difficulty.EASY:
			speed_modifier = 0.65       # 35% mais lenta que o potencial máximo do motor
			reaction_delay = 0.25       # Demora 250ms para recalcular desvios/trajetória
			error_offset = 2.5          # Erra o centro do gate por até 2.5 metros (faz curvas abertas)
		Difficulty.MEDIUM:
			speed_modifier = 0.85       # 15% mais lenta
			reaction_delay = 0.1        # Demora 100ms
			error_offset = 1.0          # Erra o centro por até 1 metro
		Difficulty.HARD:
			speed_modifier = 1.0        # Usa 100% da força do motor
			reaction_delay = 0.0        # Resposta instantânea frame a frame
			error_offset = 0.0          # Trajetória perfeita pelo centro do gate

func callable_num_frames_delay() -> void:
	await get_tree().physics_frame
	set_next_gate_target()

func car_custom_integrate_forces(_state: PhysicsDirectBodyState3D) -> void:
	if car.need_physics_reset:
		var reset_position = car.global_position + Vector3(0, 0.5, 0)
		var new_transform = Transform3D(Basis.IDENTITY, reset_position)
		
		if current_gate != -1 and not GameManager.race.track.circuit_gates.is_empty():
			var target_node = GameManager.race.track.circuit_gates[current_gate] as Node3D
			var look_target = target_node.global_position
			look_target.y = reset_position.y
			if reset_position.distance_to(look_target) > 1.0:
				new_transform = new_transform.looking_at(look_target, Vector3.UP)
				new_transform.basis = new_transform.basis.rotated(Vector3.UP, PI)

		stuck_timer = 0.0
		is_reversing = false

func _physics_process(delta: float) -> void:
	if (
		GameManager.race.status != RaceManager.RaceStatus.Started
		or GameManager.race.track.circuit_gates.is_empty()
		or current_gate == -1
	):
		return
	
	# 1. VERIFICAÇÃO DE PONTA-CABEÇA (Anti-Sleep)
	if car.need_physics_reset:
		return

	var current_speed = car.linear_velocity.length()
	var dynamic_steer_speed = steering_speed * (3.0 if current_speed < 1.5 else 1.0)

	# --- ATUALIZAÇÃO DO REACTION DELAY E OFFSET DE ERRO ---
	reaction_timer += delta
	if reaction_timer >= reaction_delay:
		reaction_timer = 0.0
		if error_offset > 0.0:
			# Gera um desvio aleatório horizontal para simular imperfeição na curva
			var random_dir = car.global_transform.basis.x * randf_range(-error_offset, error_offset)
			current_target_offset = random_dir
		else:
			current_target_offset = Vector3.ZERO

	# 2. CÁLCULO DE AGENTE DE NAVEGAÇÃO
	var next_path_position: Vector3 = navigation_agent.get_next_path_position() + current_target_offset
	# Dificuldade afeta diretamente a velocidade final desejada
	var target_speed = max(12.0, (car.engine_power * speed_modifier) / 12.0)
	
	var desired_direction = (next_path_position - car.global_position).normalized()
	var desired_velocity = desired_direction * target_speed
	
	navigation_agent.set_velocity(desired_velocity)

	var effective_velocity = dynamic_safe_velocity if dynamic_safe_velocity.length() > 0.5 else desired_velocity
	var local_safe_pos = car.to_local(car.global_position + effective_velocity)
	var forward_vector = -car.global_transform.basis.z
	var alignment_factor = forward_vector.dot(effective_velocity.normalized())

	# 3. COMPORTAMENTO DA MARCHA RÉ BLINDADO
	if is_reversing:
		reverse_timer -= delta
		if reverse_timer <= 0:
			is_reversing = false
			stuck_timer = 0.0
		else:
			car.engine_force = -car.engine_power * 0.8 * speed_modifier
			car.brake = 0.0
			var steer_dir = 1.0 if local_safe_pos.x > 0 else -1.0
			car.steering = move_toward(car.steering, max_steer_angle * 0.8 * steer_dir, dynamic_steer_speed * delta)
			return 

	# 4. MONITORAMENTO DE TRAVAMENTO
	var point_is_behind = alignment_factor < -0.4
	var trying_to_move = abs(car.engine_force) > 50.0 or car.brake > 10.0
	
	if current_speed < 0.4 and (trying_to_move or point_is_behind):
		stuck_timer += delta
		if stuck_timer >= TIME_TO_TRIGGER_REVERSE:
			is_reversing = true
			reverse_timer = REVERSE_DURATION
			car.brake = 0.0
			return
	else:
		stuck_timer = max(0.0, stuck_timer - delta * 2)

	# 5. CÁLCULO DE DIREÇÃO CONVENCIONAL
	var angle_to_target = atan2(-local_safe_pos.x, -local_safe_pos.z)
	var current_max_steer = max_steer_angle / (1.0 + current_speed * speed_steering_reduction)
	var desired_steering = clamp(angle_to_target, -current_max_steer, current_max_steer)
	car.steering = move_toward(car.steering, desired_steering, dynamic_steer_speed * delta)
	
	# 6. ACELERAÇÃO FLUIDA E AJUSTE ANTICOMPETIÇÃO
	var curve_smooth_factor = clamp(alignment_factor, 0.3, 1.0)
	
	# REGRA DE CORREÇÃO AGRESSIVA (Lento)
	if current_speed < 3.5:
		car.engine_force = car.engine_power * 0.8 * speed_modifier
		car.brake = 0.0
	
	# MOVIMENTAÇÃO NORMAL EM ALTA VELOCIDADE
	elif alignment_factor > -0.2:
		var target_engine_force = car.engine_power * curve_smooth_factor * speed_modifier
		car.engine_force = move_toward(car.engine_force, target_engine_force, car.engine_power * delta)
		
		if current_speed > 12.0 and alignment_factor < 0.6:
			var brake_intensity = (1.0 - alignment_factor) * car.brake_force
			car.brake = move_toward(car.brake, brake_intensity, 50.0 * delta)
		else:
			car.brake = move_toward(car.brake, 0.0, 100.0 * delta)
	
	# CURVA EXTREMA EM ALTA VELOCIDADE
	else:
		car.engine_force = 0.0
		car.brake = move_toward(car.brake, 40.0, 120.0 * delta)

func update_gate_target(gate: int) -> void:
	current_gate = gate
	set_next_gate_target()

func set_next_gate_target() -> void:
	if GameManager.race.track.circuit_gates.is_empty(): return
	var target_node = GameManager.race.track.circuit_gates[current_gate]
	navigation_agent.target_position = target_node.global_position

func on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	dynamic_safe_velocity = safe_velocity
