extends Node3D

# ==========================================
# REFERENSI NODE & SCENE
# ==========================================
@onready var camera: Camera3D = $Camera3D
@onready var main_panel: Control = %MainPanel

# Referensi ke kapsul scene SettingsMenu yang baru saja Anda masukkan
@onready var settings_menu: Control = $UILayer/SettingsMenu

@onready var btn_play: Button = %BtnPlay
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit

var _time_passed: float = 0.0

# ==========================================
# INISIALISASI
# ==========================================
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Pengikatan Sinyal Navigasi Utama
	btn_play.pressed.connect(_on_play_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	# Menghubungkan sinyal kustom dari modul SettingsMenu
	settings_menu.back_requested.connect(_on_settings_closed)
	
	_show_panel("main")
	
	# Mengeksekusi pengikatan sinyal audio HANYA untuk tombol di main_panel
	_connect_button_sounds(main_panel)
	get_viewport().gui_release_focus()

# ==========================================
# EFEK VISUAL
# ==========================================
func _process(delta: float) -> void:
	_time_passed += delta
	if camera:
		camera.rotation_degrees.y = sin(_time_passed * 0.9) * 2.0
		camera.rotation_degrees.x = cos(_time_passed * 0.7) * 1.5

# ==========================================
# NAVIGASI ANTARMUKA (ROUTING)
# ==========================================
func _show_panel(panel_name: String) -> void:
	main_panel.visible = (panel_name == "main")
	settings_menu.visible = (panel_name == "settings")

func _on_play_pressed() -> void:
	Global.sanity_level = Global.max_sanity
	Global.stamina_level = Global.max_stamina
	Global.solved_doors = 0
	Global.monster_spawned = false
	get_tree().change_scene_to_file("res://scenes/levels/MainLevel.tscn")

func _on_settings_pressed() -> void:
	_show_panel("settings")

func _on_settings_closed() -> void:
	_show_panel("main")

func _on_quit_pressed() -> void:
	get_tree().quit()

# ==========================================
# SISTEM AUDIO DINAMIS
# ==========================================
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
	if GlobalAudio.has_method("play_click"): GlobalAudio.play_click()
