extends StaticBody3D

func hack_wall() -> void:
	# 1. Menambahkan metrik retasan pada state global
	Global.solved_doors += 1
	print("Sistem: Dinding diretas. Total gerbang terbuka: ", Global.solved_doors)
	
	# 2. Evaluasi pemicu entitas musuh
	if Global.solved_doors >= 5 and not Global.monster_spawned:
		_spawn_monster()
		
	# 3. Menghancurkan entitas fisik ini untuk membuka lorong
	queue_free()

func _spawn_monster() -> void:
	Global.monster_spawned = true
	
	# Mencari referensi arsitektur navigasi utama
	var level_manager = get_tree().root.find_child("NavigationRegion3D", true, false)
	
	if level_manager and level_manager.monster_prefab != null:
		var monster = level_manager.monster_prefab.instantiate()
		
		# Pendaratan entitas pada salah satu sel matriks ruangan yang valid
		var random_spawn_point = level_manager.valid_room_positions.pick_random()
		
		# Sumbu Y disesuaikan agar musuh tidak jatuh menembus lantai saat instantiate
		random_spawn_point.y = 2.0 
		monster.global_position = random_spawn_point
		
		level_manager.add_child(monster)
		print("Peringatan Kritis: Entitas bermanifestasi di dalam labirin.")
	else:
		print("Galat Sistem: monster_prefab tidak ditemukan pada LevelManager.")
