extends Node
class_name RaceManager

signal started

@export var track: Track
@export var laps: int = 3
@export var players: Array[Player] = []

func start_race() -> void:
	started.emit()
