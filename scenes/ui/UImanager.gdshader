shader_type canvas_item;

// Mengambil apa yang sedang dirender di layar saat ini
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
// Variabel untuk mengendalikan seberapa parah distorsi yang terjadi
uniform float distortion_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Memberikan efek gelombang (wobble) berdasarkan waktu dan intensitas
    uv.x += sin(uv.y * 10.0 + TIME * 5.0) * (0.01 * distortion_intensity);
    uv.y += cos(uv.x * 10.0 + TIME * 3.0) * (0.01 * distortion_intensity);
    
    vec4 color = texture(screen_texture, uv);
    COLOR = color;
}