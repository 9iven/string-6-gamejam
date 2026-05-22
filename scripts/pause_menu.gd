extends CanvasLayer

# Residu variabel main_menu_scene dan node audio lokal telah dibersihkan

@onready var main_panel: Control = %MainPausePanel
@onready var settings_panel: Control = %SettingsPanel

@onready var btn_resume: Button = %BtnResume
@onready var btn_restart: Button = %BtnRestart
@onready var btn_settings: Button = %BtnSettings
@onready var btn_menu: Button = %BtnMainMenu
@onready var btn_back: Button = %BtnBack

@onready var slider_volume: HSlider = %SliderVolume
@onready var slider_sens: HSlider = %SliderSens

func _ready() -> void:
	hide()
	
	# Pengikatan sinyal fungsionalitas UI
	btn_resume.pressed.connect(_on_resume)
	btn_restart.pressed.connect(_on_restart)
	btn_settings.pressed.connect(_on_settings)
	btn_menu.pressed.connect(_on_main_menu)
	btn_back.pressed.connect(_on_back)

	slider_volume.value_changed.connect(_on_volume_changed)
	slider_sens.value_changed.connect(_on_sensitivity_changed)
	
	# PANGGILAN KRITIS: Mengeksekusi pengikatan sinyal audio untuk seluruh tombol
	_connect_button_sounds(self)

# ==========================================
# MANAJEMEN STATE JEDA
# ==========================================
func toggle_pause() -> void:
	var is_paused := not get_tree().paused
	get_tree().paused = is_paused
	visible = is_paused

	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show_panel("main")
		
		slider_volume.value = Global.master_volume
		slider_sens.value = Global.mouse_sensitivity
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_panel(panel_name: String) -> void:
	main_panel.visible = (panel_name == "main")
	settings_panel.visible = (panel_name == "settings")

# ==========================================
# ROUTING ANTARMUKA
# ==========================================
func _on_resume() -> void:
	toggle_pause()

func _on_restart() -> void:
	get_tree().paused = false
	
	Global.sanity_level = Global.max_sanity
	Global.stamina_level = Global.max_stamina
	Global.solved_doors = 0
	Global.monster_spawned = false
	
	get_tree().reload_current_scene()

func _on_main_menu() -> void:
	get_tree().paused = false
	# Eksekusi transisi tunggal berbasis string untuk menghindari Circular Dependency
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_settings() -> void:
	_show_panel("settings")

func _on_back() -> void:
	_show_panel("main")

func _on_volume_changed(value: float) -> void:
	Global.master_volume = value

func _on_sensitivity_changed(value: float) -> void:
	Global.mouse_sensitivity = value

# ==========================================
# SISTEM AUDIO DINAMIS (REKURSIF)
# ==========================================
func _connect_button_sounds(parent_node: Node) -> void:
	# Memindai seluruh tree UI untuk mencari tombol
	for child in parent_node.get_children():
		if child is BaseButton:
			# Mengikat deteksi hover/fokus
			child.mouse_entered.connect(_on_button_hovered)
			child.focus_entered.connect(_on_button_hovered)
			# Mengikat deteksi klik (bersamaan dengan fungsi utama tombol)
			child.pressed.connect(_on_button_pressed)
		
		# Jika container memiliki anak, masuk lebih dalam
		if child.get_child_count() > 0:
			_connect_button_sounds(child)
			
func _on_button_hovered() -> void:
	GlobalAudio.play_hover()

func _on_button_pressed() -> void:
	GlobalAudio.play_click()
