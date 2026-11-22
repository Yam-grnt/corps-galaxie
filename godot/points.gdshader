// Nuage de points lumineux. Le grain reste petit et régulier, comme un pixel : une forme se lit par la densité et la
// couleur de ses grains, jamais par leur taille.
// CUSTOM0 : couleur, et rayon de l'enfant si le grain « ouvre » sur un enfant (0 : grain de matière).
// CUSTOM1 : x = système du corps auquel le point appartient (−1 : aucun), y = phase le long d'un trajet (vaisseau, nerf…).
// CUSTOM2 : centre de l'enfant auquel le grain appartient (le grain lui-même, ou un grain de son amas).
// UV      : x = rang du grain dans l'amas de son enfant (0 : le grain principal), y = étalement de l'amas.
//
// Toutes les mesures « en pixels » sont des angles : des pixels d'un œil de casque de référence (1760 px pour 96°,
// soit F_REF pixels par radian). main.gd (_collecter) applique exactement les mêmes règles pour choisir quoi afficher.
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled;

uniform float cnt = 1000.0;   // nombre de points de ce niveau de détail
uniform float n_tot = 1000.0; // nombre de points du nœud complet
uniform float n_fixe = 0.0;   // premiers points, toujours affichés (les plus gros enfants)
// Propres à chaque exemplaire affiché (main.gd, _appliquer) : le seuil à partir duquel SES enfants se déploient
// (OPEN, ou davantage si le budget a manqué pour eux), et le seuil que son parent lui a appliqué (0 : toujours plein).
uniform float ouv_enf = 24.0;
uniform float ouv_soi = 0.0;
uniform float dens = 2.0;     // points révélés : dens × rayon apparent^1,5
// Vie propre de l'objet : 0 rien, 1 battement du cœur, 2 respiration, 3 agitation thermique (molécules, atomes)
uniform int vie = 0;
// Effet d'activité de la visite guidée : 0 rien, 1 battement lumineux, 2 vague qui balaie, 3 scintillement
uniform int fx = 0;
uniform float fx_w = 1.0;                  // cycles par seconde (ou tirages par seconde pour le scintillement)
uniform float fx_q = 3.0;                  // nombre d'onde de la vague
uniform vec3 fx_dir = vec3(0.0, 0.0, 1.0); // direction de la vague
uniform float lueur = 1.0;                 // multiplicateur général (mise en avant ou mise en retrait)
// Filtre : systèmes mis en lumière (un bit par système ; 0 = tout), le reste s'estompe.
uniform int masque = 0;
uniform float flux = 0.0;                  // circulation le long des phases : 1 dans le sens croissant, −1 à rebours, 0 aucune
// Projecteur : ce qui est hors de la sphère (centre, rayon) s'estompe, pour détacher l'élément choisi. Rayon 0 : éteint.
uniform vec4 foyer = vec4(0.0);
uniform float retrait = 0.6;          // lumière restante hors du projecteur (avant correction gamma)
const float RETRAIT_FILTRE = 0.3;      // lumière restante des systèmes que le filtre écarte

// ── réglages du grain (les mêmes valeurs que dans main.gd) ──
const float F_REF = 792.0;        // pixels de référence par radian
const float OPEN = 24.0;          // rayon apparent pondéré à partir duquel un enfant se déploie
const float FONDU_OUV = 1.6;      // l'enfant est entièrement déployé à ouv × FONDU_OUV
const float AMAS = 0.2;           // grains d'amas par pixel² de rayon apparent de l'enfant
const float REGARD_MIN = 0.45;    // poids d'un objet loin du centre du regard
const float REGARD_0 = 0.24;      // (radians) jusqu'ici, plein poids
const float REGARD_1 = 0.79;      // (radians) au-delà, poids minimal
const float PX_MATIERE_MIN = 2.4; // taille d'un grain de matière (pixels de référence)
const float PX_MATIERE_MAX = 3.4;
const float PX_ENFANT_MIN = 2.8;  // taille d'un grain qui ouvre sur un enfant
const float PX_ENFANT_MAX = 4.0;
const float PX_AMAS = 2.5;        // taille d'un grain d'amas
const float K_DENS = 0.06;        // au-delà d'un grain pour 17 px², la lumière de chaque grain baisse
const float GAIN = 1.75;
varying vec3 col;

float hasard(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// Poids d'un objet (centre en repère de vue, rayon) selon son écart au centre du regard.
float regard(vec3 c, float r) {
	float d = max(length(c), 1e-5);
	float th = acos(clamp(-c.z / d, -1.0, 1.0)) - asin(clamp(r / d, 0.0, 1.0));
	return mix(1.0, REGARD_MIN, smoothstep(REGARD_0, REGARD_1, th));
}

void vertex() {
	vec3 v = VERTEX;
	float re = CUSTOM0.a;
	float rang = UV.x;
	float s = length(MODEL_MATRIX[0].xyz);
	float u = max(abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y * 0.5 / F_REF, 0.75);   // pixels réels par pixel de référence

	// le nuage lui-même : il apparaît en fondu, et ses points se révèlent un à un à mesure qu'il grandit
	vec3 cn = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float prn = s / max(length(cn), 0.03) * F_REF;   // rayon apparent du nuage entier
	float pen = prn * regard(cn, s);
	float app = ouv_soi <= 0.0 ? 1.0 : smoothstep(ouv_soi, ouv_soi * FONDU_OUV, pen);
	float ouv = ouv_enf;
	float n_rev = n_fixe + dens * pow(pen, 1.5);      // nombre de points que ce nuage mérite à cette taille
	float n_vis = max(1.0, min(cnt, 0.85 * n_rev));
	// les amas denses ne virent pas au blanc ; un nuage dont on ne montre qu'une partie compense un peu
	// … et un nuage clairsemé (peu de points pour beaucoup de place) donne plus de lumière à chacun : pas de fantôme
	float place = (3.14 * prn * prn + 1.0) / n_vis;      // pixels² par point
	float a = app * min(1.0, sqrt(K_DENS * place)) * min(1.8, sqrt(n_tot / n_vis) * clamp(sqrt(place / 150.0), 1.0, 1.6));

	float m = 1.0;   // modulation de lumière
	if (fx == 1) {
		float w = sin(TIME * 6.2832 * fx_w);
		m *= 0.75 + 0.9 * (w > 0.0 ? w * w : 0.0);      // l'objet présenté ne s'éteint jamais : il respire au-dessus de sa lumière normale
	} else if (fx == 2) {
		float w = sin(fx_q * dot(fx_dir, VERTEX) + TIME * 6.2832 * fx_w);
		m *= 0.6 + 1.5 * (w > 0.0 ? w * w * w : 0.0);
	} else if (fx == 3) {
		m *= hasard(VERTEX + floor(TIME * fx_w)) < 0.25 ? 2.0 : 0.75;
	}
	float gros = 1.0;
	int sys = int(floor(CUSTOM1.x + 0.5));
	bool ecarte = false;
	if (masque != 0 && sys >= 0) {
		if ((masque & (1 << sys)) != 0) {
			m *= 1.35;
			gros = 1.2;
			if (flux != 0.0 && CUSTOM1.y > 0.0) {
				// des paquets lumineux qui se suivent le long du trajet (pouls dans les artères, influx dans les nerfs)
				// dans les veines, le sang revient toujours vers le cœur (phases décroissantes)
				float w = sin(CUSTOM1.y * 38.0 - TIME * 5.0 * (sys == 4 ? -abs(flux) : flux));
				m *= 0.4 + 2.2 * (w > 0.0 ? w * w * w : 0.0);
			}
		} else {
			m *= RETRAIT_FILTRE;
			ecarte = true;      // ce que le filtre écarte ne se déploie pas
		}
	}

	float px;
	if (re > 0.0) {
		// un grain qui ouvre sur un enfant, ou un grain de l'amas qui l'entoure
		vec3 ce = (MODELVIEW_MATRIX * vec4(CUSTOM2.xyz, 1.0)).xyz;
		float pr = re * s / max(length(ce), 0.02) * F_REF;   // rayon apparent de l'enfant
		float pe = pr * regard(ce, re * s);
		// fondu croisé : grain et amas s'effacent pendant que le nuage de l'enfant apparaît (même règle, même seuil)
		float o = ecarte ? 0.0 : smoothstep(ouv, ouv * FONDU_OUV, pe);
		if (rang < 0.5) {
			px = mix(PX_ENFANT_MIN, PX_ENFANT_MAX, smoothstep(1.5, 10.0, pr));
			a *= 0.8 * mix(1.0, 0.08, o);
			if (float(VERTEX_ID) < n_fixe) {
				// les quelques gros enfants d'un nœud (le noyau et les électrons d'un atome, les organes du corps) comptent chacun
				px += 1.0;
				a *= 1.25;
			}
		} else {
			// l'amas : d'abord une poussière étalée sur le territoire de l'enfant (la forme du parent se lit par la
			// densité), qui se resserre sur la forme de l'enfant à l'approche du seuil d'ouverture
			float nw = min(AMAS * pe * pe, 48.0);
			float serre = smoothstep(0.3 * OPEN, 0.85 * OPEN, pe);
			float etal = mix(UV.y, 1.0, serre);
			v = CUSTOM2.xyz + (v - CUSTOM2.xyz) * etal;
			px = PX_AMAS;
			float surf = 3.14 * etal * etal * pr * pr;
			a = app * 0.7 * clamp(nw - rang + 1.0, 0.0, 1.0) * (1.0 - o) * min(1.0, sqrt(K_DENS * 1.6 * (surf + 1.0) / max(nw, 1.0)));
		}
	} else {
		// un grain de matière : il se révèle selon son rang dans le nuage
		float i = float(VERTEX_ID);
		a *= 0.55 * (i < n_fixe ? 1.0 : clamp((n_rev - i) / (0.3 * n_rev + 1.0), 0.0, 1.0));
		px = clamp(0.006 * prn, PX_MATIERE_MIN, PX_MATIERE_MAX);
	}
	if (re > 0.0 && rang < 0.5) {
		float i = float(VERTEX_ID);
		a *= i < n_fixe ? 1.0 : clamp((n_rev - i) / (0.3 * n_rev + 1.0), 0.0, 1.0);
	}

	if (vie == 1) {
		// deux coups rapprochés (« poum-poum ») à 66 battements par minute : le cœur se serre puis se relâche
		float t = fract(TIME * 1.1);
		float coup = exp(-t * 14.0) + 0.7 * exp(-abs(t - 0.3) * 18.0) * step(0.3, t);
		v *= 1.0 - 0.035 * coup;
		m *= 0.85 + 0.55 * coup;
	} else if (vie == 2) {
		// 15 respirations par minute
		float w = sin(TIME * 6.2832 * 0.25);
		v *= 1.0 + 0.03 * w;
		m *= 0.9 + 0.15 * w;
	} else if (vie == 3 && re <= 0.0) {
		// agitation thermique : seuls les points « de matière » tremblent, pas ceux qui ouvrent sur un enfant
		float pas = floor(TIME * 12.0);
		v += (vec3(hasard(VERTEX + pas), hasard(VERTEX.yzx + pas), hasard(VERTEX.zxy + pas)) - 0.5) * 0.03;
	}
	VERTEX = v;
	vec4 monde = MODEL_MATRIX * vec4(v, 1.0);
	if (foyer.w > 0.0) {
		m *= mix(1.0, retrait, smoothstep(foyer.w * 1.0, foyer.w * 1.4, distance(monde.xyz, foyer.xyz)));
	}
	float d = max(length((VIEW_MATRIX * monde).xyz), 0.02);
	a *= smoothstep(0.15, 0.32, d);   // rien de lumineux à moins de 15 cm des yeux
	POINT_SIZE = a > 0.003 ? px * u * gros : 0.0;
	col = CUSTOM0.rgb * a * m * lueur * GAIN;   // le corps doit rester ce qu'il y a de plus lumineux dans la scène
}

void fragment() {
	vec2 q = POINT_COORD * 2.0 - 1.0;
	float k = 1.0 - dot(q, q);
	if (k <= 0.0) {
		discard;
	}
	vec3 c = col * smoothstep(0.0, 0.4, k);
	ALBEDO = pow(c, vec3(2.2));
}
