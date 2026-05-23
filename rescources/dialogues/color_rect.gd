extends ColorRect

func _ready() -> void:
	# Menghubungkan signal dari Global ke fungsi pembaruan shader
	Global.sanity_changed.connect(_on_sanity_changed)

func _on_sanity_changed(new_sanity: float) -> void:
	# Menghitung intensitas distorsi (semakin kecil sanity, semakin besar distorsi)
	var intensity = 1.0 - (new_sanity / Global.max_sanity)
	
	# Mengirim nilai ke dalam shader
	material.set_shader_parameter("distortion_intensity", intensity)
