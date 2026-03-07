shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float scanline_size : hint_range(1.0, 16.0) = 4.0;

void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV);

	// Base scanlines on the native render resolution, not screen pixels,
	// so they stay visible even at low viewport resolutions when upscaled.
	float native_height = float(textureSize(screen_texture, 0).y);
	float scanline = mod(floor(SCREEN_UV.y * native_height / scanline_size), 2.0);
	color.rgb *= 1.0 - scanline * scanline_intensity;

	COLOR = color;
}
