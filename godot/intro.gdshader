// Nuage de l'introduction : un seul maillage de points qui se métamorphose d'une scène à l'autre.
// Chaque point porte toutes ses positions cibles ; le passage de l'une à l'autre est calculé ici, sans rien recalculer côté script.
//   VERTEX   : silhouette femme (repère du modèle)        CUSTOM0 : silhouette homme (xyz), graine (a)
//   CUSTOM1  : galaxie, dans le plan de son disque (xyz), graine (a)
//   CUSTOM2  : cellule (xyz), nature du point (a)          CUSTOM3 : atome (xyz), nature du point (a)
//   UV, UV2  : quatre graines de hasard
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled;

// Formes : 0 nuit étoilée, 1 galaxie, 2 poussière d'étoiles, 3 corps, 4 cellule, 5 atome
uniform int forme_a = 0;
uniform int forme_b = 0;
uniform float melange = 0.0;    // avancement du passage de a vers b (0 → 1, linéaire ; l'adoucissement est fait ici)
uniform int plongee = 0;         // +1 : on plonge (la forme de départ grossit et se dissout, l'autre naît petite) ; −1 : on remonte
uniform float temps = 0.0;
uniform float genre = 0.0;      // 0 femme, 1 homme (le corps se remodèle en glissant de l'un à l'autre)
uniform float fondu = 1.0;      // lumière générale
uniform float cnt = 30000.0;    // nombre de points
uniform float echelle_corps = 0.85;
varying vec3 col;

const vec3 BLANC = vec3(1.0, 0.93, 0.82);
const vec3 DORE = vec3(1.0, 0.76, 0.3);
const vec3 BLEU = vec3(0.22, 0.4, 1.0);
const vec3 CIEL = vec3(0.55, 0.75, 1.0);
const vec3 ROSE = vec3(1.0, 0.36, 0.5);
const vec3 ROUGE = vec3(1.0, 0.24, 0.2);

struct Pt {
	vec3 fem;
	vec4 hom;
	vec4 gal;
	vec4 cel;
	vec4 ato;
	vec4 g;
};

vec3 tourne_y(vec3 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

// Position (mètres, autour du centre de la scène), couleur, rayon du point (mètres) et lumière pour une forme donnée.
void forme(int f, Pt a, out vec3 p, out vec3 c, out float r, out float l) {
	float g0 = a.hom.a;
	float g1 = a.gal.a;
	if (f == 1) {
		// galaxie : le disque tourne lentement (un peu plus vite au centre), puis on l'incline vers le spectateur
		vec3 q = a.gal.xyz;
		float rr = length(q.xz);
		q = tourne_y(q, temps * (0.05 + 0.02 / (0.25 + rr)));
		float ci = cos(1.08);
		float si = sin(1.08);
		q = vec3(q.x, ci * q.y - si * q.z, si * q.y + ci * q.z);
		float cz = cos(0.3);
		float sz = sin(0.3);
		p = vec3(cz * q.x - sz * q.y, sz * q.x + cz * q.y, q.z);
		float coeur = smoothstep(0.3, 0.0, rr);
		c = mix(mix(BLEU, CIEL, a.g.x), BLANC, a.g.y * 0.6);
		c = mix(c, DORE, step(0.86, a.g.z) * 0.9);
		c = mix(c, ROSE, step(0.965, a.g.w));
		c = mix(c, mix(DORE, BLANC, 0.55), coeur);
		r = 0.0042 + 0.004 * step(0.97, a.g.z);
		l = 1.3 - 0.75 * coeur + 4.0 * step(0.97, a.g.z);
	} else if (f == 2) {
		// poussière d'étoiles : chaque grain tombe à son rythme en se balançant, et renaît en haut
		float h = 1.9;
		float y = mod(a.g.y * h + temps * (0.07 + 0.13 * a.g.w), h);
		p = vec3((a.g.x - 0.5) * 2.1 + 0.05 * sin(temps * 0.6 + g0 * 40.0), 0.95 - y, (a.g.z - 0.5) * 1.3 + 0.04 * cos(temps * 0.5 + g1 * 40.0));
		c = mix(DORE, BLANC, a.g.z * a.g.z);
		c = mix(c, CIEL, step(0.9, g1) * 0.7);
		float vif = step(g1, 0.16);
		r = 0.0035 + 0.004 * vif * a.g.w;
		l = (0.35 + 3.5 * vif) * smoothstep(0.0, 0.3, y) * smoothstep(h, h - 0.3, y);
	} else if (f == 3) {
		// corps debout : il respire (la cage thoracique se soulève), et le cœur bat en rose
		vec3 m = mix(a.fem, a.hom.xyz, genre);
		float thorax = exp(-pow((m.y - 0.34) / 0.2, 2.0));
		float souffle = sin(temps * 1.5708);
		m.xz *= 1.0 + 0.022 * thorax * souffle;
		m.y += 0.006 * souffle * smoothstep(0.0, 0.5, m.y);
		m += 0.004 * vec3(sin(temps * 1.1 + g0 * 50.0), sin(temps * 0.9 + g1 * 50.0), sin(temps * 1.3 + a.g.x * 50.0));
		p = m * echelle_corps;
		c = mix(BLANC, DORE, a.g.y * 0.55);
		c = mix(c, CIEL, step(0.78, a.g.z) * 0.8);
		float t = fract(temps * 1.1);
		float coup = exp(-t * 12.0) + 0.7 * exp(-abs(t - 0.3) * 16.0) * step(0.3, t);
		float coeur = smoothstep(0.13, 0.03, distance(m, vec3(0.03, 0.4, 0.03)));
		c = mix(c, ROSE, coeur);
		r = 0.0032 + 0.0025 * coeur;
		l = 0.45 * (0.9 + 0.12 * souffle) + coeur * (0.25 + 0.7 * coup);
	} else if (f == 4) {
		// cellule : membrane, noyau et organites, qui ondulent à peine
		vec3 q = tourne_y(a.cel.xyz, temps * 0.06);
		q *= 1.0 + 0.012 * sin(temps * 0.8 + q.y * 5.0 + q.x * 3.0);
		p = q;
		int k = int(a.cel.a + 0.5);
		r = 0.0032;
		if (k == 0) {            // membrane
			c = mix(BLEU, CIEL, a.g.x);
			l = 1.1;
		} else if (k == 1) {     // cytoplasme
			c = mix(BLEU, BLANC, 0.3);
			l = 0.5;
		} else if (k == 2) {     // enveloppe du noyau
			c = mix(ROSE, BLANC, 0.25 * a.g.y);
			l = 1.4;
		} else if (k == 3) {     // chromatine, nucléole
			c = mix(ROUGE, ROSE, a.g.x);
			l = 1.6;
		} else if (k == 4) {     // mitochondries
			c = mix(DORE, BLANC, 0.2 * a.g.z);
			l = 1.6;
		} else if (k == 5) {     // réticulum
			c = mix(CIEL, BLANC, 0.4);
			l = 0.9;
		} else {                 // vésicules
			c = mix(BLANC, DORE, 0.4);
			l = 1.8;
			r = 0.004;
		}
	} else if (f == 5) {
		// atome : un noyau serré, et l'électron comme un nuage de présence possible, qui scintille sans jamais tracer d'orbite
		int k = int(a.ato.a + 0.5);
		if (k == 2) {
			vec3 q = a.ato.xyz;
			q *= 1.0 + 0.04 * sin(temps * 0.7 + g0 * 30.0);
			p = tourne_y(q, temps * 0.04);
			float e = 0.5 + 0.5 * sin(temps * (1.5 + 5.0 * a.g.w) + g1 * 100.0);
			c = mix(BLEU, CIEL, a.g.y);
			c = mix(c, BLANC, step(0.9, a.g.z));
			r = 0.0032 + 0.002 * e;
			l = (0.2 + 2.2 * e * e * e) * (0.12 + 0.88 * smoothstep(0.05, 0.3, length(q)));
		} else {
			p = a.ato.xyz + 0.003 * vec3(sin(temps * 9.0 + g0 * 60.0), sin(temps * 8.0 + g1 * 60.0), sin(temps * 7.0 + a.g.x * 60.0));
			c = k == 0 ? mix(ROUGE, ROSE, 0.5 * a.g.x) : mix(DORE, BLANC, 0.5);
			r = 0.0045;
			l = 1.6;
		}
	} else {
		// nuit : presque tout est éteint, quelques étoiles veillent et dérivent à peine
		p = (a.g.xyz - 0.5) * vec3(3.0, 1.9, 1.5) + vec3(0.0, 0.05, -0.25);
		p.x += 0.02 * sin(temps * 0.2 + g0 * 20.0);
		float etoile = step(g1, 0.03);
		float grande = step(g1, 0.004);
		c = mix(BLANC, mix(CIEL, DORE, step(0.5, a.g.w)), 0.5 * g0);
		r = 0.006 + 0.008 * grande;
		l = etoile * (3.0 + 12.0 * grande) * (0.65 + 0.35 * sin(temps * (0.8 + 2.5 * a.g.w) + g0 * 90.0));
	}
}

void vertex() {
	Pt a;
	a.fem = VERTEX;
	a.hom = CUSTOM0;
	a.gal = CUSTOM1;
	a.cel = CUSTOM2;
	a.ato = CUSTOM3;
	a.g = vec4(UV, UV2);
	vec3 pa;
	vec3 ca;
	float ra;
	float la;
	forme(forme_a, a, pa, ca, ra, la);
	vec3 p = pa;
	vec3 c = ca;
	float r = ra;
	float l = la;
	if (forme_b != forme_a && melange > 0.0) {
		vec3 pb;
		vec3 cb;
		float rb;
		float lb;
		forme(forme_b, a, pb, cb, rb, lb);
		// chaque point part à son heure, accélère puis ralentit doucement
		float e = clamp(melange * 1.7 - a.hom.a * 0.7, 0.0, 1.0);
		e = e * e * e * (e * (e * 6.0 - 15.0) + 10.0);
		float arc = sin(e * 3.14159);
		float za = plongee > 0 ? 1.0 + 2.0 * e : (plongee < 0 ? 1.0 - 0.7 * e : 1.0);
		float zb = plongee > 0 ? 0.3 + 0.7 * e : (plongee < 0 ? 3.0 - 2.0 * e : 1.0);
		p = mix(pa * za, pb * zb, e);
		// léger tourbillon en chemin : le nuage s'enroule puis se pose
		p = tourne_y(p, arc * (0.25 + 0.9 * a.gal.a));
		p += arc * 0.1 * (a.g.yzx - 0.5) * vec3(1.0, 0.6, 0.6);
		c = mix(ca, cb, e);
		r = mix(ra, rb, e);
		l = mix(la, lb, e) * (1.0 + 0.25 * arc);
	}
	VERTEX = p;
	vec4 w = MODELVIEW_MATRIX * vec4(p, 1.0);
	float d = max(length(w.xyz), 0.02);
	float f = abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y * 0.5;
	// Même souci que points.gdshader : ne pas virer au blanc là où les points se recouvrent. `l` est la lumière voulue pour
	// un point de 2,2 pixels vu à 330 pixels par mètre ; on la corrige selon la définition de l'écran et la taille du point,
	// pour que le nuage ait le même éclat sur un écran d'ordinateur et dans le casque.
	float fd = f / d;
	float px = clamp(2.0 * r * fd, 2.2, 12.0);
	float v = l * (fd / 330.0) * (fd / 330.0) * (2.2 / px) * (2.2 / px) * (30000.0 / cnt);
	float scint = 0.86 + 0.14 * sin(temps * (2.0 + 4.0 * a.g.x) + a.g.w * 80.0);
	float lum = pow(min(v, 1.0), 0.4545) * scint * fondu * smoothstep(0.3, 0.6, d);   // le fragment élève à la puissance 2,2
	POINT_SIZE = px;
	col = c * lum;
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
