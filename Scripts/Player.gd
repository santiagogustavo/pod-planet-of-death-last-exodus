extends Node3D
class_name Player

@export var car_data: CarData
@export var player_details: PlayerDetails

@onready var gizmo: Node3D = $Gizmo
@onready var chase_camera_prefab: PackedScene = load("res://Prefabs/Player/ChaseCamera.tscn")
@onready var hud_prefab: PackedScene = load("res://Prefabs/Player/PlayerHUD.tscn")

func _ready() -> void:
	if !car_data:
		return
	gizmo.queue_free()
	var car_instance: Car = load(car_data.scene_path).instantiate()
	add_child(car_instance)
	var chase_camera_instance: ChaseCamera = chase_camera_prefab.instantiate()
	chase_camera_instance.car = car_instance
	car_instance.add_child(chase_camera_instance)
	var hud_instance: PlayerHUD = hud_prefab.instantiate()
	hud_instance.car = car_instance
	hud_instance.player_details = player_details
	add_child(hud_instance)
