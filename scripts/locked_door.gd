extends StaticBody3D

var unique_material: StandardMaterial3D
var visual_node: GeometryInstance3D

# OPTIMASI: Data-Driven Design menggunakan Dictionary
# Pemetaan warna statis dipisahkan dari logika fungsional
const TYPE_COLORS := {
	"trap": Color(1.0, 0.0, 0.0), # Merah
	"real": Color(0.0, 1.0, 0.5), # Hijau/Cyan
	"exit": Color(1.0, 0.8, 0.0)  # Kuning/Emas
}

func _ready() -> void:
	visual_node = _find_visual_node(self)
	if not visual_node: return
	
	var mat: Material = null
	if visual_node is MeshInstance3D:
		mat = visual_node.get_active_material(0)
	elif "material" in visual_node:
		mat = visual_node.get("material")
		
	# Deklarasi kondisional sebaris (Ternary Operator)
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
# KENDALI ANIMASI (TWEEN)
# ==========================================
func set_reveal_state(is_revealed: bool) -> void:
	if not unique_material or not has_meta("door_type"): return

	var type: String = get_meta("door_type")
	var tween := create_tween()

	if is_revealed:
		unique_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if type == "fake":
			tween.tween_property(unique_material, "albedo_color:a", 0.2, 0.3)
		# Evaluasi Dictionary (O(1) Time Complexity) menggantikan if-else berantai
		elif TYPE_COLORS.has(type):
			tween.tween_property(unique_material, "emission", TYPE_COLORS[type], 0.3) 
			tween.tween_property(unique_material, "albedo_color:a", 0.8, 0.3)
		else:
			tween.kill()
	else:
		tween.tween_property(unique_material, "emission", Color.BLACK, 0.4)
		tween.tween_property(unique_material, "albedo_color:a", 1.0, 0.4)
		tween.tween_callback(func(): unique_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED)

func fade_and_destroy() -> void:
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision: collision.set_deferred("disabled", true)

	# OPTIMASI: Deklarasi fungsi Lambda sebagai variabel (Callback Reusability)
	var destroy_logic := func():
		queue_free()
		get_tree().call_group("level_manager", "rebake_map")

	if unique_material:
		unique_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var tween := create_tween()
		tween.tween_property(unique_material, "albedo_color:a", 0.0, 1.0)
		tween.tween_callback(destroy_logic)
	else:
		destroy_logic.call()
