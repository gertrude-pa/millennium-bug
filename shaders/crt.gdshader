shader_type canvas_item;

// Cheap CRT: scanlines + barrel curvature + chromatic aberration + vignette.
// Applied as a fullscreen overlay on a high-layer CanvasLayer.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.25;
uniform float curvature : hint_range(0.0, 0.2) = 0.06;
uniform float chromatic : hint_range(0.0, 0.01) = 0.0018;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	// Barrel distortion.
	float r2 = dot(c, c);
	uv = 0.5 + c * (1.0 + curvature * r2);

	// If outside the screen after distortion, render black (CRT bezel).
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Chromatic aberration.
		float rc = texture(screen_tex, uv + vec2(chromatic, 0.0)).r;
		float gc = texture(screen_tex, uv).g;
		float bc = texture(screen_tex, uv - vec2(chromatic, 0.0)).b;
		vec3 col = vec3(rc, gc, bc);

		// Scanlines.
		float line = sin(uv.y * SCREEN_PIXEL_SIZE.y * 3.14159 * 0.5 * (1.0 / SCREEN_PIXEL_SIZE.y));
		col *= 1.0 - scanline_strength * (0.5 + 0.5 * line);

		// Vignette.
		float vig = smoothstep(0.8, 0.2, length(c));
		col *= mix(1.0 - vignette, 1.0, vig);

		COLOR = vec4(col, 1.0);
	}
}
