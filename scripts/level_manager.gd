extends NavigationRegion3D

# ==========================================
# 1. KONFIGURASI DAN REFERENSI NODE
# ==========================================
@export_group("Prefabs (Cetak Biru)")
@export var room_prefab: PackedScene
@export var open_gate_prefab: PackedScene
@export var locked_door_prefab: PackedScene
@export var monster_prefab: PackedScene
@export var player_node: CharacterBody3D

@export_group("Pengaturan Matriks Labirin")
var dimensions: Vector2i = Vector2i(15, 15) 
var room_size: float = 10.0

# ==========================================
# 2. VARIABEL PENYIMPANAN DATA (MEMORI)
# ==========================================
# Menyimpan status grid (contoh: "0" untuk kosong, "C" untuk rute utama)
var dungeon: Array = []

# Menyimpan koordinat koneksi antarruangan untuk menentukan dinding mana yang harus dihancurkan
var path_connections: Dictionary = {}

# Menyimpan posisi absolut 3D dari setiap ruangan yang berhasil dibangun
var valid_room_positions: Array[Vector3] = []

# ==========================================
# 3. VARIABEL SISTEM ZONA DAN SANDI
# ==========================================
var critical_path: Array[Vector2i] = []
var zone_clues: Dictionary = {} 
var locked_door_mappings: Dictionary = {} 
var char_pool: Array[String] = ["A", "B", "C", "X", "Y", "Z", "7", "9"]


# ==========================================
# FUNGSI UTAMA (ALUR EKSEKUSI)
# ==========================================
func _ready() -> void:
	# Mengacak seed agar labirin selalu berbeda setiap kali dimainkan
	randomize()
	_initialize_dungeon()
	
	# Menentukan titik awal pemain di area bawah matriks
	var start_pos = Vector2i(7, 14)
	
	# LANGKAH 1: Membangun rute utama sepanjang 15 ruangan
	var initial_path: Array[Vector2i] = []
	var is_path_successful = _generate_path(start_pos, 15, initial_path)
	
	if is_path_successful:
		# Menyimpan rute yang berhasil ke dalam memori utama
		critical_path.assign(initial_path)
		
		# LANGKAH 2: Mengunci perbatasan zona dan menyebarkan sandi
		_setup_strict_zones()
		
		# LANGKAH 3: Merakit objek 3D ke dalam dunia fisis
		_build_3d_dungeon()
		
		# LANGKAH 4: Memindahkan pemain ke ruang pertama
		if player_node != null:
			player_node.global_position = Vector3(start_pos.x * room_size, 2.0, start_pos.y * room_size)
	else:
		print("Galat Kritis: Gagal membangun 15 ruangan berurutan. Area terlalu sempit.")


# ==========================================
# FUNGSI MANAJEMEN DATA GRID
# ==========================================
func _initialize_dungeon() -> void:
	# Membersihkan memori sebelum memulai
	dungeon.clear()
	path_connections.clear()
	
	# Mengisi seluruh grid dengan "0" (status kosong)
	for x in dimensions.x:
		dungeon.append([])
		for y in dimensions.y:
			dungeon[x].append("0")

func _add_connection(room_a: Vector2i, room_b: Vector2i) -> void:
	# Mencatat bahwa room_a terhubung ke room_b, dan sebaliknya
	if not path_connections.has(room_a): path_connections[room_a] = []
	if not path_connections.has(room_b): path_connections[room_b] = []
	
	if not path_connections[room_a].has(room_b): path_connections[room_a].append(room_b)
	if not path_connections[room_b].has(room_a): path_connections[room_b].append(room_a)

func _remove_connection(room_a: Vector2i, room_b: Vector2i) -> void:
	# Menghapus catatan koneksi jika rute ternyata menemui jalan buntu (backtracking)
	if path_connections.has(room_a): path_connections[room_a].erase(room_b)
	if path_connections.has(room_b): path_connections[room_b].erase(room_a)


# ==========================================
# FUNGSI PEMBANGkit JALUR PROSEDURAL
# ==========================================
func _generate_path(current: Vector2i, length: int, current_path: Array[Vector2i]) -> bool:
	# Mendaftarkan ruangan saat ini ke dalam rute
	current_path.append(current)
	dungeon[current.x][current.y] = "C" # "C" berarti Critical Path (Jalur Utama)
	
	# Jika panjang target sudah tercapai, hentikan pencarian
	if length == 1:
		return true
		
	# Menentukan arah awal secara acak (Utara, Selatan, Timur, atau Barat)
	var direction = Vector2i(0, -1)
	var rand_dir = randi() % 4
	if rand_dir == 0: direction = Vector2i(0, -1)
	elif rand_dir == 1: direction = Vector2i(1, 0)
	elif rand_dir == 2: direction = Vector2i(0, 1)
	else: direction = Vector2i(-1, 0)
	
	# Mencoba keempat arah menggunakan rotasi 90 derajat
	for i in range(4):
		var next_pos = current + direction
		
		# Memastikan ruangan berikutnya tidak keluar dari batas peta
		if next_pos.x >= 0 and next_pos.x < dimensions.x and next_pos.y >= 0 and next_pos.y < dimensions.y:
			# Memastikan ruangan berikutnya masih kosong
			if str(dungeon[next_pos.x][next_pos.y]) == "0":
				
				_add_connection(current, next_pos)
				
				# Memanggil fungsi ini kembali untuk ruangan berikutnya (Rekursif)
				if _generate_path(next_pos, length - 1, current_path):
					return true # Berhasil!
					
				# Jika gagal (jalan buntu), batalkan koneksi dan coba arah lain
				_remove_connection(current, next_pos)
				
		# Memutar arah 90 derajat untuk pengecekan berikutnya
		direction = Vector2i(-direction.y, direction.x)
		
	# Jika keempat arah gagal, hapus ruangan ini dan mundur satu langkah
	dungeon[current.x][current.y] = "0"
	current_path.pop_back()
	return false


# ==========================================
# FUNGSI LOGIKA ZONA DAN SANDI
# ==========================================
func _setup_strict_zones() -> void:
	# Zona 1: Ruangan indeks 0 hingga 4. Pintu dikunci antara ruang indeks 4 dan 5.
	_create_zone_lock(0, 4, 4, 5)
	
	# Zona 2: Ruangan indeks 5 hingga 9. Pintu dikunci antara ruang indeks 9 dan 10.
	_create_zone_lock(5, 9, 9, 10)
	
	# Zona 3: Ruangan indeks 10 hingga 14 adalah zona terakhir, tidak butuh pintu pengunci.

func _create_zone_lock(start_idx: int, end_idx: int, door_room_a_idx: int, door_room_b_idx: int) -> void:
	# 1. Menghasilkan kombinasi 3 karakter acak sebagai password
	var passcode = char_pool.pick_random() + char_pool.pick_random() + char_pool.pick_random()
	
	# 2. Memilih satu ruangan acak di dalam rentang zona ini untuk menempelkan petunjuk sandi
	var clue_idx = randi_range(start_idx, end_idx)
	var clue_room_position = critical_path[clue_idx]
	zone_clues[clue_room_position] = passcode
	
	# 3. Mendaftarkan koneksi antara dua ruangan perbatasan sebagai pintu yang harus dikunci
	var room_a = critical_path[door_room_a_idx]
	var room_b = critical_path[door_room_b_idx]
	
	var key_1 = str(room_a) + "_" + str(room_b)
	var key_2 = str(room_b) + "_" + str(room_a)
	
	locked_door_mappings[key_1] = passcode
	locked_door_mappings[key_2] = passcode


# ==========================================
# FUNGSI PERAKITAN 3D (RENDERING)
# ==========================================
func _build_3d_dungeon() -> void:
	var room_instances = {}
	
	# FASE 1: Meletakkan balok-balok ruangan ke dalam dunia
	for x in dimensions.x:
		for y in dimensions.y:
			if str(dungeon[x][y]) != "C": continue
			
			var room_pos = Vector2i(x, y)
			var pos_3d = Vector3(x * room_size, 0, y * room_size)
			
			var new_room = room_prefab.instantiate()
			new_room.position = pos_3d
			add_child(new_room)
			
			room_instances[room_pos] = new_room
			valid_room_positions.append(pos_3d)

	# FASE 2: Menghancurkan dinding yang terhubung dan meletakkan sandi
	for pos in room_instances.keys():
		_process_room_geometry(room_instances[pos], pos)

	# Memperbarui jalur navigasi AI musuh setelah dinding dihancurkan
	call_deferred("bake_navigation_mesh", false)


func _process_room_geometry(room: Node3D, pos: Vector2i) -> void:
	# Mengambil daftar ruangan yang terhubung dengan ruangan ini
	var connections = path_connections.get(pos, [])
	
	# Kamus referensi arah dan nama node dindingnya
	var wall_data = {
		Vector2i(0, -1): "Wall_N",
		Vector2i(1, 0):  "Wall_E",
		Vector2i(0, 1):  "Wall_S",
		Vector2i(-1, 0): "Wall_W"
	}

	# Evaluasi setiap dinding di ruangan ini
	for direction in wall_data.keys():
		var wall_name = wall_data[direction]
		var wall_node = room.get_node_or_null(wall_name)
		
		if not wall_node: continue
		
		# Jika algoritma mencatat ada koneksi ke arah ini, dinding harus dihancurkan
		if connections.has(pos + direction):
			
			# Hanya spawn gerbang dari arah Utara atau Timur untuk mencegah spawn gerbang ganda
			if direction in [Vector2i(0, -1), Vector2i(1, 0)]:
				_spawn_connection(wall_node, pos, pos + direction)
				
			wall_node.queue_free()

	# Jika ruangan ini terpilih untuk menyimpan petunjuk sandi, jalankan fungsinya
	if zone_clues.has(pos):
		_place_clue_in_room(room, pos, wall_data, connections)


func _place_clue_in_room(room: Node3D, pos: Vector2i, wall_data: Dictionary, connections: Array) -> void:
	var clue_node = room.get_node_or_null("WallClue")
	if not clue_node: return

	for direction in wall_data.keys():
		# Lompati jika dinding ini memiliki koneksi (akan dihancurkan)
		if connections.has(pos + direction): continue
		
		var wall_name = wall_data[direction]
		var wall_node = room.get_node_or_null(wall_name)
		
		# Verifikasi bahwa dinding masih utuh dan memiliki marker TextSlot
		if not wall_node or wall_node.is_queued_for_deletion(): continue
		if not wall_node.has_node("TextSlot"): continue
		
		var slot = wall_node.get_node("TextSlot")
		
		# Terapkan teks dan salin koordinat absolut dari TextSlot
		clue_node.text = "SANDI ZONA: " + zone_clues[pos]
		clue_node.global_transform = slot.global_transform
		clue_node.scale = Vector3.ONE
		clue_node.show()
		
		return # Menghentikan fungsi segera setelah teks berhasil ditempel pada 1 dinding

	# Menyembunyikan teks jika terjadi anomali (tidak menemukan dinding solid)
	clue_node.hide()


func _spawn_connection(wall_node: Node3D, room_a: Vector2i, room_b: Vector2i) -> void:
	var door_key = str(room_a) + "_" + str(room_b)
	
	# Menentukan apakah pintu ini masuk ke dalam daftar karantina zona
	var is_locked_door = locked_door_mappings.has(door_key)
	var connection_prefab = locked_door_prefab if is_locked_door else open_gate_prefab
		
	if connection_prefab != null:
		var gate_instance = connection_prefab.instantiate()
		add_child(gate_instance)
		
		# Menerapkan orientasi dari dinding asli
		gate_instance.global_rotation = wall_node.global_rotation
		
		# Menerapkan posisi, tetapi memaksa elevasi (sumbu Y) berada di lantai dasar
		var target_pos = wall_node.global_position
		target_pos.y = 0.0 
		gate_instance.global_position = target_pos
		
		# Menyuntikkan string password ke dalam script pintu
		if is_locked_door and gate_instance.has_method("set_password"):
			gate_instance.set_password(locked_door_mappings[door_key])
