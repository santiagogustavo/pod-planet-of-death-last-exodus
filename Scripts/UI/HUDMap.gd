extends TextureRect
class_name HUDMap

@onready var viewport_container: Viewport = $CRT/MapViewport
@onready var camera_pivot: Node3D = $CRT/MapViewport/CameraPivot
@onready var player_indicator: PlayerIndicator = $CRT/MapViewport/PlayerIndicator
@onready var enemy_indicator_prefab: PackedScene = load("res://Prefabs/UI/EnemyIndicator.tscn")

func _ready() -> void:
	GameManager.race.player_added.connect(handle_player_added)

func _process(delta: float) -> void:
	camera_pivot.global_position = player_indicator.global_position
	var rotation_lerp_delta: float = delta * 5.0
	camera_pivot.global_rotation = Vector3(
		lerp_angle(camera_pivot.global_rotation.x, player_indicator.global_rotation.x, rotation_lerp_delta),
		lerp_angle(camera_pivot.global_rotation.y, player_indicator.global_rotation.y, rotation_lerp_delta),
		lerp_angle(camera_pivot.global_rotation.z, player_indicator.global_rotation.z, rotation_lerp_delta)
	)

func handle_player_added(added_player: Player) -> void:
	if added_player.player_details.player_type == PlayerDetails.PlayerType.Player1:
		player_indicator.player_index = GameManager.race.players.find(added_player)
	else:
		var enemy_indicator: PlayerIndicator = enemy_indicator_prefab.instantiate()
		enemy_indicator.player_index = GameManager.race.players.find(added_player)
		viewport_container.add_child(enemy_indicator)
