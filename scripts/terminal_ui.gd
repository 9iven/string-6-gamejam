extends CanvasLayer

# Injeksi Static Typing untuk efisiensi alokasi memori
@onready var status_label: Label = %StatusLabel
@onready var input_field: LineEdit = %InputField

var target_door: Node3D = null

func _ready() -> void:
	hide()
	input_field.text_submitted.connect(_on_password_submitted)

func open_terminal(door: Node3D) -> void:
	target_door = door
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true 
	
	status_label.text = "MASUKKAN SANDI ZONA:"
	input_field.clear()
	input_field.grab_focus()

func close_terminal() -> void:
	hide()
	target_door = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	# Evaluasi singkat (Short-circuit evaluation)
	if visible and event.is_action_pressed("ui_cancel"):
		close_terminal()

func _on_password_submitted(new_text: String) -> void:
	if not target_door: return
		
	var input_sandi := new_text.to_upper()
	var required_password: String = target_door.get_meta("password")
	
	if input_sandi == required_password:
		close_terminal()
		print("KEMENANGAN: Rute Pelarian Terbuka!")
		target_door.queue_free()
		# Implementasi sistem transisi layar akhir dapat ditempatkan di sini
	else:
		status_label.text = "AKSES DITOLAK. SANDI TIDAK VALID."
		input_field.clear()
