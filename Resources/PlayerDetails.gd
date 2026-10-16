extends Resource
class_name PlayerDetails

enum PlayerType {
	Player1,
	Bot
}

@export var player_type: PlayerType
@export var player_name: String
@export var player_avatar: Texture2D
@export var car_data: CarData
