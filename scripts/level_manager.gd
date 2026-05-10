extends NavigationRegion3D

@export var room_prefab: PackedScene
@export var open_gate_prefab: PackedScene
@export var locked_door_prefab: PackedScene
@export var monster_prefab: PackedScene
@export var player_node: CharacterBody3D

var dimensions: Vector2i = Vector2i(15, 15) 
var room_size: float = 10.0

var dungeon: Array = []
var path_connections: Dictionary = {}
var valid_room_positions: Array[Vector3] = []

var critical_path: Array[Vector2i] = []
var zone_clues: Dictionary = {} 
var locked_door_mappings: Dictionary = {} 
var char_pool: Array[String] = ["A", "B", "C", "X", "Y", "Z", "7", "9"]

func _ready() -> void:
	randomize()
	_initialize_dungeon()
	
	var start_pos = Vector2i(7, 14)
	
	# 1. Bangun rute tunggal yang berkelok sepanjang 15 ruangan tanpa cabang
	var initial_path: Array[Vector2i] = []
	if _generate_path(start_pos, 15, initial_path):
		critical_path.assign(initial_path)
		
		# 2. Eksekusi karantina dan penyebaran sandi
		_setup_strict_zones()
		
		# 3. Rakit geometri fisik
		_build_3d_dungeon()
		
		if player_node != null:
			player_node.global_position = Vector3(start_pos.x * room_size, 2.0, start_pos.y * room_size)
	else:
		print("Galat Kritis: Gagal membangun 15 ruangan berurutan. Area terlalu sempit.")

func _initialize_dungeon() -> void:
	dungeon.clear()
	path_connections.clear()
	for x in dimensions.x:
		dungeon.append([])
		for y in dimensions.y:
			dungeon[x].append("0")

func _add_connection(a: Vector2i, b: Vector2i) -> void:
	if not path_connections.has(a): path_connections[a] = []
	if not path_connections.has(b): path_connections[b] = []
	if not path_connections[a].has(b): path_connections[a].append(b)
	if not path_connections[b].has(a): path_connections[b].append(a)

func _remove_connection(a: Vector2i, b: Vector2i) -> void:
	if path_connections.has(a): path_connections[a].erase(b)
	if path_connections.has(b): path_connections[b].erase(a)

# Algoritma rotasi 90 derajat yang menjamin rute tidak tumpang tindih
func _generate_path(current: Vector2i, length: int, current_path: Array[Vector2i]) -> bool:
	current_path.append(current)
	dungeon[current.x][current.y] = "C"
	
	if length == 1:
		return true
		
	var direction = Vector2i(0, -1)
	var rand_dir = randi() % 4
	if rand_dir == 0: direction = Vector2i(0, -1)
	elif rand_dir == 1: direction = Vector2i(1, 0)
	elif rand_dir == 2: direction = Vector2i(0, 1)
	else: direction = Vector2i(-1, 0)
	
	for i in range(4):
		var next_pos = current + direction
		if next_pos.x >= 0 and next_pos.x < dimensions.x and next_pos.y >= 0 and next_pos.y < dimensions.y:
			if str(dungeon[next_pos.x][next_pos.y]) == "0":
				
				_add_connection(current, next_pos)
				if _generate_path(next_pos, length - 1, current_path):
					return true
					
				_remove_connection(current, next_pos)
				
		direction = Vector2i(-direction.y, direction.x)
		
	dungeon[current.x][current.y] = "0"
	current_path.pop_back()
	return false

# --- FUNGSI KARANTINA ZONA ---
func _setup_strict_zones() -> void:
	# Mengunci Zona 1 (Ruang 1-5) dan meletakkan sandi
	_create_zone_lock(0, 4, 4, 5)
	
	# Mengunci Zona 2 (Ruang 6-10) dan meletakkan sandi
	_create_zone_lock(5, 9, 9, 10)
	
	# Zona 3 (Ruang 11-15) adalah zona akhir, tidak membutuhkan pintu pengunci di ujungnya.

func _create_zone_lock(start_idx: int, end_idx: int, door_room_a_idx: int, door_room_b_idx: int) -> void:
	# Hasilkan sandi 3 digit acak
	var passcode = char_pool.pick_random() + char_pool.pick_random() + char_pool.pick_random()
	
	# Pilih SATU ruangan secara acak di dalam rentang 5 ruangan ini untuk menyimpan petunjuk
	var clue_idx = randi_range(start_idx, end_idx)
	zone_clues[critical_path[clue_idx]] = passcode
	
	# Dapatkan koordinat dari dua ruangan yang menjadi perbatasan zona
	var room_a = critical_path[door_room_a_idx]
	var room_b = critical_path[door_room_b_idx]
	
	var key_1 = str(room_a) + "_" + str(room_b)
	var key_2 = str(room_b) + "_" + str(room_a)
	
	# Registrasi perbatasan tersebut agar diganti menjadi pintu terkunci
	locked_door_mappings[key_1] = passcode
	locked_door_mappings[key_2] = passcode

func _build_3d_dungeon() -> void:
	var room_instances = {}
	
	# 1. Tahap Inisialisasi: Fokus hanya pada membuat ruangan
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

	# 2. Tahap Geometri: Mengatur dinding, gerbang, dan sandi
	for pos in room_instances.keys():
		_process_room_geometry(room_instances[pos], pos)

	call_deferred("bake_navigation_mesh", false)

# --- HELPER FUNCTIONS UNTUK MENYEDERHANAKAN LOGIKA ---

func _process_room_geometry(room: Node3D, pos: Vector2i) -> void:
	var connections = path_connections.get(pos, [])
	var wall_data = {
		Vector2i(0, -1): "Wall_N",
		Vector2i(1, 0): "Wall_E",
		Vector2i(0, 1): "Wall_S",
		Vector2i(-1, 0): "Wall_W"
	}

	# Proses Dinding dan Pintu
	for direction in wall_data.keys():
		var wall_name = wall_data[direction]
		var wall_node = room.get_node_or_null(wall_name)
		
		if not wall_node: continue
		
		if connections.has(pos + direction):
			# Jika ada koneksi, buat gerbang lalu hapus dinding
			if direction in [Vector2i(0, -1), Vector2i(1, 0)]:
				_spawn_connection(wall_node, pos, pos + direction)
			wall_node.queue_free()

	# Proses Penempelan Sandi (Hanya jika dibutuhkan)
	if zone_clues.has(pos):
		_place_clue_in_room(room, pos, wall_data, connections)

func _place_clue_in_room(room: Node3D, pos: Vector2i, wall_data: Dictionary, connections: Array) -> void:
	var clue_node = room.get_node_or_null("WallClue")
	if not clue_node: return

	for direction in wall_data.keys():
		# Guard Clause: Cari dinding yang TIDAK punya koneksi (solid)
		if connections.has(pos + direction): continue
		
		var wall_name = wall_data[direction]
		var wall_node = room.get_node_or_null(wall_name)
		
		# Pastikan wall belum dihapus dan punya TextSlot
		if not wall_node or wall_node.is_queued_for_deletion(): continue
		if not wall_node.has_node("TextSlot"): continue
		
		var slot = wall_node.get_node("TextSlot")
		clue_node.text = "SANDI ZONA: " + zone_clues[pos]
		clue_node.global_transform = slot.global_transform
		clue_node.scale = Vector3.ONE
		clue_node.show()
		return # Berhenti setelah berhasil menempel satu kali

	# Jika sampai sini tidak ketemu dinding solid, sembunyikan teks
	clue_node.hide()

func _spawn_connection(wall_node: Node3D, room_a: Vector2i, room_b: Vector2i) -> void:
	var connection_prefab = open_gate_prefab
	var door_key = str(room_a) + "_" + str(room_b)
	
	# Validasi apakah rute spesifik ini adalah perbatasan yang dikarantina
	var is_locked_door = locked_door_mappings.has(door_key)
	
	if is_locked_door and locked_door_prefab != null:
		connection_prefab = locked_door_prefab
		
	if connection_prefab != null:
		var gate_instance = connection_prefab.instantiate()
		add_child(gate_instance)
		gate_instance.global_rotation = wall_node.global_rotation
		
		var target_pos = wall_node.global_position
		target_pos.y = 0.0 
		gate_instance.global_position = target_pos
		
		if is_locked_door and gate_instance.has_method("set_password"):
			gate_instance.set_password(locked_door_mappings[door_key])
