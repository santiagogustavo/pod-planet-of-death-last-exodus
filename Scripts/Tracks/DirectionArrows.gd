extends Node3D
class_name DirectionArrows

@export var scroll_speed: float = 0.1

@onready var csgpolygon: CSGPolygon3D = $CSGPolygon3D

func _process(delta: float) -> void:
	var current_uv_x_offset = csgpolygon.material.get("uv1_offset").x
	var uv_x_offset: float = delta * scroll_speed
	csgpolygon.material.set("uv1_offset", Vector3(current_uv_x_offset - uv_x_offset, 0.0, 0.0))
