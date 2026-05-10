extends StaticBody3D

var required_password: String = ""

func set_password(pwd: String) -> void:
	required_password = pwd

# Fungsi ini dipanggil oleh Terminal UI saat pemain menekan Enter
func submit_password(input_string: String) -> bool:
	if input_string == required_password:
		_unlock_door()
		return true # Memberitahu UI bahwa sandi benar
	else:
		return false # Memberitahu UI bahwa sandi salah

func _unlock_door() -> void:
	Global.solved_doors += 1
	
	# Logika kemunculan monster di zona akhir
	if Global.solved_doors >= 2 and not Global.monster_spawned:
		_spawn_monster()
		
	queue_free() # Menghancurkan pintu

func _spawn_monster() -> void:
	Global.monster_spawned = true
	var level_manager = get_tree().root.find_child("NavigationRegion3D", true, false)
	
	if level_manager and level_manager.monster_prefab != null:
		var monster = level_manager.monster_prefab.instantiate()
		var random_spawn_point = level_manager.valid_room_positions.pick_random()
		random_spawn_point.y = 2.0 
		monster.global_position = random_spawn_point
		level_manager.add_child(monster)
