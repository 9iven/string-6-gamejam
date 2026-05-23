extends StaticBody3D

# Parameter export memungkinkan modifikasi nilai per objek melalui panel Inspector
@export var target_frequency: float = 100.0
var current_frequency: float = 0.0

func _ready() -> void:
	# [OPTIMASI] Validasi keamanan struktur node untuk pemula
	if not has_node("CollisionShape3D"):
		print("Peringatan [TunableObject]: Objek ini tidak memiliki CollisionShape3D! RayCast dari Player tidak akan bisa mendeteksinya.")

# Fungsi ini dipanggil secara eksternal oleh script Player.gd
func tune_string(amount: float) -> void:
	current_frequency += amount
	
	# Indikator log untuk memudahkan proses debugging
	print("Sistem [TunableObject]: Disetem. Frekuensi saat ini: ", current_frequency, " / ", target_frequency)
	
	# Jika batas frekuensi tercapai, picu manipulasi dimensi
	if current_frequency >= target_frequency:
		trigger_dimension_shift()

func trigger_dimension_shift() -> void:
	print("Sistem [TunableObject]: Target tercapai. Objek dihapus dari memori.")
	
	# Hapus objek dari memori sistem (menghancurkan objek di dalam game)
	queue_free()
