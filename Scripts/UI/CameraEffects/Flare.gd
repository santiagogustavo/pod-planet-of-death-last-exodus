extends Control
class_name Flare

@export var effect_enabled: bool = false

@onready var rect: ColorRect = $ColorRect
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var rect_material: Material = rect.material

func _process(_delta: float) -> void:
	visible = (
		GameManager.race and GameManager.race.track.weather == Track.Weather.Sunny
	)
	if !visible:
		return
	animation_tree.set("parameters/conditions/visible", Sun.is_sun_visible)
	animation_tree.set("parameters/conditions/hidden", !Sun.is_sun_visible)
	rect_material.set("shader_parameter/sun_position", Sun.unprojected_sun_direction)
