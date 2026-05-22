extends Node

@onready var hover_player: AudioStreamPlayer = $HoverPlayer
@onready var click_player: AudioStreamPlayer = $ClickPlayer

func play_hover() -> void:
	hover_player.pitch_scale = randf_range(0.95, 1.05)
	hover_player.play()

func play_click() -> void:
	click_player.play()
