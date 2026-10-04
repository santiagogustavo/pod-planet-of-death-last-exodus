extends TextureRect
class_name PlayerAvatar

@export var character_image: Texture2D

@onready var avatar_rect: TextureRect = $Mask/Avatar

func _process(_delta: float) -> void:
	if character_image:
		avatar_rect.texture = character_image
