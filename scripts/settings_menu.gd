extends Control

# Deklarasi sinyal khusus untuk berkomunikasi dengan menu induk
signal back_requested

# ==========================================
# REFERENSI NODE
# ==========================================
@onready var slider_volume: HSlider = %SliderVolume
@onready var slider_sens: HSlider = %SliderSens
@onready var action_list: VBoxContainer = %ActionList
@onready var listening_overlay: Panel = %ListeningOverlay
@onready var btn_back: Button = %BtnBack
@onready var btn_reset: Button = %BtnReset

# ==========================================
# VARIABEL STATE & KONFIGURASI
# ==========================================
var keybind_dict: Dictionary = {
	"move_up": "Forward",
	"move_down": "Backward",
	"move_left": "Left",
	"move_right": "Right",
	"sprint": "Run",
	"interact": "Interact",
	"ui_accept": "Vision",
	"ui_cancel": "Exit/Back"
}

var is_listening: bool = false
var current_action_to_rebind: String = ""
var current_button_to_update: Button = null

# ==========================================
# INISIALISASI
# ==========================================
func _ready() -> void:
	# Sinkronisasi nilai UI dengan Global State
	slider_volume.value = Global.master_volume
	slider_sens.value = Global.mouse_sensitivity
	
	# Pengikatan sinyal UI
	slider_volume.value_changed.connect(_on_volume_changed)
	slider_sens.value_changed.connect(_on_sensitivity_changed)
	btn_back.pressed.connect(_on_back_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)
	
	listening_overlay.hide() # Tambahkan ini agar tidak ada sisa overlay yang tertinggal
	
	_connect_button_sounds(self)
	_generate_action_list()

func _process(_delta: float) -> void:
	# Jika menu disembunyikan, hentikan semua proses input/listening
	if not visible and is_listening:
		_cancel_rebind()

# ==========================================
# FUNGSI KELUAR (EXIT)
# ==========================================
func _on_back_pressed() -> void:
	# Memancarkan sinyal ke parent (induk) agar parent yang menutup panel ini
	back_requested.emit()
	if GlobalAudio.has_method("play_click"):
		GlobalAudio.play_click()

# ==========================================
# KONTROL AUDIO & SENSITIVITAS
# ==========================================
func _on_volume_changed(value: float) -> void:
	Global.master_volume = value

func _on_sensitivity_changed(value: float) -> void:
	Global.mouse_sensitivity = value

func _connect_button_sounds(parent_node: Node) -> void:
	for child in parent_node.get_children():
		if child is BaseButton:
			child.mouse_entered.connect(_on_button_hovered)
			child.focus_entered.connect(_on_button_hovered)
			child.pressed.connect(_on_button_pressed)
		
		if child.get_child_count() > 0:
			_connect_button_sounds(child)

func _on_button_hovered() -> void:
	if GlobalAudio.has_method("play_hover"): GlobalAudio.play_hover()

func _on_button_pressed() -> void:
	# Jangan mainkan suara klik di sini jika tombol sudah memiliki suara khusus,
	# tapi untuk amannya kita panggil suara klik global.
	if GlobalAudio.has_method("play_click"): GlobalAudio.play_click()

# ==========================================
# SISTEM KEYBINDING DINAMIS
# ==========================================
func _generate_action_list() -> void:
	for child in action_list.get_children():
		child.queue_free()
		
	for action_name in keybind_dict.keys():
		var row := HBoxContainer.new()
		
		var label := Label.new()
		label.text = keybind_dict[action_name]
		label.custom_minimum_size = Vector2(150, 0) 
		
		var button := Button.new()
		button.text = _get_current_key_name(action_name)
		button.custom_minimum_size = Vector2(150, 0)
		
		button.mouse_entered.connect(_on_button_hovered)
		button.pressed.connect(_on_rebind_button_pressed.bind(button, action_name))
		
		row.add_child(label)
		row.add_child(button)
		action_list.add_child(row)

func _get_current_key_name(action_name: String) -> String:
	var events = InputMap.action_get_events(action_name)
	if events.size() > 0:
		return events[0].as_text().trim_suffix(" (Physical)")
	return "Unassigned"

func _on_rebind_button_pressed(button: Button, action_name: String) -> void:
	is_listening = true
	current_action_to_rebind = action_name
	current_button_to_update = button
	
	listening_overlay.show()
	listening_overlay.grab_focus()

func _input(event: InputEvent) -> void:
	# Guard Clause: Jangan tangkap input jika panel pengaturan sedang disembunyikan
	if not visible:
		return

	# Mode Mendengarkan Input Baru
	if is_listening:
		if event is InputEventKey or event is InputEventMouseButton:
			if event.is_pressed():
				# Pengecualian ESCAPE
				if event is InputEventKey and event.keycode == KEY_ESCAPE:
					if current_action_to_rebind != "ui_cancel":
						_cancel_rebind()
						return
						
				_assign_new_key(event)
				get_viewport().set_input_as_handled()
		return

	# Navigasi Antarmuka: Tombol "ui_cancel" memicu sinyal kembali
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _assign_new_key(event: InputEvent) -> void:
	InputMap.action_erase_events(current_action_to_rebind)
	InputMap.action_add_event(current_action_to_rebind, event)
	
	current_button_to_update.text = event.as_text().trim_suffix(" (Physical)")
	_cancel_rebind()

func _cancel_rebind() -> void:
	is_listening = false
	current_action_to_rebind = ""
	current_button_to_update = null
	listening_overlay.hide()

func _on_reset_pressed() -> void:
	InputMap.load_from_project_settings()
	_generate_action_list()
