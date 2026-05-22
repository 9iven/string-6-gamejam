extends StaticBody3D

var unique_material: StandardMaterial3D
var visual_node: GeometryInstance3D

# ==========================================
# KONFIGURASI WARNA (DATA-DRIVEN)
# ==========================================
const TYPE_COLORS := {
	"trap": Color(1.0, 0.1, 0.1), # Merah Terang (Jebakan yang menguras sanity)
	"fake": Color(0.8, 0.0, 0.0), # Merah Gelap (Tembok buntu atau rute salah)
	"real": Color(0.2, 0.8, 0.6), # Hijau Lembut (Aman dan tidak menyakiti mata)
	"exit": Color(1.0, 0.8, 0.0)  # Kuning Emas
}

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
	
	# SOLUSI MATA LELAH: Menurunkan pengali pendaran dari 3.0 menjadi 1.5
	unique_material.emission_energy_multiplier = 0.1
	
	visual_node.material_override = unique_material

func _find_visual_node(node: Node) -> GeometryInstance3D:
	if node is GeometryInstance3D: return node
	for child in node.get_children():
		var result := _find_visual_node(child)
		if result: return result
	return null

# ==========================================
# KENDALI ANIMASI VISUAL (TWEEN)
# ==========================================
func set_reveal_state(is_revealed: bool) -> void:
	if not unique_material or not has_meta("door_type"): return

	var type: String = get_meta("door_type")
	var tween := create_tween()

	if is_revealed:
		unique_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		# KOREKSI VISIBILITAS: Semua tipe pintu kini diproses untuk memancarkan warna
		if TYPE_COLORS.has(type):
			tween.tween_property(unique_material, "emission", TYPE_COLORS[type], 0.3) 
			
			# Tembok buntu (fake) memiliki tingkat transparansi yang sedikit lebih tinggi
			var target_alpha: float = 0.4 if type == "fake" else 0.8
			tween.tween_property(unique_material, "albedo_color:a", target_alpha, 0.3)
		else:
			tween.kill()
	else:
		tween.tween_property(unique_material, "emission", Color.BLACK, 0.4)
		tween.tween_property(unique_material, "albedo_color:a", 1.0, 0.4)
		tween.tween_callback(func(): unique_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED)

# ==========================================
# MEKANISME DESTRUKSI FISIS
# ==========================================
func fade_and_destroy() -> void:
	var collider = get_node_or_null("CollisionShape3D")
	if collider:
		collider.set_deferred("disabled", true)

	var tween = create_tween()
	
	# FASE 1: Dinding tergencet menjadi satu benang vertikal tipis
	tween.set_parallel(true)
	tween.tween_property(self, "scale:x", 0.02, 0.3).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "scale:z", 0.02, 0.3).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "scale:y", 1.5, 0.3).set_trans(Tween.TRANS_ELASTIC)
	
	# FASE 2: Benang ditarik ke bawah hingga menyusut dan hilang
	tween.chain().tween_property(self, "scale:y", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	
	# Menghapus node dari memori
	tween.tween_callback(self.queue_free)
