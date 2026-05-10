extends CharacterBody3D

const SPEED = 3.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Sekarang masih pake global player position
@export var player_target: Node3D

func _ready() -> void:
	# Pencarian target otomatis
	if player_target == null:
		player_target = get_tree().root.find_child("Player", true, false)

func _physics_process(delta: float) -> void:
	# 1. Gravitasi
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Pengejaran Instan (Brute-Force)
	if player_target != null:
		var current_pos = global_position
		var target_pos = player_target.global_position
		
		# Jarak antara musuh dan pemain
		var distance = current_pos.distance_to(target_pos)
		
		# Jika jarak masih lebih dari 1 meter, kejar terus
		if distance > 1.0:
			# Menghitung arah langsung ke pemain
			var direction = current_pos.direction_to(target_pos)
			direction.y = 0 # Netralkan sumbu Y agar tidak terbang
			direction = direction.normalized()
			
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			# Berhenti jika sudah sangat dekat
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
	
	# 3. Eksekusi Pergerakan
	move_and_slide()
