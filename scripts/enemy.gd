extends CharacterBody3D

# ==========================================
# KONFIGURASI AI & NAVIGASI
# ==========================================
@export var patrol_speed := 3.5
@export var chase_speed := 6.0
@export var detection_radius := 15.0
@export var attack_range := 1.5

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# Referensi Node Audio
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio3D
@onready var footstep_timer: Timer = $FootstepTimer
@onready var jumpscare_audio: AudioStreamPlayer = $JumpscareAudio

var player: CharacterBody3D
var level_manager: Node3D
var current_state := "PATROL"
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ==========================================
# INISIALISASI & SIKLUS FISIKA
# ==========================================
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	level_manager = get_tree().get_first_node_in_group("level_manager") as Node3D
	
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0
	
	# Mengikat siklus timer ke fungsi modulasi langkah
	footstep_timer.timeout.connect(_on_footstep_timer_timeout)
	
	call_deferred("_pick_random_patrol_point")

func _physics_process(delta: float) -> void:
	if not player: return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	_evaluate_state()
	_execute_movement()
	_handle_footstep_state()

# ==========================================
# LOGIKA STATE MACHINE
# ==========================================
func _evaluate_state() -> void:
	var dist_to_player := global_position.distance_to(player.global_position)
	
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
				_attack_player() 

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
# MANAJEMEN AUDIO
# ==========================================
func _handle_footstep_state() -> void:
	# Hanya putar langkah jika entitas bergerak dan menyentuh lantai
	if velocity.length() > 0.1 and is_on_floor():
		if footstep_timer.is_stopped():
			# Sesuaikan kecepatan langkah dengan state saat ini (berlari vs berjalan)
			footstep_timer.wait_time = 0.35 if current_state == "CHASE" else 0.55
			footstep_timer.start()
	else:
		footstep_timer.stop()

func _on_footstep_timer_timeout() -> void:
	# Modulasi pitch algoritmik untuk mencegah repetisi monoton
	footstep_audio.pitch_scale = randf_range(0.85, 1.15)
	footstep_audio.play()

func _play_detached_jumpscare() -> void:
	if jumpscare_audio.stream == null: return
	
	# Menduplikasi node audio agar bebas dari hierarki monster
	var detached_audio = jumpscare_audio.duplicate()
	get_tree().root.add_child(detached_audio)
	
	detached_audio.play()
	
	# Memerintahkan node duplikat untuk menghancurkan dirinya sendiri pasca-pemutaran
	detached_audio.finished.connect(detached_audio.queue_free)

# ==========================================
# SENSOR & UTILITAS
# ==========================================
func _has_line_of_sight() -> bool:
	var space_state := get_world_3d().direct_space_state
	var origin_pos := global_position + Vector3(0, 1.0, 0)
	var target_pos := player.global_position + Vector3(0, 1.0, 0)
	
	var query := PhysicsRayQueryParameters3D.create(origin_pos, target_pos)
	query.exclude = [self.get_rid()]
	query.collision_mask = 1 
	
	var result := space_state.intersect_ray(query)
	return result and result.has("collider") and result.collider.is_in_group("player")

func _pick_random_patrol_point() -> void:
	if level_manager and "valid_room_positions" in level_manager:
		var points: Array = level_manager.valid_room_positions
		if not points.is_empty():
			nav_agent.target_position = points.pick_random()

func _attack_player() -> void:
	# 1. Eksekusi Audio Terdekopel
	_play_detached_jumpscare()
	
	# 2. Penalti Status: Mengurangi 50 poin kewarasan
	Global.sanity_level = max(0.0, Global.sanity_level - 50.0)
	
	# 3. Reset Siklus: Memaksa pemain meretas 5 pintu lagi agar monster bisa muncul
	Global.solved_doors = 0
	Global.monster_spawned = false
	
	# 4. Pemicu Visual: Mengirim sinyal ke pemain untuk menampilkan gambar
	if player.has_method("show_jumpscare"):
		player.show_jumpscare()
		
	# 5. Eliminasi Diri: Menghapus entitas monster dari memori dengan aman
	queue_free()
