extends Area3D
class_name NearMissDetector

@export var near_miss_threshold: float = 0.5

@onready var sfx: AudioStreamPlayer3D = $SFX
@onready var raycast: RayCast3D = $RayCast3D

var is_passing_by: bool = false
var timer: SceneTreeTimer

func _ready() -> void:
	body_entered.connect(handle_body_entered)
	body_exited.connect(handle_body_exited)

func handle_body_entered(_body: Node3D) -> void:
	is_passing_by = true
	timer = get_tree().create_timer(near_miss_threshold)
	timer.timeout.connect(func ():
		is_passing_by = false
	)

func handle_body_exited(body: Node3D) -> void:
	if !is_passing_by:
		return
	raycast.look_at(body.global_position)
	sfx.global_position = raycast.to_global(raycast.target_position)
	sfx.play()
