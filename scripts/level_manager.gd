extends NavigationRegion3D

@export var room_prefab: PackedScene
@export var door_prefab: PackedScene
@export var monster_prefab: PackedScene

@export var player_node: CharacterBody3D

# Dimensi matriks labirin
var dimensions: Vector2i = Vector2i(7, 5) 
var room_size: float = 10.0

var dungeon: Array = []
var branch_candidates: Array[Vector2i] = []
var valid_room_positions: Array[Vector3] = []

func _ready() -> void:
	randomize()
	_initialize_dungeon()

	var start_pos = Vector2i(3, 4)
	dungeon[start_pos.x][start_pos.y] = "S"

	_generate_path(start_pos, 10, "C")
	_generate_branches(3, Vector2i(2, 4))
	_build_3d_dungeon()
	
	if player_node != null:
		# Mengalkulasi posisi tengah ruang pertama
		var start_world_pos = Vector3(start_pos.x * room_size, 2.0, start_pos.y * room_size)

		# Memindahkan Player ke ruang pertama. 
		# Sumbu Y diatur ke 2.0 agar karakter jatuh sedikit dari udara dan tidak terjebak di dalam lantai (clipping).
		player_node.global_position = start_world_pos
	else:
		print("Galat: Node Player belum dihubungkan pada Inspector!")

func _initialize_dungeon() -> void:
	for x in dimensions.x:
		dungeon.append([])
		for y in dimensions.y:
			dungeon[x].append("0")

func _generate_path(current: Vector2i, length: int, marker: String) -> bool:
	if length == 0:
		return true
		
	var dirs = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]
	dirs.shuffle() # Mengacak arah eksplorasi
	
	for dir in dirs:
		var next_pos = current + dir
		# Validasi batas array
		if next_pos.x >= 0 and next_pos.x < dimensions.x and next_pos.y >= 0 and next_pos.y < dimensions.y:
			if str(dungeon[next_pos.x][next_pos.y]) == "0":
				dungeon[next_pos.x][next_pos.y] = marker
				
				# Pemanggilan rekursif
				if _generate_path(next_pos, length - 1, marker):
					branch_candidates.append(next_pos)
					return true
					
				# Backtracking jika jalur buntu
				dungeon[next_pos.x][next_pos.y] = "0"
	return false

func _generate_branches(num_branches: int, length_range: Vector2i) -> void:
	var branches_created = 0
	while branches_created < num_branches and branch_candidates.size() > 0:
		var candidate = branch_candidates.pick_random()
		var branch_length = randi_range(length_range.x, length_range.y)
		
		# Penanda cabang direpresentasikan oleh angka (1, 2, 3...)
		if _generate_path(candidate, branch_length, str(branches_created + 1)):
			branches_created += 1
		else:
			branch_candidates.erase(candidate)

func _build_3d_dungeon() -> void:
	# Struktur data untuk menyimpan referensi instansi ruangan berdasarkan koordinat
	var room_instances = {}
	
	# Fase A: Peletakan Ruangan
	for x in dimensions.x:
		for y in dimensions.y:
			var cell_val = str(dungeon[x][y])
			if cell_val != "0": 
				var pos_3d = Vector3(x * room_size, 0, y * room_size)
				
				# Menggunakan variabel baru untuk menghindari konflik nama
				var new_room = room_prefab.instantiate()
				new_room.position = pos_3d
				add_child(new_room)
				
				room_instances[Vector2i(x, y)] = new_room
				valid_room_positions.append(pos_3d)
				
				# Meletakkan pintu sandi pada jalur cabang
				if cell_val.is_valid_int() and int(cell_val) > 0:
					if door_prefab != null:
						var new_door = door_prefab.instantiate()
						new_door.position = pos_3d
						add_child(new_door)

	# Fase B: Penggalian Lorong (Menghancurkan Dinding yang Berdempetan)
	for pos in room_instances.keys():
		var target_room = room_instances[pos]
		
		# Pengecekan arah Utara (Z-)
		if room_instances.has(pos + Vector2i(0, -1)):
			if target_room.has_node("Wall_N"): target_room.get_node("Wall_N").queue_free()
			
		# Pengecekan arah Selatan (Z+)
		if room_instances.has(pos + Vector2i(0, 1)):
			if target_room.has_node("Wall_S"): target_room.get_node("Wall_S").queue_free()
			
		# Pengecekan arah Timur (X+)
		if room_instances.has(pos + Vector2i(1, 0)):
			if target_room.has_node("Wall_E"): target_room.get_node("Wall_E").queue_free()
			
		# Pengecekan arah Barat (X-)
		if room_instances.has(pos + Vector2i(-1, 0)):
			if target_room.has_node("Wall_W"): target_room.get_node("Wall_W").queue_free()

	# Fase C: Kompilasi NavigationMesh
	call_deferred("bake_navigation_mesh", false)
	print("Sistem: Labirin prosedural berhasil dirender secara spasial.")
