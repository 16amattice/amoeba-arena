shader_type canvas_item;

// This is actual screen-space blur, not a transparent flat color.
// Godot generates mipmaps of the back-buffer; extra taps soften high-contrast
// world geometry beneath the glass while preserving the moving arena.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 glass_tint : source_color = vec4(0.04, 0.10, 0.14, 0.78);
uniform float blur_lod : hint_range(0.0, 5.0) = 3.4;
uniform float grain : hint_range(0.0, 1.0) = 0.12;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 texel = SCREEN_PIXEL_SIZE * 3.0;
    vec3 blurred = textureLod(screen_texture, uv, blur_lod).rgb * 0.38;
    blurred += textureLod(screen_texture, uv + vec2(texel.x, 0.0), blur_lod).rgb * 0.155;
    blurred += textureLod(screen_texture, uv - vec2(texel.x, 0.0), blur_lod).rgb * 0.155;
    blurred += textureLod(screen_texture, uv + vec2(0.0, texel.y), blur_lod).rgb * 0.155;
    blurred += textureLod(screen_texture, uv - vec2(0.0, texel.y), blur_lod).rgb * 0.155;

    float noise = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
    vec3 color = mix(blurred, glass_tint.rgb, glass_tint.a);
    color += (noise - 0.5) * grain * 0.035;
    COLOR = vec4(color, 1.0);
}
