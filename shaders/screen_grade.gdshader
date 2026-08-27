// 螢幕分級：假性移軸（上下帶狀柔焦，5 taps）＋暗角＋觀測去彩度＋通關暖調＋閃光。
// Compatibility/WebGL2 相容；Web Low 以 blur_strength=0 關閉柔焦（保留暗角與分級）。
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_strength : hint_range(0.0, 4.0) = 2.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.30;
uniform float observe_mix : hint_range(0.0, 1.0) = 0.0;
uniform float warm_mix : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	// 帶狀柔焦：底部帶較寬（前景）、頂部帶較窄（遠景）
	float band = max(smoothstep(0.66, 1.0, uv.y) * 1.2, smoothstep(0.26, 0.0, uv.y));
	vec2 px = SCREEN_PIXEL_SIZE * blur_strength * band;
	vec3 col = texture(screen_tex, uv).rgb * 0.42;
	col += texture(screen_tex, uv + vec2(px.x, px.y)).rgb * 0.145;
	col += texture(screen_tex, uv + vec2(-px.x, px.y)).rgb * 0.145;
	col += texture(screen_tex, uv + vec2(px.x, -px.y)).rgb * 0.145;
	col += texture(screen_tex, uv + vec2(-px.x, -px.y)).rgb * 0.145;
	// 觀測模式：去彩度＋霧青冷調
	float g = dot(col, vec3(0.333));
	vec3 obs = mix(col, vec3(g) * vec3(0.74, 0.90, 1.02), 0.75);
	col = mix(col, obs, observe_mix);
	// 通關後：暖調擴大
	col = mix(col, col * vec3(1.09, 1.00, 0.86) + vec3(0.03, 0.015, 0.0), warm_mix);
	// 暗角
	float d = distance(uv, vec2(0.5, 0.46));
	col *= 1.0 - vignette * smoothstep(0.34, 0.78, d);
	// 演出閃光
	col = mix(col, vec3(0.93, 0.96, 0.92), flash);
	COLOR = vec4(col, 1.0);
}
