shader_type canvas_item;

// Full-screen post-processing: vignette, film grain, chromatic aberration,
// color grading (crushed blacks, warm highlights, cool shadows), scanlines.
// Applied on a top-level CanvasLayer over the entire game.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

// --- Vignette ---------------------------------------------------------
// Smoothstep(outer, inner, length): vig=1 at inner, 0 at outer.
// Intensity is how much of the original color survives near edges.
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.55;
uniform float vignette_softness  : hint_range(0.0, 1.0) = 0.45;
uniform vec3  vignette_color     : source_color = vec3(0.08, 0.04, 0.08);

// --- Chromatic aberration --------------------------------------------
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.0018;

// --- Film grain -------------------------------------------------------
uniform float grain_strength : hint_range(0.0, 0.5) = 0.04;
uniform float grain_speed    : hint_range(0.0, 10.0) = 2.0;

// --- Color grading ----------------------------------------------------
uniform float black_crush    : hint_range(0.0, 0.5) = 0.0;
uniform float highlight_warm : hint_range(0.0, 1.0) = 0.25;
uniform float shadow_cool    : hint_range(0.0, 1.0) = 0.15;
uniform float saturation     : hint_range(0.0, 2.0) = 1.15;
uniform float contrast       : hint_range(0.5, 2.0) = 1.08;
uniform float brightness_boost : hint_range(0.0, 1.0) = 0.08;

// --- Scanlines (subtle) ----------------------------------------------
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.0;
uniform float scanline_density  : hint_range(50.0, 600.0) = 320.0;

// Pseudo-random noise for grain
float hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - 0.5;

	// --- Chromatic aberration: sample RGB at slightly offset UVs -----
	float ca = chromatic_aberration * length(centered) * 2.0;
	vec3 col;
	col.r = texture(screen_tex, uv + centered * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - centered * ca).b;

	// --- Color grading: lift shadows cool, push highlights warm ------
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 cool_tint = vec3(0.55, 0.72, 1.00);
	vec3 warm_tint = vec3(1.00, 0.82, 0.55);
	float shadow_mask = 1.0 - smoothstep(0.0, 0.5, luma);
	float highlight_mask = smoothstep(0.5, 1.0, luma);
	col = mix(col, col * cool_tint, shadow_mask * shadow_cool);
	col = mix(col, col * warm_tint, highlight_mask * highlight_warm);

	// Black crush (deepen the darks) — zero by default now so we don't
	// double-darken the gothic palette
	if (black_crush > 0.001) {
		col = max(col - black_crush, vec3(0.0)) / (1.0 - black_crush);
	}

	// Brightness lift
	col += brightness_boost;

	// Contrast
	col = (col - 0.5) * contrast + 0.5;

	// Saturation
	float new_luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(new_luma), col, saturation);

	// --- Vignette -----------------------------------------------------
	// vig = 1 at center, 0 at corner (smoothstep is reversed)
	float vig = smoothstep(0.85, vignette_softness, length(centered));
	// Blend toward vignette_color only in the OUTER area. Clamp intensity
	// so we can never dye the whole screen if someone fat-fingers uniforms.
	float tint = clamp((1.0 - vig) * vignette_intensity, 0.0, 1.0);
	col = mix(col, vignette_color, tint);

	// --- Scanlines ----------------------------------------------------
	float scan = sin(uv.y * scanline_density) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * (1.0 - scan);

	// --- Grain --------------------------------------------------------
	float noise = hash(uv * 1024.0 + TIME * grain_speed);
	col += (noise - 0.5) * grain_strength;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
