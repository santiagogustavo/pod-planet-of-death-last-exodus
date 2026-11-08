extends OptionsTab
class_name PlayerTab

@onready var name_line_edit: LineEdit = $VBoxContainer/NameLineEdit/LineEdit
@onready var avatar_slider: HSlider = $VBoxContainer/AvatarSlider/HSlider
@onready var avatar_rect: TextureRect = $VBoxContainer/AvatarSlider/TextureRect

func _ready() -> void:
	bind_name_line_edit()
	bind_avatar_slider()

func _process(_delta: float) -> void:
	avatar_slider.value = PlayerProfileManager.avatar_index
	avatar_rect.texture = load(Avatars.PATHS[PlayerProfileManager.avatar_index])

func bind_name_line_edit() -> void:
	PlayerProfileManager.loaded.connect(func ():
		name_line_edit.text = PlayerProfileManager.player_name
	)
	name_line_edit.text = PlayerProfileManager.player_name
	name_line_edit.text_changed.connect(func (text: String):
		PlayerProfileManager.player_name = text
	)

func bind_avatar_slider() -> void:
	avatar_slider.value_changed.connect(func (value: int):
		PlayerProfileManager.avatar_index = value
	)
