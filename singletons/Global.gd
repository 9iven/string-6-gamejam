extends Node

signal sanity_changed(new_sanity: float)

var max_sanity: float = 100.0
var sanity_level: float = 100.0

var max_stamina: float = 100.0
var stamina_level: float = 100.0
var is_sprinting: bool = false # Variabel penanda status lari

var current_level: int = 1
var final_password: String = ""
var current_room_char: String = ""
var dialogue_box_ref: Panel = null

var solved_doors: int = 0
var monster_spawned: bool = false

func _process(delta: float) -> void:
	# 1. Pemulihan Sanity secara konstan
	if sanity_level < max_sanity:
		sanity_level = move_toward(sanity_level, max_sanity, 2.0 * delta) # Pulih 2 poin per detik
		sanity_changed.emit(sanity_level)
		
	# 2. Pemulihan Stamina (hanya beroperasi jika karakter tidak sedang lari)
	if not is_sprinting and stamina_level < max_stamina:
		stamina_level = move_toward(stamina_level, max_stamina, 15.0 * delta) # Pulih 15 poin per detik
