extends Node3D

# ==========================================
# REFERENSI NODE & SCENE
# ==========================================
@onready var camera: Camera3D = $Camera3D
@onready var main_panel: Control = %MainPanel
@onready var settings_panel: Control = %SettingsPanel

@onready var btn_play: Button = %BtnPlay
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit
@onready var btn_back: Button = %BtnBack

@onready var slider_volume: HSlider = %SliderVolume
@onready var slider_sens: HSlider = %SliderSens

var _time_passed: float = 0.0

# ==========================================
# INISIALISASI
# ==========================================
func _ready() -> void:
	# Memastikan mouse bebas bergerak saat di menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Menghubungkan sinyal antarmuka fungsional
	btn_play.pressed.connect(_on_play_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	
	slider_volume.value_changed.connect(_on_volume_changed)
	slider_sens.value_changed.connect(_on_sensitivity_changed)
	
	# Sinkronisasi nilai UI dengan Global State
	slider_volume.value = Global.master_volume
	slider_sens.value = Global.mouse_sensitivity
	
	_show_panel("main")
	
	# Eksekusi pengikatan sinyal audio untuk seluruh tombol
	_connect_button_sounds(self)
	
	# Mencabut paksa fokus untuk mencegah suara hover terpicu saat boot
	get_viewport().gui_release_focus()

# ==========================================
# EFEK VISUAL (CAMERA SWAY)
# ==========================================
func _process(delta: float) -> void:
	_time_passed += delta
	# Kalkulasi sinus & kosinus untuk menciptakan ayunan kamera yang tidak stabil
	if camera:
		camera.rotation_degrees.y = sin(_time_passed * 0.5) * 2.0
		camera.rotation_degrees.x = cos(_time_passed * 0.3) * 1.5

# ==========================================
# MANAJEMEN ANTARMUKA (STATE ROUTING)
# ==========================================
func _show_panel(panel_name: String) -> void:
	main_panel.visible = (panel_name == "main")
	settings_panel.visible = (panel_name == "settings")

func _on_play_pressed() -> void:
	# Reset status global sebelum masuk ke labirin 
	Global.sanity_level = Global.max_sanity
	Global.stamina_level = Global.max_stamina
	Global.solved_doors = 0
	Global.monster_spawned = false
	
	# Transisi berbasis string untuk mencegah Circular Dependency
	# Pastikan rute ini sesuai dengan lokasi aktual scene level Anda
	get_tree().change_scene_to_file("res://scenes/levels/MainLevel.tscn")

func _on_settings_pressed() -> void:
	_show_panel("settings")

func _on_back_pressed() -> void:
	_show_panel("main")

func _on_quit_pressed() -> void:
	get_tree().quit()

# ==========================================
# MUTATOR PENGATURAN (SETTINGS CONTROLLER)
# ==========================================
func _on_volume_changed(value: float) -> void:
	Global.master_volume = value

func _on_sensitivity_changed(value: float) -> void:
	Global.mouse_sensitivity = value

# ==========================================
# SISTEM AUDIO DINAMIS (REKURSIF)
# ==========================================
func _connect_button_sounds(parent_node: Node) -> void:
	# Memindai seluruh tree UI untuk mencari komponen interaktif
	for child in parent_node.get_children():
		if child is BaseButton:
			child.mouse_entered.connect(_on_button_hovered)
			child.focus_entered.connect(_on_button_hovered)
			child.pressed.connect(_on_button_pressed)
		
		# Memasuki container hierarki lebih dalam secara algoritmik
		if child.get_child_count() > 0:
			_connect_button_sounds(child)

func _on_button_hovered() -> void:
	GlobalAudio.play_hover()

func _on_button_pressed() -> void:
	GlobalAudio.play_click()
