extends StaticBody3D

var unique_material: StandardMaterial3D
var original_color: Color = Color.WHITE

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	
	add_to_group("doors")
	
	
	var mesh_instance = _find_mesh_instance(self)
	if mesh_instance != null:
		var mat = mesh_instance.get_active_material(0)
		
		# FALLBACK: Jika tidak ada material di editor, buat material baru secara dinamis
		if mat != null:
			unique_material = mat.duplicate()
		else:
			unique_material = StandardMaterial3D.new()
			unique_material.albedo_color = Color(0.6, 0.6, 0.6) # Warna beton abu-abu default
			
		# Konfigurasi material untuk animasi
		unique_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		unique_material.emission_enabled = true
		unique_material.emission = Color.BLACK
		unique_material.emission_energy_multiplier = 3.0 # Memastikan cahaya pendaran sangat terang
		
		mesh_instance.material_override = unique_material
		original_color = unique_material.albedo_color

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result != null: return result
	return null

# ==========================================
# FUNGSI VALIDASI SANDI (Hanya Final Exit)
# ==========================================
func submit_password(input_string: String) -> bool:
	if has_meta("password"):
		var required_password = get_meta("password")
		if input_string == required_password:
			fade_and_destroy()
			return true 
	return false

# ==========================================
# FUNGSI ANIMASI PUDAR & FOKUS
# ==========================================
func fade_and_destroy() -> void:
	var collision = get_node_or_null("CollisionShape3D")
	if collision != null: collision.set_deferred("disabled", true)

	# Validasi null pointer yang aman
	if unique_material != null:
		unique_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var tween = create_tween()
		tween.tween_property(unique_material, "albedo_color:a", 0.0, 1.0)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func set_reveal_state(is_revealed: bool) -> void:
	if not has_meta("door_type") or unique_material == null: return

	var type = get_meta("door_type")
	
	# Hanya membuat SATU tween untuk dipakai secara efisien
	var tween = create_tween()

	if is_revealed:
		unique_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		if type == "fake":
			tween.tween_property(unique_material, "albedo_color:a", 0.2, 0.3)
		elif type == "trap":
			tween.tween_property(unique_material, "emission", Color(1.0, 0.0, 0.0), 0.3) 
			tween.tween_property(unique_material, "albedo_color:a", 0.8, 0.3)
		elif type == "real":
			tween.tween_property(unique_material, "emission", Color(0.0, 1.0, 0.5), 0.3) 
			tween.tween_property(unique_material, "albedo_color:a", 0.8, 0.3)
		elif type == "exit":
			tween.tween_property(unique_material, "emission", Color(1.0, 0.8, 0.0), 0.3) 
			tween.tween_property(unique_material, "albedo_color:a", 0.9, 0.3)
		else:
			tween.kill() # Membunuh tween jika tipe tidak dikenali agar tidak error
	else:
		# Menggunakan variabel tween yang sama, tidak membuat t_back baru
		tween.tween_property(unique_material, "emission", Color.BLACK, 0.4)
		tween.tween_property(unique_material, "albedo_color:a", 1.0, 0.4)
		tween.tween_callback(func(): unique_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED)
