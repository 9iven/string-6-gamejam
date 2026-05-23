extends Node

signal sanity_changed(new_sanity: float)
# Indikator status untuk memblokir pergerakan dan interaksi lain
var is_in_dialogue: bool = false

var max_sanity: float = 100.0
var sanity_level: float = 100.0

var max_stamina: float = 100.0
var stamina_level: float = 100.0
var is_sprinting: bool = false # Variabel penanda status lari
var is_exhausted: bool = false # Variabel penanda status capek

var current_level: int = 1
var final_password: String = ""
var current_room_char: String = ""
var dialogue_box_ref: Panel = null

var solved_doors: int = 0
var monster_spawned: bool = false

# ==========================================
# (SETTINGS)
# ==========================================
var mouse_sensitivity: float = 0.003
var master_volume: float = 1.0:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		# Mengubah volume fisis pada AudioServer Godot
		var bus_idx := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))

func _process(delta: float) -> void:
	# 1. Pemulihan Sanity secara konstan
	if sanity_level < max_sanity:
		sanity_level = move_toward(sanity_level, max_sanity, 2.0 * delta) 
		sanity_changed.emit(sanity_level)
		
	# 2. Pemulihan Stamina
	if not is_sprinting and stamina_level < max_stamina:
		# Stamina pulih
		stamina_level = move_toward(stamina_level, max_stamina, 15.0 * delta) 
		
		# PENCABUTAN STATUS: Jika stamina sudah penuh 100%, pemain bisa lari lagi
		if stamina_level >= max_stamina:
			is_exhausted = false
			
			
