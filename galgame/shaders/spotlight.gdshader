shader_type canvas_item;

uniform vec2 spotlight_center = vec2(0.5, 0.5);
uniform vec2 spotlight_radius = vec2(0.0, 0.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	float mask = 1.0;
	
	// 只在半徑 > 0 時才計算聚光燈效果（避免除以零）
	if (spotlight_radius.x > 0.0 && spotlight_radius.y > 0.0) {
		vec2 diff = (uv - spotlight_center) / spotlight_radius;
		float dist = length(diff);
		mask = smoothstep(0.6, 1.0, dist);
	}
	
	COLOR.rgb = vec3(0.0);
	COLOR.a = darkness * mask;
}
