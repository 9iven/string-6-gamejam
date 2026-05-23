extends Panel

@onready var speaker_name = $SpeakerName
@onready var dialogue_text = $DialogueText

var dialogue_data: Array[DialogueLine] = []
var current_line_index: int = 0
var is_typing: bool = false

func _ready() -> void:
	Global.dialogue_box_ref = self
	hide()

func load_dialogue(data: DialogueData) -> void:
	if data != null and data.lines.size() > 0:
		dialogue_data = data.lines
		current_line_index = 0
		
		# Mengunci status global
		Global.is_in_dialogue = true
		show()
		display_line()
	else:
		print("Galat: Objek DialogueData kosong!")

func display_line() -> void:
	if current_line_index < dialogue_data.size():
		is_typing = true
		var current_line: DialogueLine = dialogue_data[current_line_index]
		
		speaker_name.text = current_line.speaker_name
		var raw_text = current_line.text
		
		dialogue_text.text = apply_sanity_filter(raw_text)
		dialogue_text.visible_characters = 0
	else:
		# Jika indeks melebihi batas, eksekusi pembersihan
		close_dialogue()

func close_dialogue() -> void:
	hide()
	Global.is_in_dialogue = false
	
	# Membersihkan residu string agar tidak terjadi bug kotak kosong
	speaker_name.text = ""
	dialogue_text.text = ""
	is_typing = false

func _process(delta: float) -> void:
	if is_typing:
		dialogue_text.visible_characters += 1
		if dialogue_text.visible_characters >= dialogue_text.get_total_character_count():
			is_typing = false

func _input(event: InputEvent) -> void:
	# Guard clause: Abaikan input jika kotak dialog sedang tertutup
	if not visible: 
		return 

	# Menangani terminasi paksa (Tombol ESC)
	if event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled() # Memblokir sinyal agar tidak membuka Pause Menu
		
	elif event.is_action_pressed("interact"):
		if is_typing:
			# Melompat ke akhir teks
			dialogue_text.visible_characters = -1
			is_typing = false
		else:
			# Lanjut ke baris berikutnya
			current_line_index += 1
			display_line()

func apply_sanity_filter(text: String) -> String:
	var sanity_percentage = Global.sanity_level / Global.max_sanity
	if sanity_percentage <= 0.5:
		var intensity = int((1.0 - sanity_percentage) * 100)
		return "[shake rate=20.0 level=" + str(intensity) + " connected=1]" + text + "[/shake]"
	return text
