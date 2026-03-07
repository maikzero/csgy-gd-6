// player.gdshader
shader_type canvas_item;
render_mode blend_mix;

// Flash intensity - 0 = normal, 1 = full flash color
uniform float hit_effect : hint_range(0, 1) = 0.0;

// What color to flash (white by default, change to red if you want)
uniform vec4 hit_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    // Get the original pixel color from the sprite
    vec4 original_color = texture(TEXTURE, UV);
    
    // Mix between original and hit color based on hit_effect
    vec4 final_color = mix(original_color, hit_color, hit_effect);
    
    // Keep original transparency
    COLOR.rgb = final_color.rgb;
    COLOR.a = original_color.a * COLOR.a;
}