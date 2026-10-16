extends Node
class_name RaceManager

signal countdown
signal started
signal player_added

enum RaceStatus {
	Idle,
	Countdown,
	Started,
	Ended
}

@export var track: Track
@export var laps: int = 3
@export var players: Array[Player] = []
@export var predefined_players: Array[PlayerDetails] = []

@onready var player_prefab: PackedScene = load("res://Prefabs/Player/Player.tscn")
@onready var race_music_prefab: PackedScene = load("res://Prefabs/RaceMusic.tscn")

var status: RaceStatus = RaceStatus.Idle

class PlayerProgress:
	var player_name: String
	var total_distance: float

func _ready() -> void:
	GameManager.race = self
	instantiate_race_music()
	spawn_players_to_gates()

func instantiate_race_music() -> void:
	var race_music_instance: RaceMusic = race_music_prefab.instantiate()
	add_child(race_music_instance)

func spawn_players_to_gates() -> void:
	var gate_index: int = 0
	for player in predefined_players:
		var player_instance: Player = player_prefab.instantiate()
		player_instance.player_details = player
		player_instance.start_gate_index = gate_index
		get_tree().root.add_child.call_deferred(player_instance)
		gate_index += 1

func start_race_countdown() -> void:
	countdown.emit()
	status = RaceStatus.Countdown

func start_race() -> void:
	started.emit()
	status = RaceStatus.Started

func add_player(player: Player) -> void:
	players.append(player)
	player_added.emit(player)

func sort_players_by_distance_to_next_gate() -> Array[String]:
	if players.is_empty():
		return []

	var track_total_distance = GameManager.race.track.get_total_distance()
	var player_progresses: Array[PlayerProgress] = []
	
	for player in players:
		if not player.car_instance:
			continue
			
		var progress := PlayerProgress.new()
		progress.player_name = player.name
		
		var lap_distance = player.compute_total_traveled_distance() 
		
		# Determina quantas voltas inteiras a menos devem ser multiplicadas
		var lap_modifier = 1
		
		# -----------------------------------------------------------------
		# CORREÇÃO PARA O CORREDOR NO FINAL DA VOLTA (GATE 0)
		# -----------------------------------------------------------------
		# Se ele está no Gate 0, a lap_distance calculada por ele é apenas a 
		# reta final. Porém, ele já percorreu toda a pista da volta anterior. 
		# Portanto, tratamos o cálculo de voltas concluídas usando a 'current_lap' cheia.
		# -----------------------------------------------------------------
		if player.current_gate == 0 and player.current_lap > 0:
			lap_modifier = 0
			
		var completed_laps_distance = (player.current_lap - lap_modifier) * track_total_distance
		
		progress.total_distance = completed_laps_distance + lap_distance
		player_progresses.append(progress)
	
	player_progresses.sort_custom(func(a: PlayerProgress, b: PlayerProgress):
		return a.total_distance > b.total_distance
	)
	
	var sorted_players: Array[String] = []
	for p in player_progresses:
		sorted_players.append(p.player_name)
		
	return sorted_players

func get_par_time_between_players(player_a_position: int, player_b_position: int) -> float:
	var sorted_players = sort_players_by_distance_to_next_gate()
	
	var player_a: Player = players[players.find_custom(func (player: Player):
		return player.name == sorted_players[player_a_position - 1]
	)]
	var player_b: Player = players[players.find_custom(func (player: Player):
		return player.name == sorted_players[player_b_position - 1]
	)]
	
	var leader: Player = player_a if player_a_position < player_b_position else player_b
	var follower: Player = player_b if player_a_position < player_b_position else player_a
	
	var track_total_distance = GameManager.race.track.get_total_distance()
	
	# 1. Calcula a distância absoluta contínua de ambos
	var leader_modifier = 1 if not (leader.current_gate == 0 and leader.current_lap > 0) else 0
	var follower_modifier = 1 if not (follower.current_gate == 0 and follower.current_lap > 0) else 0
	
	var leader_total = leader.compute_total_traveled_distance() + ((leader.current_lap - leader_modifier) * track_total_distance)
	var follower_total = follower.compute_total_traveled_distance() + ((follower.current_lap - follower_modifier) * track_total_distance)
	
	var distance_diff = leader_total - follower_total
	
	if distance_diff <= 0:
		return 0.0

	# -----------------------------------------------------------------
	# SOLUÇÃO PARA INVERSÃO DE TEMPOS: VELOCIDADE DE REFERÊNCIA DO SEGUIDOR
	# -----------------------------------------------------------------
	# Usando a velocidade do 'follower' como base, o divisor será o mesmo 
	# quando o 3º colocado olhar para o 2º e para o 1º. 
	# Adicionamos um max(..., 15.0) para que, se o 3º colocado parar, 
	# o tempo continue subindo de forma consistente para todos os líderes.
	# -----------------------------------------------------------------
	var reference_speed = max(follower.car_instance.speed_ms, 15.0)
	
	return distance_diff / reference_speed
