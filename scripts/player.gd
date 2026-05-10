extends CharacterBody3D

const BASE_SPEED = 5.0
const SPRINT_SPEED = 8.5
const MOUSE_SENSITIVITY = 0.003
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera = $Camera3D
@onready var interact_ray = $Camera3D/RayCast3D

# Referensi UI (Menggunakan Unique Name % agar terhindar dari galat null instance)
@onready var crosshair = %Crosshair
@onready var sanity_bar = %SanityBar
@onready var stamina_bar = %StaminaBar

var _mouse_motion: Vector2 = Vector2.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interact_ray.add_exception(self)
	
	# Sinkronisasi batas UI dengan data Global
	if sanity_bar != null and stamina_bar != null:
		sanity_bar.max_value = Global.max_sanity
		stamina_bar.max_value = Global.max_stamina

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_motion += event.relative

	# Logika Interaksi Objek
	if event.is_action_pressed("interact"):
		if interact_ray.is_colliding():
			var target = interact_ray.get_collider()
			if target.has_method("tune_string"):
				target.tune_string(20.0)
				Global.sanity_level = max(0.0, Global.sanity_level - 10.0)
				Global.sanity_changed.emit(Global.sanity_level)
			elif target.has_method("hack_wall"):
				target.hack_wall()

	# Manajemen Kursor
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().root.set_input_as_handled()

func _process(_delta: float) -> void:
	# 1. Pembaruan UI secara konstan
	if sanity_bar != null:
		sanity_bar.value = Global.sanity_level
	if stamina_bar != null:
		stamina_bar.value = Global.stamina_level
		
	# 2. Logika Deteksi Crosshair Dinamis
	if crosshair != null:
		if interact_ray.is_colliding():
			var target = interact_ray.get_collider()
			if target.has_method("tune_string") or target.has_method("hack_wall"):
				crosshair.color = Color(1, 0, 0) # Berubah merah saat dapat diinteraksi
			else:
				crosshair.color = Color(1, 1, 1) # Putih
		else:
			crosshair.color = Color(1, 1, 1) # Putih

func _physics_process(delta: float) -> void:
	# 1. Rotasi Kamera
	if _mouse_motion != Vector2.ZERO:
		rotate_y(-_mouse_motion.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-_mouse_motion.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		_mouse_motion = Vector2.ZERO

	# 2. Gravitasi
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 3. Kalkulasi Vektor Input
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# 4. Manajemen Sprint dan Drainase Stamina
	var current_speed = BASE_SPEED
	
	# Kondisi: Tombol sprint ditekan, stamina ada, dan karakter benar-benar sedang bergerak
	if Input.is_action_pressed("sprint") and Global.stamina_level > 0 and direction != Vector3.ZERO:
		current_speed = SPRINT_SPEED
		Global.is_sprinting = true
		# Menguras stamina secara proporsional per frame
		Global.stamina_level = max(0.0, Global.stamina_level - (25.0 * delta)) 
	else:
		# Jika tombol dilepas atau stamina habis, matikan status sprint untuk memicu regenerasi
		Global.is_sprinting = false

	# 5. Eksekusi Pergerakan Fisis
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
