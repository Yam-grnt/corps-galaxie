// Nuage de points lumineux. Chaque sommet porte sa couleur et, s'il représente un enfant, le rayon de cet enfant (CUSTOM0.a).
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled;

uniform float cnt = 1000.0;   // nombre de points de ce niveau de détail
uniform float boost = 1.0;    // compensation quand on n'affiche qu'une partie des points
varying vec3 col;

void vertex() {
	vec4 w = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float d = max(length(w.xyz), 0.02);
	float s = length(MODEL_MATRIX[0].xyz);
	float f = abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y * 0.5;
	float dc = max(length((MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz), 0.03);
	float prn = s / dc * f;   // rayon apparent du nuage entier, en pixels
	float a = boost * min(1.0, sqrt(0.012 * (3.14 * prn * prn + 1.0) / cnt));   // les amas denses ne virent pas au blanc
	float px;
	if (CUSTOM0.a > 0.0) {
		float pr = CUSTOM0.a * s / d * f;
		a *= 0.75 * mix(1.0, 0.3, smoothstep(6.0, 12.0, pr));
		px = clamp(2.0 * pr, 3.0, 19.0);
	} else {
		float pr = 0.0035 * s / d * f;
		px = clamp(2.0 * pr, 2.2, 5.0);
		a *= 0.5;
	}
	a *= smoothstep(0.03, 0.12, d);
	POINT_SIZE = px;
	col = CUSTOM0.rgb * a;
}

void fragment() {
	vec2 q = POINT_COORD * 2.0 - 1.0;
	float k = 1.0 - dot(q, q);
	if (k <= 0.0) {
		discard;
	}
	vec3 c = col * smoothstep(0.0, 0.55, k);
	ALBEDO = pow(c, vec3(2.2));
}
