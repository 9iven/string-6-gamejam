extends StaticBody3D

var unique_material: StandardMaterial3D
var visual_node: GeometryInstance3D

func _ready() -> void:
	visual_node = _find_visual_node(self)
	if not visual_node: return
	
	var mat: Material = null
	if visual_node is MeshInstance3D:
		mat = visual_node.get_active_material(0)
	elif "material" in visual_node:
		mat = visual_node.get("material")
		
	unique_material = mat.duplicate() if (mat and mat is StandardMaterial3D) else StandardMaterial3D.new()
	
	if not mat:
		unique_material.albedo_color = Color(0.6, 0.6, 0.6)
		
	unique_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	unique_material.emission_enabled = true
	unique_material.emission = Color.BLACK
	unique_material.emission_energy_multiplier = 3.0 
	
	visual_node.material_override = unique_material

func _find_visual_node(node: Node) -> GeometryInstance3D:
	if node is GeometryInstance3D: return node
	for child in node.get_children():
		var result := _find_visual_node(child)
		if result: return result
	return null

# ==========================================
# KENDALI ANIMASI VISUAL (KHUSUS EXIT)
# ==========================================
func set_reveal_state(is_revealed: bool) -> void:
	if not unique_material: return
	var tween := create_tween()

	if is_revealed:
		unique_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Pintu keluar secara absolut menggunakan warna Emas/Kuning
		tween.tween_property(unique_material, "emission", Color(1.0, 0.8, 0.0), 0.3) 
		tween.tween_property(unique_material, "albedo_color:a", 0.9, 0.3)
	else:
		tween.tween_property(unique_material, "emission", Color.BLACK, 0.4)
		tween.tween_property(unique_material, "albedo_color:a", 1.0, 0.4)
		tween.tween_callback(func(): unique_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED)

# ==========================================
# VALIDASI TERMINAL
# ==========================================
func submit_password(input_string: String) -> bool:
	if has_meta("password") and input_string == get_meta("password"):
		_trigger_victory_sequence()
		return true 
	return false

func _trigger_victory_sequence() -> void:
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision: collision.set_deferred("disabled", true)

	if unique_material:
		unique_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var tween := create_tween()
		tween.tween_property(unique_material, "albedo_color:a", 0.0, 1.0)
		# Menghancurkan objek setelah animasi pudar selesai
		tween.tween_callback(func(): queue_free())
	else:
		queue_free()
