shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV);

	float scanline = mod(floor(FRAGCOORD.y), 2.0);
	color.rgb *= 1.0 - scanline * scanline_intensity;

	COLOR = color;
}
