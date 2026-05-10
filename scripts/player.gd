extends CharacterBody3D

# === VARIABEL KONFIGURASI ===
const BASE_SPEED = 5.0
const SPRINT_SPEED = 8.5
const MOUSE_SENSITIVITY = 0.003
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# === REFERENSI NODE ===
@onready var camera = $Camera3D
@onready var interact_ray = $Camera3D/RayCast3D

# Referensi UI (User Interface)
@onready var crosshair = %Crosshair
@onready var sanity_bar = %SanityBar
@onready var stamina_bar = %StaminaBar
@onready var terminal_ui = $TerminalUI

# Variabel Internal
var _mouse_motion: Vector2 = Vector2.ZERO


# ==========================================
# FUNGSI BAWAAN GODOT (ALUR UTAMA)
# ==========================================

func _ready() -> void:
	# 1. Menangkap kursor mouse ke dalam jendela permainan
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# 2. Mencegah raycast mendeteksi tubuh karakter sendiri
	interact_ray.add_exception(self)
	
	# 3. Menyiapkan batas maksimal UI
	_initialize_ui()

func _input(event: InputEvent) -> void:
	_handle_mouse_capture(event)
	
	# Mengumpulkan pergerakan mouse untuk diproses pada frame fisika
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_motion += event.relative

	# Mendengarkan tombol interaksi ditekan
	if event.is_action_pressed("interact"):
		_try_interact()

func _process(_delta: float) -> void:
	# Fungsi ini berjalan setiap frame layar untuk mengurus elemen visual
	_update_ui_bars()
	_update_crosshair_color()

func _physics_process(delta: float) -> void:
	# Fungsi ini berjalan setiap tick mesin fisika untuk kalkulasi fisis
	_apply_camera_rotation()
	_apply_gravity(delta)
	_handle_movement_and_sprint(delta)
	
	# Mengeksekusi seluruh pergerakan fisis yang telah dihitung di atas
	move_and_slide()


# ==========================================
# FUNGSI MODULAR (KODE YANG LEBIH MUDAH DIBACA)
# ==========================================

func _initialize_ui() -> void:
	# Sinkronisasi batas UI dengan data Global di awal permainan
	if sanity_bar != null and stamina_bar != null:
		sanity_bar.max_value = Global.max_sanity
		stamina_bar.max_value = Global.max_stamina

func _handle_mouse_capture(event: InputEvent) -> void:
	# Keluar dari mode tangkap mouse dengan tombol Cancel (contoh: ESC)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	# Mengembalikan mode tangkap mouse dengan klik kiri
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().root.set_input_as_handled()

func _try_interact() -> void:
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		
		if target.has_method("tune_string"):
			target.tune_string(20.0)
			Global.sanity_level = max(0.0, Global.sanity_level - 10.0)
			Global.sanity_changed.emit(Global.sanity_level)
			
		elif target.has_method("submit_password"):
			# Membuka terminal dan mengirimkan data pintu yang sedang ditatap
			terminal_ui.open_terminal(target)

func _update_ui_bars() -> void:
	# Memperbarui nilai UI secara konstan berdasarkan data Global
	if sanity_bar != null:
		sanity_bar.value = Global.sanity_level
	if stamina_bar != null:
		stamina_bar.value = Global.stamina_level

func _update_crosshair_color() -> void:
	if crosshair == null: 
		return # Menghentikan eksekusi jika crosshair UI belum dimuat
		
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		
		# GUARD CLAUSE: Memastikan target fisis benar-benar ada di memori
		if target != null:
			# Mencari method "submit_password" (bukan lagi "hack_wall")
			if target.has_method("tune_string") or target.has_method("submit_password"):
				# Mengubah warna crosshair menjadi merah (bisa berinteraksi)
				crosshair.color = Color(1, 0, 0) 
				return # Hentikan fungsi di sini agar baris bawah tidak tereksekusi
				
	# Mengembalikan warna ke putih jika tidak menatap objek interaktif
	crosshair.color = Color(1, 1, 1)

func _apply_camera_rotation() -> void:
	if _mouse_motion != Vector2.ZERO:
		# Rotasi tubuh karakter menoleh ke kiri/kanan (Sumbu Y)
		rotate_y(-_mouse_motion.x * MOUSE_SENSITIVITY)
		
		# Rotasi kamera mendongak ke atas/bawah (Sumbu X)
		camera.rotate_x(-_mouse_motion.y * MOUSE_SENSITIVITY)
		
		# Membatasi sudut pandang mendongak/menunduk agar leher tidak patah (clamp)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
		# Atur ulang memori pergerakan mouse menjadi nol untuk frame berikutnya
		_mouse_motion = Vector2.ZERO

func _apply_gravity(delta: float) -> void:
	# Menarik karakter ke bawah jika sedang tidak menyentuh lantai
	if not is_on_floor():
		velocity.y -= gravity * delta

func _handle_movement_and_sprint(delta: float) -> void:
	# Menerima input WASD dari keyboard
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Mengubah arah relatif terhadap arah tubuh karakter menghadap
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed = BASE_SPEED
	
	# Kondisi Sprint: Tombol ditekan, stamina tersedia, dan karakter sedang bergerak
	if Input.is_action_pressed("sprint") and Global.stamina_level > 0 and direction != Vector3.ZERO:
		current_speed = SPRINT_SPEED
		Global.is_sprinting = true
		Global.stamina_level = max(0.0, Global.stamina_level - (25.0 * delta)) 
	else:
		Global.is_sprinting = false

	# Mengaplikasikan kecepatan pada sumbu X dan Z
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		# Melakukan pengereman perlahan saat tidak ada input ditekan
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
