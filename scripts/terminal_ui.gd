extends CanvasLayer

# === REFERENSI NODE (Menggunakan Unique Name) ===
@onready var status_label = %StatusLabel
@onready var input_field = %InputField

# Memori untuk menyimpan pintu mana yang sedang diretas
var target_door: Node3D = null

func _ready() -> void:
	# Menyembunyikan UI saat permainan dimulai
	hide()
	
	# Menghubungkan sinyal saat pemain menekan 'Enter' pada kotak teks
	input_field.text_submitted.connect(_on_password_submitted)

# ==========================================
# FUNGSI KENDALI UI
# ==========================================
func open_terminal(door: Node3D) -> void:
	target_door = door
	show()
	
	# Melepaskan kursor mouse agar pemain dapat mengklik UI
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Menjeda permainan agar monster atau timer berhenti saat meretas
	get_tree().paused = true 
	
	# Menyiapkan kotak teks
	status_label.text = "MASUKKAN SANDI ZONA:"
	input_field.clear()
	input_field.grab_focus() # Kursor otomatis berkedip di kotak teks

func close_terminal() -> void:
	hide()
	target_door = null
	
	# Mengunci kembali kursor mouse untuk pergerakan karakter
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Melanjutkan permainan
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	# Mengizinkan pemain membatalkan peretasan dengan menekan tombol ESC
	if visible and event.is_action_pressed("ui_cancel"):
		close_terminal()

# ==========================================
# FUNGSI VALIDASI SANDI
# ==========================================
func _on_password_submitted(new_text: String) -> void:
	if target_door == null: return
		
	var input_sandi = new_text.to_upper()
	
	# Mengambil sandi dari metadata yang ditanamkan oleh Level Manager
	var required_password = target_door.get_meta("password")
	
	if input_sandi == required_password:
		close_terminal()
		print("KEMENANGAN: Rute Pelarian Terbuka!")
		target_door.queue_free()
		# TODO: Picu transisi layar akhir (Game Over / Win Screen)
	else:
		status_label.text = "AKSES DITOLAK. SANDI TIDAK VALID."
		input_field.clear()
