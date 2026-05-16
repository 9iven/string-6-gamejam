extends CharacterBody3D

# ==========================================
# KONFIGURASI AI & NAVIGASI
# ==========================================
@export var patrol_speed := 3.5
@export var chase_speed := 6.0
@export var detection_radius := 15.0
@export var attack_range := 1.5

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var player: CharacterBody3D
var level_manager: Node3D
var current_state := "PATROL"
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ==========================================
# INISIALISASI & SIKLUS FISIKA
# ==========================================
func _ready() -> void:
	# Menggunakan casting yang aman (safe casting) untuk referensi node
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	level_manager = get_tree().get_first_node_in_group("level_manager") as Node3D
	
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0
	
	call_deferred("_pick_random_patrol_point")

func _physics_process(delta: float) -> void:
	if not player: return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	_evaluate_state()
	_execute_movement()

# ==========================================
# LOGIKA STATE MACHINE
# ==========================================
func _evaluate_state() -> void:
	var dist_to_player := global_position.distance_to(player.global_position)
	
	# Implementasi Match Statement untuk State Machine yang elegan
	match current_state:
		"PATROL":
			if dist_to_player <= detection_radius and _has_line_of_sight():
				current_state = "CHASE"
			elif nav_agent.is_navigation_finished() or velocity.length() < 0.1:
				_pick_random_patrol_point()
				
		"CHASE":
			nav_agent.target_position = player.global_position
			
			if dist_to_player > detection_radius * 1.5:
				current_state = "PATROL"
				_pick_random_patrol_point()
			elif dist_to_player <= attack_range:
				_attack_player() # Pastikan memanggil fungsi ini

# ==========================================
# KENDALI MOTORIK
# ==========================================
func _execute_movement() -> void:
	if nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0, patrol_speed)
		velocity.z = move_toward(velocity.z, 0, patrol_speed)
		move_and_slide()
		return
		
	var next_pos := nav_agent.get_next_path_position()
	var direction := global_position.direction_to(next_pos)
	
	direction.y = 0 
	direction = direction.normalized()
	
	var speed := chase_speed if current_state == "CHASE" else patrol_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	move_and_slide()

# ==========================================
# SENSOR & UTILITAS
# ==========================================
func _has_line_of_sight() -> bool:
	var space_state := get_world_3d().direct_space_state
	var origin_pos := global_position + Vector3(0, 1.0, 0)
	var target_pos := player.global_position + Vector3(0, 1.0, 0)
	
	var query := PhysicsRayQueryParameters3D.create(origin_pos, target_pos)
	query.exclude = [self.get_rid()]
	query.collision_mask = 1 # Sinar hanya terhalang oleh Environment
	
	var result := space_state.intersect_ray(query)
	
	# Optimasi: Mengembalikan evaluasi boolean secara langsung tanpa blok if-else
	return result and result.has("collider") and result.collider.is_in_group("player")

func _pick_random_patrol_point() -> void:
	if level_manager and "valid_room_positions" in level_manager:
		var points: Array = level_manager.valid_room_positions
		if not points.is_empty():
			nav_agent.target_position = points.pick_random()

func _attack_player() -> void:
	# 1. Penalti Status: Mengurangi 50 poin kewarasan
	Global.sanity_level = max(0.0, Global.sanity_level - 50.0)
	
	# 2. Reset Siklus: Memaksa pemain meretas 5 pintu lagi agar monster bisa muncul
	Global.solved_doors = 0
	Global.monster_spawned = false
	
	# 3. Pemicu Visual: Mengirim sinyal ke pemain untuk menampilkan gambar
	if player.has_method("show_jumpscare"):
		player.show_jumpscare()
		
	# 4. Eliminasi Diri: Menghapus entitas monster dari memori
	queue_free()
