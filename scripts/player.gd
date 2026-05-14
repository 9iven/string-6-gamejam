extends CharacterBody3D

# === VARIABEL KONFIGURASI ===
const BASE_SPEED = 5.0
const SPRINT_SPEED = 8.5
const MOUSE_SENSITIVITY = 0.003
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# === MEKANIK PENGLIHATAN (VISION FOCUS) ===
var is_focusing: bool = false
const FOCUS_SANITY_DRAIN_RATE = 5.0 # Jumlah sanity yang terkuras per detik
const NORMAL_FOV = 75.0
const FOCUS_FOV = 60.0 # Kamera sedikit "men-zoom" untuk efek fokus

# === REFERENSI NODE ===
@onready var camera = $Camera3D
@onready var interact_ray = $Camera3D/RayCast3D
@onready var vision_light = $Camera3D/SpotLight3D

# Parameter Cahaya
const NORMAL_LIGHT_ENERGY = 1.0
const FOCUS_LIGHT_ENERGY = 3.5 # Cahaya menjadi jauh lebih terang saat fokus
const NORMAL_LIGHT_RANGE = 15.0
const FOCUS_LIGHT_RANGE = 25.0 # Jarak pandang menembus kegelapan lebih jauh

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
	collision_mask = 3 
	interact_ray.collision_mask = 3
	
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
	
	# Mendengarkan tombol spasi untuk masuk ke mode fokus
# Mendengarkan tombol spasi untuk masuk ke mode fokus
	if event.is_action_pressed("ui_accept"): 
		is_focusing = true
		# Memanggil fungsi set_reveal_state(true) ke seluruh pintu di labirin
		get_tree().call_group("doors", "set_reveal_state", true)
		
	elif event.is_action_released("ui_accept"):
		is_focusing = false
		# Mengembalikan seluruh pintu ke wujud aslinya
		get_tree().call_group("doors", "set_reveal_state", false)

func _process(delta: float) -> void:
	# Fungsi ini berjalan setiap frame layar untuk mengurus elemen visual
	_update_ui_bars()
	_update_crosshair_color()
	_handle_vision_focus(delta) # Memanggil sistem fokus setiap frame

# --- FUNGSI BARU UNTUK FOKUS ---
func _handle_vision_focus(delta: float) -> void:
	if is_focusing and Global.sanity_level > 0:
		# 1. Kuras sanity secara perlahan
		Global.sanity_level = max(0.0, Global.sanity_level - (FOCUS_SANITY_DRAIN_RATE * delta))
		
		# 2. Efek Kamera: Zoom in (bidang pandang menyempit)
		camera.fov = lerp(camera.fov, FOCUS_FOV, 8.0 * delta)
		
		# 3. Efek Cahaya: Meningkatkan intensitas dan jarak terang
		if vision_light != null:
			vision_light.light_energy = lerp(vision_light.light_energy, FOCUS_LIGHT_ENERGY, 8.0 * delta)
			vision_light.spot_range = lerp(vision_light.spot_range, FOCUS_LIGHT_RANGE, 8.0 * delta)
			
	else:
		# Jika spasi dilepas atau sanity habis, kembalikan kamera ke normal
		camera.fov = lerp(camera.fov, NORMAL_FOV, 8.0 * delta)
		
		# Mengembalikan pencahayaan ke redup
		if vision_light != null:
			vision_light.light_energy = lerp(vision_light.light_energy, NORMAL_LIGHT_ENERGY, 8.0 * delta)
			vision_light.spot_range = lerp(vision_light.spot_range, NORMAL_LIGHT_RANGE, 8.0 * delta)

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
			
		elif target.has_meta("door_type"):
			var type = target.get_meta("door_type")
			
			if type == "real":
				Global.sanity_level = max(0.0, Global.sanity_level - 5.0)
				_check_monster_trigger() # Memicu hitung mundur monster
				if target.has_method("fade_and_destroy"):
					target.fade_and_destroy() 
				
			elif type == "trap":
				Global.sanity_level = max(0.0, Global.sanity_level - 15.0)
				Global.stamina_level = max(0.0, Global.stamina_level - 30.0)
				_check_monster_trigger()
				if target.has_method("fade_and_destroy"):
					target.fade_and_destroy()
				
			elif type == "fake":
				Global.sanity_level = max(0.0, Global.sanity_level - 2.0)
				print("Pintu macet atau ini hanyalah sebuah dinding.")

			# KOREKSI: Tambahkan blok untuk pintu Exit
			elif type == "exit":
				if terminal_ui != null:
					terminal_ui.open_terminal(target)

func _update_ui_bars() -> void:
	# Memperbarui nilai UI secara konstan berdasarkan data Global
	if sanity_bar != null:
		sanity_bar.value = Global.sanity_level
	if stamina_bar != null:
		stamina_bar.value = Global.stamina_level

func _update_crosshair_color() -> void:
	if crosshair == null: return 
		
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		if target != null:
			# KOREKSI: Gunakan metadata door_type sebagai filter deteksi
			if target.has_method("tune_string") or target.has_meta("door_type"):
				crosshair.color = Color(1, 0, 0) 
				return 
				
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
		
func _check_monster_trigger() -> void:
	Global.solved_doors += 1
	if Global.solved_doors >= 5 and not Global.monster_spawned:
		Global.monster_spawned = true
		# Memanggil fungsi di level_manager melalui sistem group
		get_tree().call_group("level_manager", "spawn_monster")
