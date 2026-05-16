extends NavigationRegion3D

# ==========================================
# 1. KONFIGURASI DAN REFERENSI NODE
# ==========================================
@export_group("Prefabs (Cetak Biru)")
@export var room_prefab: PackedScene
@export var open_gate_prefab: PackedScene
@export var locked_door_prefab: PackedScene
@export var final_exit_prefab: PackedScene 
@export var monster_prefab: PackedScene
@export var player_node: CharacterBody3D

@export_group("Pengaturan Matriks Labirin")
var dimensions: Vector2i = Vector2i(7, 7) 
var room_size: float = 10.0

# ==========================================
# 2. VARIABEL PENYIMPANAN DATA
# ==========================================
var path_connections: Dictionary = {}
var edge_types: Dictionary = {} 
var valid_room_positions: Array[Vector3] = [] 

# Deklarasi variabel tanpa nilai statis
var start_pos: Vector2i 
var exit_room_pos: Vector2i
var exit_wall_direction: Vector2i

var final_password: Array[String] = []
var clue_rooms: Dictionary = {}
var char_pool: Array[String] = ["A", "B", "C", "X", "Y", "Z", "7", "9"]

# ==========================================
# FUNGSI UTAMA (ALUR EKSEKUSI)
# ==========================================
func _ready() -> void:
	randomize()
	
	# KALKULASI PUSAT DINAMIS: Mencari titik tengah matriks secara otomatis
	start_pos = Vector2i(dimensions.x / 2, dimensions.y / 2)
	
	_generate_dense_maze()
	_remove_dead_ends()
	_setup_blue_prince_logic()
	_assign_global_edge_types() 
	_build_3d_dungeon()
	
	if player_node != null:
		player_node.global_position = Vector3(start_pos.x * room_size, 2.0, start_pos.y * room_size)

# ==========================================
# PEMBANGKITAN BRAID MAZE (TANPA VOID)
# ==========================================
func _add_connection(a: Vector2i, b: Vector2i) -> void:
	if not path_connections.has(a): path_connections[a] = []
	if not path_connections.has(b): path_connections[b] = []
	if not path_connections[a].has(b): path_connections[a].append(b)
	if not path_connections[b].has(a): path_connections[b].append(a)

func _generate_dense_maze() -> void:
	path_connections.clear()
	var unvisited = []
	for x in dimensions.x:
		for y in dimensions.y:
			unvisited.append(Vector2i(x, y))

	var stack = []
	var current = start_pos
	unvisited.erase(current)
	stack.append(current)

	# Iterative Randomized DFS (Sempurna untuk grid padat tanpa void)
	while stack.size() > 0:
		current = stack.back()
		var unvisited_neighbors = []
		var dirs = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
		
		for d in dirs:
			var n = current + d
			if n.x >= 0 and n.x < dimensions.x and n.y >= 0 and n.y < dimensions.y:
				if unvisited.has(n):
					unvisited_neighbors.append(n)

		if unvisited_neighbors.size() > 0:
			var next_room = unvisited_neighbors.pick_random()
			_add_connection(current, next_room)
			unvisited.erase(next_room)
			stack.append(next_room)
		else:
			stack.pop_back()

func _remove_dead_ends() -> void:
	# Memindai seluruh 400 ruangan. Jika ada yang buntu (hanya punya 1 pintu), paksa tembus ke tetangga.
	for x in dimensions.x:
		for y in dimensions.y:
			var pos = Vector2i(x, y)
			if path_connections.has(pos) and path_connections[pos].size() == 1:
				var dirs = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
				var possible_links = []
				for d in dirs:
					var n = pos + d
					if n.x >= 0 and n.x < dimensions.x and n.y >= 0 and n.y < dimensions.y:
						if not path_connections[pos].has(n):
							possible_links.append(n)
				
				if possible_links.size() > 0:
					_add_connection(pos, possible_links.pick_random())


# ==========================================
# LOGIKA SANDI DAN RUTE TERPENDEK
# ==========================================
func _setup_blue_prince_logic() -> void:
	for i in range(3):
		final_password.append(char_pool.pick_random())
		
	# PENGACAKAN PINTU KELUAR: Memilih salah satu dari 4 sisi batas labirin
	var edge_choice = randi() % 4
	if edge_choice == 0: # Sisi Utara
		exit_room_pos = Vector2i(randi_range(0, dimensions.x - 1), 0)
		exit_wall_direction = Vector2i(0, -1) 
	elif edge_choice == 1: # Sisi Selatan
		exit_room_pos = Vector2i(randi_range(0, dimensions.x - 1), dimensions.y - 1)
		exit_wall_direction = Vector2i(0, 1)
	elif edge_choice == 2: # Sisi Barat
		exit_room_pos = Vector2i(0, randi_range(0, dimensions.y - 1))
		exit_wall_direction = Vector2i(-1, 0)
	else: # Sisi Timur
		exit_room_pos = Vector2i(dimensions.x - 1, randi_range(0, dimensions.y - 1))
		exit_wall_direction = Vector2i(1, 0)
	
	# Algoritma Breadth-First Search (BFS)
	var queue = [start_pos]
	var came_from = {start_pos: null}
	
	while queue.size() > 0:
		var curr = queue.pop_front()
		if curr == exit_room_pos: break
		for n in path_connections[curr]:
			if not came_from.has(n):
				came_from[n] = curr
				queue.append(n)
				
	var shortest_path = []
	var step = exit_room_pos
	while step != null:
		shortest_path.append(step)
		step = came_from[step]
	shortest_path.reverse()
	
	# Distribusi petunjuk sandi
	var clue_indices = [
		shortest_path.size() / 4,
		shortest_path.size() / 2,
		(shortest_path.size() * 3) / 4
	]
	
	for i in range(3):
		var room_idx = clamp(clue_indices[i], 1, shortest_path.size() - 2)
		var room_target = shortest_path[room_idx]
		clue_rooms[room_target] = "DIGIT " + str(i + 1) + " = " + final_password[i]

# ==========================================
# AUDIT PINTU GLOBAL (JAMINAN 2 RUTE AMAN)
# ==========================================
func _get_edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return str(a.x) + "," + str(a.y) + "-" + str(b.x) + "," + str(b.y)
	return str(b.x) + "," + str(b.y) + "-" + str(a.x) + "," + str(a.y)

func _assign_global_edge_types() -> void:
	edge_types.clear()
	var all_edges = []
	
	for room in path_connections.keys():
		for neighbor in path_connections[room]:
			var edge = _get_edge_key(room, neighbor)
			if not all_edges.has(edge):
				all_edges.append(edge)
				
	for edge in all_edges:
		var r = randf()
		if r < 0.4: edge_types[edge] = "open_gate"
		elif r < 0.8: edge_types[edge] = "real" 
		else: edge_types[edge] = "trap"
			
	# Audit untuk memastikan setiap ruangan di dalam matriks padat ini memiliki >= 2 rute aman
	for room in path_connections.keys():
		var neighbors = path_connections[room]
		var safe_count = 0
		var trap_edges = []
		
		for n in neighbors:
			var edge = _get_edge_key(room, n)
			var type = edge_types[edge]
			if type in ["open_gate", "real"]: safe_count += 1
			elif type == "trap": trap_edges.append(edge)
				
		while safe_count < 2 and trap_edges.size() > 0:
			var edge_to_fix = trap_edges.pop_back()
			edge_types[edge_to_fix] = "open_gate" if randf() < 0.5 else "real"
			safe_count += 1

# ==========================================
# PERAKITAN 3D
# ==========================================
func _build_3d_dungeon() -> void:
	var room_instances = {}
	
	# 20x20 matriks padat (semua koordinat dirender)
	for x in dimensions.x:
		for y in dimensions.y:
			var room_pos = Vector2i(x, y)
			var pos_3d = Vector3(x * room_size, 0, y * room_size)
			var new_room = room_prefab.instantiate()
			new_room.position = pos_3d
			add_child(new_room)
			room_instances[room_pos] = new_room
			valid_room_positions.append(pos_3d)

	for pos in room_instances.keys():
		_process_room_geometry(room_instances[pos], pos)


	call_deferred("bake_navigation_mesh", false)

func _process_room_geometry(room: Node3D, pos: Vector2i) -> void:
	var connections = path_connections.get(pos, [])
	var wall_data = {
		Vector2i(0, -1): "Wall_N",
		Vector2i(1, 0):  "Wall_E",
		Vector2i(0, 1):  "Wall_S",
		Vector2i(-1, 0): "Wall_W"
	}

	for direction in wall_data.keys():
		var wall_name = wall_data[direction]
		var wall_node = room.get_node_or_null(wall_name)
		if not wall_node: continue
		
		var next_pos = pos + direction
		
		# Pintu Keluar Utama
		if pos == exit_room_pos and direction == exit_wall_direction:
			_spawn_interaction(wall_node, "exit", true)
			wall_node.queue_free()
			continue
			
		# Tembok perbatasan absolut (Luar peta 20x20)
		if next_pos.x < 0 or next_pos.x >= dimensions.x or next_pos.y < 0 or next_pos.y >= dimensions.y:
			continue
			
		if connections.has(next_pos):
			# Rute Valid
			if direction in [Vector2i(0, -1), Vector2i(-1, 0)]:
				var edge_key = _get_edge_key(pos, next_pos)
				var type = edge_types[edge_key]
				_spawn_interaction(wall_node, type, true) 
					
			wall_node.queue_free() 
		else:
			# Rute Palsu
			_spawn_interaction(wall_node, "fake", false)

	if clue_rooms.has(pos):
		_place_clue_on_floor(room, pos)

func _spawn_interaction(wall_node: Node3D, type: String, is_real_path: bool) -> void:
	var prefab = null
	
	if type == "open_gate": prefab = open_gate_prefab
	elif type == "exit": prefab = final_exit_prefab
	else: prefab = locked_door_prefab 
		
	if prefab == null: return
	
	var instance = prefab.instantiate()
	add_child(instance)
	
	instance.global_rotation = wall_node.global_rotation
	var target_pos = wall_node.global_position
	target_pos.y = 0.0
	instance.global_position = target_pos
	
# TERAPKAN UNTUK SEMUA PINTU: Mencegah clipping dan Z-fighting
	if type != "open_gate":
		# KOREKSI KETEBALAN: Ubah skala Z dari 0.05 menjadi 0.2 (atau 0.3) 
		# agar dinding peretasan terlihat seperti balok beton yang solid.
		instance.scale = Vector3(1.0, 1.0, 0.999) 
		
		instance.set_meta("door_type", type)
		if type == "exit":
			instance.set_meta("password", "".join(final_password))

func _place_clue_on_floor(room: Node3D, pos: Vector2i) -> void:
	var clue_node = room.get_node_or_null("FloorClue")
	if not clue_node: return

	clue_node.text = clue_rooms[pos]
	clue_node.show()

# ==========================================
# SISTEM ENTITAS MUSUH
# ==========================================
func spawn_monster() -> void:
	var monster = monster_prefab.instantiate()
	
	# KOREKSI KRITIS: Objek WAJIB dimasukkan ke dalam memori Tree terlebih dahulu
	add_child(monster) 
	
	# SETELAH berada di dalam Tree, baru kita bisa memanipulasi koordinat globalnya
	var spawn_pos = valid_room_positions.pick_random()
	spawn_pos.y = 2.5 
	monster.global_position = spawn_pos

# ==========================================
# PEMBARUAN PETA NAVIGASI DINAMIS (RUNTIME)
# ==========================================
func rebake_map() -> void:
	# Menginstruksikan NavigationRegion3D untuk menggambar ulang peta AI
	# Parameter 'false' memastikan proses ini dieksekusi di background thread
	bake_navigation_mesh(false)
