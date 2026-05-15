extends CharacterBody3D

# ==========================================
# KONSTANTA & PARAMETER FISIS
# ==========================================
const BASE_SPEED := 5.0
const SPRINT_SPEED := 8.5
const MOUSE_SENSITIVITY := 0.003
const FOCUS_SANITY_DRAIN := 5.0
const SPRINT_STAMINA_DRAIN := 25.0

const NORMAL_FOV := 75.0
const FOCUS_FOV := 60.0
const NORMAL_LIGHT_ENERGY := 1.0
const FOCUS_LIGHT_ENERGY := 3.5
const NORMAL_LIGHT_RANGE := 15.0
const FOCUS_LIGHT_RANGE := 25.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ==========================================
# STATE & REFERENSI NODE
# ==========================================
var is_focusing := false
var _mouse_motion := Vector2.ZERO

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/RayCast3D
@onready var vision_light: SpotLight3D = $Camera3D/SpotLight3D
@onready var crosshair: ColorRect = %Crosshair
@onready var sanity_bar: ProgressBar = %SanityBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var terminal_ui: CanvasLayer = $TerminalUI

@export var jumpscare_texture: Texture2D

# ==========================================
# SIKLUS UTAMA
# ==========================================
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interact_ray.add_exception(self)
	_initialize_ui()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().root.set_input_as_handled()

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		_mouse_motion += event.relative

	if event.is_action_pressed("interact"):
		_try_interact()
	
	if event.is_action_pressed("ui_accept"): 
		is_focusing = true
		get_tree().call_group("doors", "set_reveal_state", true)
	elif event.is_action_released("ui_accept"):
		is_focusing = false
		get_tree().call_group("doors", "set_reveal_state", false)

func _process(delta: float) -> void:
	_update_ui()
	_update_crosshair()
	_handle_vision_focus(delta)

func _physics_process(delta: float) -> void:
	_apply_camera_rotation()
	if not is_on_floor():
		velocity.y -= gravity * delta
	_handle_movement(delta)
	move_and_slide()

# ==========================================
# LOGIKA SISTEM (MODULAR)
# ==========================================
func _initialize_ui() -> void:
	if sanity_bar and stamina_bar:
		sanity_bar.max_value = Global.max_sanity
		stamina_bar.max_value = Global.max_stamina

func _update_ui() -> void:
	if sanity_bar: sanity_bar.value = Global.sanity_level
	if stamina_bar: stamina_bar.value = Global.stamina_level

func _update_crosshair() -> void:
	if not crosshair: return 
	var is_targeting = false
	
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		is_targeting = target and (target.has_method("tune_string") or target.has_meta("door_type"))
	
	# Implementasi Ternary Operator untuk memangkas baris kondisional
	crosshair.color = Color.RED if is_targeting else Color.WHITE

func _handle_vision_focus(delta: float) -> void:
	# Menyiapkan variabel target lokal untuk menghindari pemanggilan 'else' yang redundan
	var target_fov := NORMAL_FOV
	var target_energy := NORMAL_LIGHT_ENERGY
	var target_range := NORMAL_LIGHT_RANGE

	if is_focusing and Global.sanity_level > 0:
		Global.sanity_level = max(0.0, Global.sanity_level - (FOCUS_SANITY_DRAIN * delta))
		target_fov = FOCUS_FOV
		target_energy = FOCUS_LIGHT_ENERGY
		target_range = FOCUS_LIGHT_RANGE

	camera.fov = lerp(camera.fov, target_fov, 8.0 * delta)
	if vision_light:
		vision_light.light_energy = lerp(vision_light.light_energy, target_energy, 8.0 * delta)
		vision_light.spot_range = lerp(vision_light.spot_range, target_range, 8.0 * delta)

func _apply_camera_rotation() -> void:
	if _mouse_motion == Vector2.ZERO: return
	
	rotate_y(-_mouse_motion.x * MOUSE_SENSITIVITY)
	camera.rotate_x(-_mouse_motion.y * MOUSE_SENSITIVITY)
	
	# Menggunakan nilai radian absolut fisis (-80 hingga 80 derajat)
	camera.rotation.x = clampf(camera.rotation.x, -1.39626, 1.39626) 
	_mouse_motion = Vector2.ZERO

func _handle_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed = BASE_SPEED
	
	Global.is_sprinting = Input.is_action_pressed("sprint") and Global.stamina_level > 0 and direction != Vector3.ZERO
	
	if Global.is_sprinting:
		speed = SPRINT_SPEED
		Global.stamina_level = max(0.0, Global.stamina_level - (SPRINT_STAMINA_DRAIN * delta)) 

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func _try_interact() -> void:
	# Return awal (Guard Clause) jika tidak menabrak apa-apa
	if not interact_ray.is_colliding(): return
	var target = interact_ray.get_collider()
	
	if target.has_method("tune_string"):
		target.tune_string(20.0)
		Global.sanity_level = max(0.0, Global.sanity_level - 10.0)
	elif target.has_meta("door_type"):
		# Implementasi Match Statement untuk keterbacaan yang lebih akademis
		match target.get_meta("door_type"):
			"real":
				Global.sanity_level = max(0.0, Global.sanity_level - 5.0)
				_trigger_door_hack(target)
			"trap":
				Global.sanity_level = max(0.0, Global.sanity_level - 15.0)
				Global.stamina_level = max(0.0, Global.stamina_level - 30.0)
				_trigger_door_hack(target)
			"fake":
				Global.sanity_level = max(0.0, Global.sanity_level - 2.0)
			"exit":
				if terminal_ui: terminal_ui.open_terminal(target)

func _trigger_door_hack(target: Node) -> void:
	# Logika terdekopel (decoupled logic) untuk proses peretasan pintu
	Global.solved_doors += 1
	if Global.solved_doors >= 5 and not Global.monster_spawned:
		Global.monster_spawned = true
		get_tree().call_group("level_manager", "spawn_monster")
		
	if target.has_method("fade_and_destroy"):
		target.fade_and_destroy()
		
# ==========================================
# EFEK VISUAL (JUMPSCARE)
# ==========================================
func show_jumpscare() -> void:
	if not jumpscare_texture: 
		print("Peringatan: Jumpscare Texture belum diisi di Inspector!")
		return
		
	# Menginstansiasi layer kanvas baru secara prosedural (berada di atas semua UI)
	var canvas := CanvasLayer.new()
	canvas.layer = 10 
	add_child(canvas)
	
	# Menginstansiasi kotak tekstur untuk menampilkan file PNG
	var tex_rect := TextureRect.new()
	tex_rect.texture = jumpscare_texture
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(tex_rect)
	
	# Memutar animasi pudar (fade-out) selama 1.5 detik
	var tween := create_tween()
	tween.tween_property(tex_rect, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_EXPO)
	
	# Callback untuk menghapus seluruh elemen UI ini dari memori setelah animasi selesai
	tween.tween_callback(func(): canvas.queue_free())
