shader_type canvas_item;

uniform float sanity_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float time_offset = 0.0;

void fragment() {
	vec2 uv = UV;

	// Distortion increases as sanity drops
	float distortion_strength = (1.0 - sanity_ratio) * 0.02;

	// Wavy distortion
	uv.x += sin(uv.y * 20.0 + time_offset * 3.0) * distortion_strength;
	uv.y += cos(uv.x * 15.0 + time_offset * 2.0) * distortion_strength * 0.5;

	vec4 color = texture(TEXTURE, uv);

	// Desaturation as sanity drops
	float desat = (1.0 - sanity_ratio) * 0.5;
	float grey = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(color.rgb, vec3(grey), desat);

	// Red/purple tint when low sanity
	if (sanity_ratio < 0.5) {
		float tint_strength = (0.5 - sanity_ratio) * 0.3;
		color.rgb = mix(color.rgb, vec3(0.6, 0.1, 0.2), tint_strength);
	}

	// Vignette effect
	float vignette_strength = (1.0 - sanity_ratio) * 0.4;
	float vignette = distance(UV, vec2(0.5));
	vignette = smoothstep(0.3, 0.7, vignette);
	color.rgb = mix(color.rgb, vec3(0.0), vignette * vignette_strength);

	COLOR = color;
}
