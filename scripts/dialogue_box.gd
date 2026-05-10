extends Panel

@onready var speaker_name = $SpeakerName
@onready var dialogue_text = $DialogueText

var dialogue_data: Array = []
var current_line_index: int = 0
var is_typing: bool = false

func _ready() -> void:
	# Mendaftarkan instance ini ke variabel global
	Global.dialogue_box_ref = self

	# Menyembunyikan kotak dialog pada saat inisialisasi awal
	hide()

func load_dialogue(file_path: String) -> void:
	# Membuka file untuk dibaca
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var file_content = file.get_as_text()
		var json = JSON.new()
		var parse_error = json.parse(file_content)
		
		if parse_error == OK:
			dialogue_data = json.data
			current_line_index = 0
			show()
			display_line()
		else:
			print("Galat pembacaan JSON pada baris: ", json.get_error_line())

func display_line() -> void:
	if current_line_index < dialogue_data.size():
		is_typing = true
		var line_data = dialogue_data[current_line_index]
		
		speaker_name.text = line_data["speaker"]
		var raw_text = line_data["text"]
		
		# Menerapkan filter kewarasan sebelum teks ditampilkan
		dialogue_text.text = apply_sanity_filter(raw_text)
		
		# Mengatur teks agar tidak terlihat untuk memulai efek mesin tik
		dialogue_text.visible_characters = 0
	else:
		# Menutup kotak dialog jika indeks melebihi jumlah percakapan
		hide()

func _process(delta: float) -> void:
	if is_typing:
		dialogue_text.visible_characters += 1
		if dialogue_text.visible_characters >= dialogue_text.get_total_character_count():
			is_typing = false

func _input(event: InputEvent) -> void:
	# Memastikan interaksi hanya diproses jika kotak dialog sedang aktif
	if event.is_action_pressed("interact") and visible:
		if is_typing:
			# Menghentikan efek mesin tik dan menampilkan teks secara instan
			dialogue_text.visible_characters = -1
			is_typing = false
		else:
			# Melanjutkan ke baris dialog selanjutnya
			current_line_index += 1
			display_line()

func apply_sanity_filter(text: String) -> String:
	# Mengambil data kewarasan dari Singleton Global
	var sanity_percentage = Global.sanity_level / Global.max_sanity
	
	# Jika kewarasan berada di bawah 50%, modifikasi string dengan format BBCode
	if sanity_percentage <= 0.5:
		var intensity = int((1.0 - sanity_percentage) * 100)
		return "[shake rate=20.0 level=" + str(intensity) + " connected=1]" + text + "[/shake]"
	
	return text
