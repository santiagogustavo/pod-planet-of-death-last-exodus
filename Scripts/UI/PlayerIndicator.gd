extends MeshInstance3D
class_name PlayerIndicator

@export var player_index: int = -1
@onready var big_indicator: MeshInstance3D = $BigIndicator

func _ready() -> void:
	big_indicator.visible = true

func _process(_delta: float) -> void:
	if player_index == -1 or !GameManager.race:
		return
	var player: Player = GameManager.race.players[player_index]
	var car_instance = player.car_instance
	global_position = Vector3(
		car_instance.global_position.x,
		car_instance.global_position.y,
		car_instance.global_position.z,
	)
	global_rotation = Vector3(0.0, car_instance.global_rotation.y, 0.0)
