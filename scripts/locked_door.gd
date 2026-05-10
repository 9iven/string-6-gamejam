extends StaticBody3D

var required_password: String = ""
var is_unlocked: bool = false

# Fungsi ini dipanggil oleh LevelManager saat ruangan dibangun
func set_password(pwd: String) -> void:
	required_password = pwd
	print("Sistem Debug: Pintu dikonfigurasi dengan sandi -> ", required_password)

# Fungsi ini dipanggil saat pemain menembakkan RayCast (berinteraksi)
func hack_wall() -> void:
	if is_unlocked: return
	
	print("Sistem: Pintu ini terkunci. Memerlukan sandi untuk membuka.")
	
	# TODO: Di sinilah Anda nantinya memanggil UI/Terminal Text Box.
	# Contoh: Global.show_terminal_ui(self)
	
	# --- BLOK DEBUG SEMENTARA ---
	# Untuk sementara, saat Anda berinteraksi, pintu akan langsung menguji dirinya sendiri
	# agar Anda dapat melanjutkan permainan tanpa UI text box.
	submit_password(required_password) 

# Fungsi ini nantinya akan dipanggil oleh UI Text Box ketika pemain menekan 'Enter'
func submit_password(input_string: String) -> void:
	if input_string == required_password:
		_unlock_door()
	else:
		print("Sistem: Akses Ditolak. Sandi tidak valid.")
		# Opsional: Tambahkan pengurangan Sanity jika salah memasukkan sandi

func _unlock_door() -> void:
	is_unlocked = true
	Global.solved_doors += 1
	print("Sistem: Sandi Diterima. Lorong Terbuka. Total pintu: ", Global.solved_doors)
	
	# Terdapat 2 pintu terkunci dalam 15 ruangan. Jika keduanya telah dibuka,
	# artinya pemain telah memasuki zona terakhir, picu manifestasi musuh.
	if Global.solved_doors >= 2 and not Global.monster_spawned:
		_spawn_monster()
		
	queue_free()

func _spawn_monster() -> void:
	Global.monster_spawned = true
	var level_manager = get_tree().root.find_child("NavigationRegion3D", true, false)
	
	if level_manager and level_manager.monster_prefab != null:
		var monster = level_manager.monster_prefab.instantiate()
		var random_spawn_point = level_manager.valid_room_positions.pick_random()
		random_spawn_point.y = 2.0 
		monster.global_position = random_spawn_point
		level_manager.add_child(monster)
		print("Peringatan Kritis: Entitas musuh telah bermanifestasi di dalam labirin!")
