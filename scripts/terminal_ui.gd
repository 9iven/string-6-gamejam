extends CanvasLayer

@onready var status_label: Label = %StatusLabel
@onready var input_field: LineEdit = %InputField
@onready var negative_player = $"../AudioNodes/NegativePlayer"

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
	
	# Mengembalikan kontrol kamera kepada pemain
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_terminal()
		
		# Ini mencegah Pause Menu ikut terbuka secara tidak sengaja saat kita menutup Terminal.
		get_viewport().set_input_as_handled()

func _on_password_submitted(new_text: String) -> void:
	if not target_door: return
		
	var input_sandi := new_text.to_upper()
	var required_password: String = target_door.get_meta("password")
	
	if input_sandi == required_password:
		print("VICTORY: Escape Route Opened!")
		
		target_door.queue_free()
		
		close_terminal()
		
		# ending screen transition here later
	else:
		negative_player.play()
		status_label.text = "ACCESS DENIED. INVALID PASSWORD."
		input_field.clear()
