extends Panel
class_name FinalLapPanel

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")

func play_final_lap() -> void:
	playback.travel("Show", true)
