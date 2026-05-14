extends CharacterBody3D

# ==========================================
# PARAMETER PERILAKU MUSUH
# ==========================================
@export var patrol_speed: float = 3.5
@export var chase_speed: float = 6.5
@export var detection_radius: float = 12.0
@export var attack_range: float = 1.5

# ==========================================
# REFERENSI KOMPONEN
# ==========================================
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision_raycast: RayCast3D = $VisionRayCast

var player: CharacterBody3D = null
var level_manager: Node3D = null
var current_state: String = "PATROL"
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ==========================================
# INISIALISASI
# ==========================================
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	level_manager = get_tree().get_first_node_in_group("level_manager")
	
	if vision_raycast != null:
		vision_raycast.add_exception(self)
		vision_raycast.collision_mask = 3 
	
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0
	
	call_deferred("_pick_random_patrol_point")

# ==========================================
# SIKLUS FISIKA UTAMA
# ==========================================
func _physics_process(delta: float) -> void:
	if player == null: return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	match current_state:
		"PATROL":
			_process_patrol(distance_to_player)
		"CHASE":
			_process_chase(distance_to_player)
			
	_move_towards_target()

# ==========================================
# LOGIKA STATUS (STATE LOGIC)
# ==========================================
func _process_patrol(distance_to_player: float) -> void:
	if distance_to_player <= detection_radius and _has_line_of_sight():
		current_state = "CHASE"
		print("Sistem AI: Entitas mendeteksi pemain. Memulai pengejaran.")
		return
		
	# Jika monster mogok karena NavMesh terputus atau sudah sampai tujuan, paksa cari titik baru
	if nav_agent.is_navigation_finished() or velocity.length() < 0.1:
		_pick_random_patrol_point()

func _process_chase(distance_to_player: float) -> void:
	nav_agent.target_position = player.global_position
	
	if distance_to_player > detection_radius * 1.5:
		current_state = "PATROL"
		print("Sistem AI: Entitas kehilangan jejak. Kembali berpatroli.")
		_pick_random_patrol_point()
		return
		
	if distance_to_player <= attack_range:
		_attack_player()

# ==========================================
# KENDALI MOTORIK (DISEMPURNAKAN)
# ==========================================
func _move_towards_target() -> void:
	var direction = Vector3.ZERO
	
	# KOREKSI KRITIS: Bypass NavMesh. Jika mengejar, langsung tabrak pemain!
	if current_state == "CHASE" and _has_line_of_sight():
		direction = global_position.direction_to(player.global_position)
	else:
		# Jika berpatroli, gunakan NavMesh
		if nav_agent.is_navigation_finished():
			velocity.x = move_toward(velocity.x, 0, patrol_speed)
			velocity.z = move_toward(velocity.z, 0, patrol_speed)
			move_and_slide()
			return
			
		var next_pos = nav_agent.get_next_path_position()
		direction = global_position.direction_to(next_pos)
	
	direction.y = 0 
	direction = direction.normalized()
	
	var speed = chase_speed if current_state == "CHASE" else patrol_speed
	
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
	move_and_slide()

# ==========================================
# FUNGSI PEMBANTU (UTILITY)
# ==========================================
func _pick_random_patrol_point() -> void:
	if level_manager != null and level_manager.get("valid_room_positions") != null:
		var points = level_manager.valid_room_positions
		if points.size() > 0:
			var random_target = points.pick_random()
			nav_agent.target_position = random_target

func _has_line_of_sight() -> bool:
	if player == null: return false
	
	# KOREKSI KRITIS: Menambahkan offset Y sebesar 1.5 meter agar 
	# laser menembak tepat ke DADA pemain, bukan ke lantai.
	var player_chest_pos = player.global_position + Vector3(0, 1.5, 0)
	vision_raycast.target_position = vision_raycast.to_local(player_chest_pos)
	vision_raycast.force_raycast_update()
	
	if vision_raycast.is_colliding():
		var collider = vision_raycast.get_collider()
		# Menggunakan identifikasi Group yang lebih aman
		if collider.is_in_group("player"):
			return true
			
	return false

func _attack_player() -> void:
	Global.sanity_level = 0.0
	print("SISTEM FATAL: Pemain dieksekusi oleh entitas. Game Over.")
	set_physics_process(false)
