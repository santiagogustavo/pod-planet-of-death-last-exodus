extends CanvasLayer
class_name RaceStartCountdown

func start_race() -> void:
	if GameManager.race:
		GameManager.race.start_race()
