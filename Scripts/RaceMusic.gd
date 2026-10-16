extends AudioStreamPlayer2D
class_name RaceMusic

func _ready() -> void:
	GameManager.race.started.connect(func ():
		play()
	)
