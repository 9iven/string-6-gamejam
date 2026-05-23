extends StaticBody3D

@export var dialogue_resource: DialogueData

func execute_interaction() -> void:
	# Hanya abaikan input jika pemain SEDANG berada di dalam layar percakapan.
	# Jika dialog sudah tertutup, pemain diizinkan memanggil fungsi ini lagi.
	if Global.is_in_dialogue: 
		return
		
	if dialogue_resource == null:
		print("Galat [NPC]: File Resource Dialog belum dimasukkan ke Inspector!")
		return
		
	if Global.dialogue_box_ref != null:
		# Memuat dan mengirim ulang data dari awal
		Global.dialogue_box_ref.load_dialogue(dialogue_resource)
