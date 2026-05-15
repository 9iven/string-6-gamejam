extends CharacterBody3D

@export var patrol_speed: float = 3.5
@export var chase_speed: float = 6.5
@export var detection_radius: float = 15.0
@export var attack_range: float = 1.5

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var player: CharacterBody3D = null
var level_manager: Node3D = null
var current_state: String = "PATROL"
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	level_manager = get_tree().get_first_node_in_group("level_manager")
	
	# Toleransi jarak agar entitas tidak tersangkut saat mencapai titik tujuan
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0
	
	call_deferred("_pick_random_patrol_point")

func _physics_process(delta: float) -> void:
	if player == null: return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	match current_state:
		"PATROL":
			_process_patrol()
		"CHASE":
			_process_chase()
			
	# Eksekusi pergerakan di akhir frame fisika
	_move_with_navmesh()

func _process_patrol() -> void:
	var dist_to_player = global_position.distance_to(player.global_position)
	
	if dist_to_player <= detection_radius and _has_line_of_sight():
		current_state = "CHASE"
		return
		
	# Meminta titik baru JIKA NavigationAgent sudah selesai ATAU entitas mogok/tersangkut
	if nav_agent.is_navigation_finished() or velocity.length() < 0.1:
		_pick_random_patrol_point()

func _process_chase() -> void:
	# Terus perbarui titik tujuan NavigationMesh ke posisi pemain saat ini
	nav_agent.target_position = player.global_position
	
	var dist_to_player = global_position.distance_to(player.global_position)
	
	# Evaluasi pelepasan target
	if dist_to_player > detection_radius * 1.5:
		current_state = "PATROL"
		_pick_random_patrol_point()
		return
		
	if dist_to_player <= attack_range:
		_attack_player()

func _move_with_navmesh() -> void:
	# FUNGSI ABSOLUT: Hanya bergerak berdasarkan titik panduan dari NavigationAgent3D
	if nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0, patrol_speed)
		velocity.z = move_toward(velocity.z, 0, patrol_speed)
		move_and_slide()
		return
		
	var next_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_pos)
	
	# Mengunci sumbu Y agar entitas tidak berusaha menggali ke dalam lantai
	direction.y = 0 
	direction = direction.normalized()
	
	var speed = chase_speed if current_state == "CHASE" else patrol_speed
	
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	move_and_slide()

func _pick_random_patrol_point() -> void:
	if level_manager != null and level_manager.get("valid_room_positions") != null:
		var points = level_manager.valid_room_positions
		if points.size() > 0:
			nav_agent.target_position = points.pick_random()

func _has_line_of_sight() -> bool:
	var space_state = get_world_3d().direct_space_state
	
	# Sinar ditembakkan sejajar dengan badan agar tidak menabrak lantai
	var origin_pos = global_position + Vector3(0, 1.0, 0)
	var target_pos = player.global_position + Vector3(0, 1.0, 0)
	
	var query = PhysicsRayQueryParameters3D.create(origin_pos, target_pos)
	query.exclude = [self.get_rid()]
	
	# Menggunakan Mask 1 (Environment/Tembok) untuk penghalang visual.
	# Jika pintu Anda berada di Mask 3, sinar ini akan menembus pintu.
	query.collision_mask = 1 
	
	var result = space_state.intersect_ray(query)
	
	if result and result.has("collider"):
		var collider = result.collider
		if collider == player or collider.is_in_group("player"):
			return true
			
	return false

func _attack_player() -> void:
	Global.sanity_level = 0.0
	print("Game Over")
	set_physics_process(false)
