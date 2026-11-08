extends Node

enum Metric {
	KMH,
	MPH
}

var metric: Metric = Metric.KMH

func set_metric(value: Metric) -> void:
	metric = value
