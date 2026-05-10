extends Area3D

@export var dialogue_file_path: String = "res://resources/dialogues/level_1.json"
var has_triggered: bool = false

func _on_body_entered(body: Node3D) -> void:
	# Memeriksa apakah yang masuk adalah pemain dan pemicu belum pernah diaktifkan
	if body.name == "Player" and not has_triggered:
		
		# Validasi apakah UI sudah terdaftar di sistem Global
		if Global.dialogue_box_ref != null:
			has_triggered = true
			Global.dialogue_box_ref.load_dialogue(dialogue_file_path)
			print("Sistem [Trigger]: Dialog berhasil dieksekusi.")
		else:
			print("Galat [Trigger]: dialogue_box_ref bernilai null. UI belum dimuat!")
