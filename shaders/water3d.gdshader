// 潮霧群島水面：雙層捲動噪聲＋高光閃點＋假 Fresnel。無 SSR、無折射。
// Web Low：second_layer=0 降為單層取樣。
shader_type spatial;
render_mode specular_disabled, cull_back;

uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec4 deep_color : source_color = vec4(0.12, 0.29, 0.39, 1.0);
uniform vec4 lift_color : source_color = vec4(0.18, 0.42, 0.54, 1.0);
uniform float second_layer : hint_range(0.0, 1.0) = 1.0;
uniform float sparkle : hint_range(0.0, 1.5) = 1.0;
uniform float scroll_scale = 0.05;

void fragment() {
	vec2 uv1 = UV * 0.24 + vec2(TIME * scroll_scale, TIME * scroll_scale * 0.6);
	vec2 uv2 = UV * 0.41 - vec2(TIME * scroll_scale * 0.8, TIME * scroll_scale * 0.5);
	float n = texture(noise_tex, uv1).r;
	n = mix(n, n * 0.55 + texture(noise_tex, uv2).r * 0.45, second_layer);
	vec3 col = mix(deep_color.rgb, lift_color.rgb, n * 0.75);
	// 高光閃點（潮濕的鹽光）
	float sp = smoothstep(0.80, 0.88, n) * sparkle;
	col += vec3(0.50, 0.68, 0.68) * sp;
	// 假 Fresnel：掠射角泛出霧色
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col += vec3(0.16, 0.22, 0.24) * fresnel;
	ALBEDO = col;
	ROUGHNESS = 0.4;
}
