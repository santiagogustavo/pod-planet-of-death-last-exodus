extends OptionsTab
class_name GameplayTab

@onready var metric_option_button: OptionButton = $VBoxContainer/MetricOption/OptionButton

func _ready() -> void:
	bind_metric_option_button()

func _process(_delta: float) -> void:
	metric_option_button.selected = GameplaySettingsManager.metric as int

func bind_metric_option_button() -> void:
	metric_option_button.item_selected.connect(func (index: int):
		GameplaySettingsManager.set_metric(index as GameplaySettingsManager.Metric)
	)
