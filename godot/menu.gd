class_name MenuGalaxie extends Node3D
## Le menu du corps galaxie : une carte à onglets, pensée à partir de ce qu'on fait le plus souvent.
##
##   Accueil   : « Parler au guide » (énorme), Recentrer, Corps entier, Noms, et deux raccourcis d'état (Montrer, Visite)
##   Montrer   : les filtres, une tuile par système, chacune avec son pictogramme dans la couleur du système
##   Visites   : une carte par visite guidée (titre + nombre d'étapes), quatre par écran
##   Réglages  : public (Enfant / Curieux / Scientifique), réalité mixte, tutoriel, menu de départ, et tout en bas
##               « Quitter », discret, qui exige 1,5 s de maintien (jauge)
##
## Le menu vit dans son plan local XY, face avant vers +Z, dimensions en mètres (encombrement 0,46 × 0,495, poignée
## comprise). main.gd le place, lui donne les pointeurs à chaque image (`maj`) et reçoit l'identifiant de l'action
## déclenchée. Les pointeurs sont ceux de panneau.gd :
##   {"id": String, "o": Vector3, "d": Vector3, "clic": bool, "appui": bool, "bout": Vector3, "doigt": bool}
## Au doigt on traverse le plan par l'avant (hystérésis : il faut ressortir de 18 mm pour réappuyer) ; au rayon on
## vise et on clique.
##
## Dessin : toutes les plaques, tous les pictogrammes (dessinés dans le shader, aucune image) et la poignée partent
## en UN appel de dessin (MultiMesh), les curseurs en un second, puis un Label3D par texte de la page affichée.

signal touche(id: String)       # un élément vient d'être survolé (main.gd joue le petit clic)
signal active(id: String)       # une action vient d'être déclenchée (même valeur que le retour de maj)

const CLAIR := Color(0.925, 0.91, 0.875)
const BLANC := Color(1.0, 0.99, 0.97)
const GRIS := Color(0.63, 0.67, 0.75)
const OR := Color(1, 0.85, 0.3)
const ENCRE := Color(0.05, 0.05, 0.07)
const NUIT_ICONE := Color(0.13, 0.17, 0.55)
const BRAISE := Color(1.0, 0.47, 0.28)

const ENFONCE := 0.004          # le doigt « appuie » à moins de 4 mm du plan
const DEGAGE := 0.018           # … et doit ressortir de 18 mm avant de pouvoir réappuyer
const PORTEE := 6.0
const AVANCE := 0.006           # un élément survolé s'avance de 6 mm
const ANNEAU := 0.008
const AIMANT := 0.012           # au rayon, on ne quitte l'élément survolé qu'en sortant de 12 mm (tremblement)
const STABLE := 0.15            # un clic au rayon n'active qu'un élément survolé depuis 0,15 s…
const MEMOIRE := 0.4            # … sinon celui qui l'a été le plus longtemps dans les 0,4 dernières secondes
const GEL_PINCE := 0.8          # la cible retenue au début d'un pincement vaut pour le clic qui suit (au plus 0,8 s)
const SOURD_VISITE := 0.6       # après le lancement d'une visite, les clics sont ignorés 0,6 s
const TEXTE_MIN := 16.0         # mm : aucun texte en dessous

const DEMI := Vector2(0.23, 0.25)       # demi-encombrement (zone où les pointeurs « accrochent »)
const L_CARTE := 0.46
const H_CARTE := 0.474
const Y_CARTE := 0.013                  # la carte va de +0,25 à −0,224 ; la poignée est dessous
const X0 := -0.218                      # bord gauche du contenu
const LC := 0.436                       # largeur du contenu
const Y_ENTETE := 0.213
const Y_CONTENU := 0.180                # haut de la zone de page (0,326 de haut)
const Y_ONGLETS := -0.184
const Y_POIGNEE := -0.238
const POIGNEE := Vector2(0.11, 0.014)

const ACCUEIL := 0
const MONTRER := 1
const VISITES := 2
const REGLAGES := 3
const ONGLETS := [["Explorer", 31], ["Montrer", 34], ["Visites", 20], ["Réglages", 21]]
const TITRES := ["Explorer", "Montrer", "Visites", "Réglages"]
const NIVEAUX := ["Enfant", "Curieux", "Scientifique"]
const PAR_ECRAN := 4                    # cartes de visite par écran

## Pictogramme (indice dans le shader) et couleur de chaque filtre : la couleur du système dans le corps.
const PICTOS := {
	"tout": [0, Color(0.925, 0.91, 0.875)],
	"sang": [1, Color(1.0, 0.36, 0.33)],
	"nerfs": [2, Color(1.0, 0.87, 0.35)],
	"oxygene": [3, Color(0.45, 0.85, 1.0)],
	"digestion": [4, Color(1.0, 0.66, 0.32)],
	"squelette": [5, Color(0.96, 0.92, 0.8)],
	"muscles": [6, Color(0.98, 0.5, 0.52)],
	"hormones": [7, Color(0.76, 0.6, 1.0)],
	"defenses": [8, Color(0.5, 0.9, 0.6)],
	"urinaire": [9, Color(0.38, 0.86, 0.78)],
	"reproduction": [10, Color(1.0, 0.58, 0.82)],
	"sens": [11, Color(0.72, 0.82, 1.0)],
	"mouvement": [12, Color(0.78, 0.94, 0.45)],
	"arteres": [13, Color(1.0, 0.33, 0.3)],
	"veines": [14, Color(0.42, 0.58, 1.0)],
	"peau": [15, Color(1.0, 0.8, 0.68)],
}
## Libellés raccourcis quand le nom complet ne tient pas à 16 mm dans une tuile.
const COURTS := {"tout": "Tout", "urinaire": "Reins", "arteres": "Artères"}

## Un seul shader. CUSTOM = (largeur, hauteur, paramètre, genre + 8 × style), COLOR = états ou couleur.
##   genre 0 carte · 1 tuile · 2 pictogramme · 3 curseur · 4 poignée · 5 interrupteur
const CODE := "
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float opacite = 1.0;
uniform vec3 nuit_haut : source_color = vec3(0.075, 0.095, 0.16);
uniform vec3 nuit_bas : source_color = vec3(0.04, 0.05, 0.09);
uniform vec3 tuile : source_color = vec3(0.17, 0.205, 0.30);
uniform vec3 indigo_a : source_color = vec3(0.22, 0.27, 0.86);
uniform vec3 indigo_b : source_color = vec3(0.36, 0.42, 1.0);
uniform vec3 dore : source_color = vec3(1.0, 0.85, 0.3);
uniform vec3 dore_b : source_color = vec3(1.0, 0.74, 0.22);
uniform vec3 clair : source_color = vec3(0.925, 0.91, 0.875);
uniform vec3 encre : source_color = vec3(0.05, 0.05, 0.07);
uniform vec3 braise : source_color = vec3(1.0, 0.42, 0.2);
uniform vec3 plateau : source_color = vec3(0.02, 0.026, 0.05);
uniform vec3 pastille : source_color = vec3(0.27, 0.32, 0.46);
uniform vec3 rail : source_color = vec3(0.3, 0.34, 0.45);
uniform vec3 lisere : source_color = vec3(0.62, 0.72, 0.95);
const float MARGE = 0.012;
varying vec2 p;
varying vec4 donnees;
varying vec4 etat;
varying float genre;
varying float style;

void vertex() {
	donnees = INSTANCE_CUSTOM;
	etat = COLOR;
	float g = floor(donnees.w + 0.5);
	style = floor(g / 8.0);
	genre = g - style * 8.0;
	vec2 t = vec2(0.0);
	if (donnees.x > 0.0) {
		t = (genre > 1.5 && genre < 3.5) ? vec2(donnees.x) : donnees.xy;
		t += 2.0 * MARGE;
	}
	p = VERTEX.xy * t;
	VERTEX = vec3(p, 0.0);
}

float boite(vec2 q, vec2 demi, float r) {
	vec2 w = abs(q) - demi + r;
	return length(max(w, 0.0)) + min(max(w.x, w.y), 0.0) - r;
}

float seg(vec2 q, vec2 a, vec2 b) {
	vec2 pa = q - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// capsule inégale : rayon r1 en bas (à l'origine), r2 en haut (à la hauteur h)
float ucap(vec2 q, float r1, float r2, float h) {
	q.x = abs(q.x);
	float b = (r1 - r2) / h;
	float a = sqrt(1.0 - b * b);
	float k = dot(q, vec2(-b, a));
	if (k < 0.0) {
		return length(q) - r1;
	}
	if (k > a * h) {
		return length(q - vec2(0.0, h)) - r2;
	}
	return dot(q, vec2(a, b)) - r1;
}

// arc de cercle centré à l'origine ; `milieu` : angle du milieu de l'arc, compté depuis le haut dans le sens horaire
float arc(vec2 q, float r, float milieu, float demi_angle) {
	float c = cos(milieu);
	float s = sin(milieu);
	q = vec2(q.x * c - q.y * s, q.x * s + q.y * c);
	q.x = abs(q.x);
	if (atan(q.x, q.y) <= demi_angle) {
		return abs(length(q) - r);
	}
	return length(q - r * vec2(sin(demi_angle), cos(demi_angle)));
}

float coeur(vec2 q) {
	q.x = abs(q.x);
	if (q.y + q.x > 1.0) {
		return length(q - vec2(0.25, 0.75)) - 0.35355;
	}
	vec2 a = q - vec2(0.0, 1.0);
	vec2 b = q - 0.5 * max(q.x + q.y, 0.0);
	return sqrt(min(dot(a, a), dot(b, b))) * sign(q.x - q.y);
}

float hexa(vec2 q, float r) {
	vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	q = abs(q);
	q -= 2.0 * min(dot(k.xy, q), 0.0) * k.xy;
	q -= vec2(clamp(q.x, -k.z * r, k.z * r), r);
	return length(q) * sign(q.y);
}

float corps(vec2 q) {
	vec2 a = vec2(abs(q.x), q.y);
	float d = length(q - vec2(0.0, 0.66)) - 0.2;
	d = min(d, boite(q - vec2(0.0, 0.08), vec2(0.2, 0.3), 0.1));
	d = min(d, seg(a, vec2(0.0, 0.3), vec2(0.34, 0.3)) - 0.085);
	d = min(d, seg(a, vec2(0.36, 0.3), vec2(0.45, -0.2)) - 0.085);
	d = min(d, seg(a, vec2(0.105, -0.2), vec2(0.125, -0.8)) - 0.095);
	return d;
}

// Les pictogrammes : q dans [-1, 1]², distance signée (négative dedans).
float icone(vec2 q, int k, float temps) {
	vec2 a = vec2(abs(q.x), q.y);
	float d = 1.0;
	if (k == 0) {                   // corps entier
		d = corps(q);
	} else if (k == 1) {            // sang : goutte
		d = ucap(q - vec2(0.0, -0.3), 0.46, 0.03, 1.1);
	} else if (k == 2) {            // nerfs : neurone
		vec2 c = vec2(-0.28, 0.26);
		d = length(q - c) - 0.25;
		d = min(d, seg(q, c, vec2(-0.82, 0.58)) - 0.06);
		d = min(d, seg(q, c, vec2(-0.4, 0.86)) - 0.06);
		d = min(d, seg(q, c, vec2(0.22, 0.7)) - 0.06);
		d = min(d, seg(q, c, vec2(-0.82, -0.12)) - 0.06);
		d = min(d, seg(q, c, vec2(0.42, -0.44)) - 0.08);
		d = min(d, seg(q, vec2(0.42, -0.44), vec2(0.8, -0.38)) - 0.065);
		d = min(d, seg(q, vec2(0.42, -0.44), vec2(0.48, -0.8)) - 0.065);
		d = min(d, length(q - vec2(0.8, -0.38)) - 0.11);
		d = min(d, length(q - vec2(0.48, -0.8)) - 0.11);
	} else if (k == 3) {            // oxygène : poumons
		d = seg(q, vec2(0.0, 0.86), vec2(0.0, 0.34)) - 0.075;
		d = min(d, seg(a, vec2(0.0, 0.34), vec2(0.3, 0.12)) - 0.075);
		d = min(d, ucap(a - vec2(0.5, -0.5), 0.31, 0.2, 0.66));
	} else if (k == 4) {            // digestion : intestin
		d = seg(q, vec2(-0.6, 0.56), vec2(0.3, 0.56));
		d = min(d, seg(q, vec2(0.3, 0.0), vec2(-0.3, 0.0)));
		d = min(d, seg(q, vec2(-0.3, -0.56), vec2(0.6, -0.56)));
		vec2 r1 = q - vec2(0.3, 0.28);
		if (r1.x > 0.0) {
			d = min(d, abs(length(r1) - 0.28));
		}
		vec2 r2 = q - vec2(-0.3, -0.28);
		if (r2.x < 0.0) {
			d = min(d, abs(length(r2) - 0.28));
		}
		d -= 0.105;
	} else if (k == 5) {            // squelette : os
		vec2 r = vec2(q.x + q.y, q.y - q.x) * 0.7071;
		d = seg(r, vec2(-0.55, 0.0), vec2(0.55, 0.0)) - 0.125;
		d = min(d, length(abs(r) - vec2(0.62, 0.17)) - 0.2);
	} else if (k == 6) {            // muscles : bras fléchi
		d = seg(q, vec2(-0.66, -0.5), vec2(0.12, -0.5)) - 0.2;
		d = min(d, length(q - vec2(-0.28, -0.2)) - 0.35);
		d = min(d, seg(q, vec2(0.2, -0.45), vec2(0.4, 0.3)) - 0.17);
		d = min(d, length(q - vec2(0.4, 0.54)) - 0.25);
	} else if (k == 7) {            // hormones : molécule
		d = abs(hexa(q - vec2(-0.14, -0.14), 0.42)) - 0.075;
		d = min(d, seg(q, vec2(0.1, 0.28), vec2(0.5, 0.58)) - 0.075);
		d = min(d, length(q - vec2(0.6, 0.64)) - 0.2);
	} else if (k == 8) {            // défenses : bouclier
		d = max(length(vec2(a.x + 0.5, a.y - 0.2)) - 1.15, q.y - 0.74);
		float x = min(boite(q - vec2(0.0, 0.0), vec2(0.085, 0.31), 0.02), boite(q - vec2(0.0, 0.0), vec2(0.31, 0.085), 0.02));
		d = max(d, -x);
	} else if (k == 9) {            // reins
		vec2 r = vec2(a.x - 0.5, (a.y - 0.18) * 0.7);
		d = max(length(r) - 0.36, -(length(r - vec2(-0.37, 0.0)) - 0.2));
		d = min(d, seg(a, vec2(0.3, 0.14), vec2(0.1, -0.84)) - 0.06);
	} else if (k == 10) {           // reproduction
		d = abs(length(q - vec2(-0.08, 0.1)) - 0.33) - 0.075;
		d = min(d, seg(q, vec2(-0.08, -0.23), vec2(-0.08, -0.84)) - 0.075);
		d = min(d, seg(q, vec2(-0.32, -0.56), vec2(0.16, -0.56)) - 0.075);
		d = min(d, seg(q, vec2(0.16, 0.34), vec2(0.62, 0.8)) - 0.075);
		d = min(d, seg(q, vec2(0.62, 0.8), vec2(0.3, 0.8)) - 0.075);
		d = min(d, seg(q, vec2(0.62, 0.8), vec2(0.62, 0.48)) - 0.075);
	} else if (k == 11) {           // sens : œil
		float l = max(length(q - vec2(0.0, -0.6)) - 1.0, length(q - vec2(0.0, 0.6)) - 1.0);
		d = abs(l + 0.075) - 0.075;
		d = min(d, length(q) - 0.2);
	} else if (k == 12) {           // mouvement : articulation qui tourne
		vec2 j = vec2(-0.42, -0.42);
		d = seg(q, j, vec2(-0.42, 0.74)) - 0.115;
		d = min(d, seg(q, j, vec2(0.74, -0.42)) - 0.115);
		d = min(d, length(q - j) - 0.23);
		d = max(d, -(length(q - j) - 0.09));
		d = min(d, arc(q - j, 0.85, 0.785, 0.42) - 0.06);
		d = min(d, seg(q, vec2(0.374, -0.116), vec2(0.156, 0.006)) - 0.06);
		d = min(d, seg(q, vec2(0.374, -0.116), vec2(0.456, 0.12)) - 0.06);
	} else if (k == 13) {           // cœur et artères
		d = coeur((q + vec2(0.0, 0.76)) / 1.4) * 1.4;
	} else if (k == 14) {           // veines : vaisseau ramifié
		d = seg(q, vec2(0.0, -0.84), vec2(0.0, -0.15)) - 0.12;
		d = min(d, seg(a, vec2(0.0, -0.15), vec2(0.5, 0.74)) - 0.095);
		d = min(d, seg(q, vec2(0.28, 0.35), vec2(0.78, 0.28)) - 0.065);
		d = min(d, seg(q, vec2(-0.2, 0.2), vec2(-0.76, 0.1)) - 0.065);
	} else if (k == 15) {           // peau : empreinte
		vec2 r = q - vec2(0.0, -0.25);
		d = arc(r, 0.25, 0.0, 2.0);
		d = min(d, arc(r, 0.55, 0.0, 1.9));
		d = min(d, arc(r, 0.85, 0.0, 1.5));
		d -= 0.075;
	} else if (k == 16) {           // micro
		d = seg(q, vec2(0.0, 0.12), vec2(0.0, 0.52)) - 0.25;
		d = min(d, arc(vec2(q.x, 0.12 - q.y), 0.47, 0.0, 1.5708) - 0.07);
		d = min(d, seg(q, vec2(0.0, -0.36), vec2(0.0, -0.72)) - 0.07);
		d = min(d, seg(q, vec2(-0.27, -0.76), vec2(0.27, -0.76)) - 0.07);
	} else if (k == 17) {           // recentrer : mire
		vec2 b = abs(q);
		d = abs(length(q) - 0.5) - 0.075;
		d = min(d, length(q) - 0.14);
		d = min(d, seg(b, vec2(0.5, 0.0), vec2(0.86, 0.0)) - 0.075);
		d = min(d, seg(b, vec2(0.0, 0.5), vec2(0.0, 0.86)) - 0.075);
	} else if (k == 18) {           // corps entier, cadré
		vec2 b = abs(q);
		d = corps(q / 0.7) * 0.7;
		d = min(d, seg(b, vec2(0.86, 0.86), vec2(0.5, 0.86)) - 0.07);
		d = min(d, seg(b, vec2(0.86, 0.86), vec2(0.86, 0.5)) - 0.07);
	} else if (k == 19) {           // noms : étiquette
		d = boite(q - vec2(0.2, 0.0), vec2(0.62, 0.43), 0.12);
		vec2 r = q - vec2(-0.42, 0.0);
		r = vec2(r.x + r.y, r.y - r.x) * 0.7071;
		d = min(d, boite(r, vec2(0.304), 0.08));
		d = max(d, -(length(q - vec2(-0.5, 0.0)) - 0.11));
		d = max(d, -(seg(q, vec2(-0.08, 0.15), vec2(0.52, 0.15)) - 0.06));
		d = max(d, -(seg(q, vec2(-0.08, -0.15), vec2(0.3, -0.15)) - 0.06));
	} else if (k == 20) {           // visites : boussole
		d = abs(length(q) - 0.78) - 0.075;
		float u = (q.x + q.y) * 0.7071;
		float v = (q.x - q.y) * 0.7071;
		float n = (abs(u) / 0.56 + abs(v) / 0.21 - 1.0) * 0.19;
		n = max(n, -(length(q) - 0.075));
		d = min(d, n);
	} else if (k == 21) {           // réglages : curseurs
		d = seg(q, vec2(-0.76, 0.36), vec2(0.76, 0.36)) - 0.065;
		d = min(d, length(q - vec2(0.3, 0.36)) - 0.23);
		d = min(d, seg(q, vec2(-0.76, -0.36), vec2(0.76, -0.36)) - 0.065);
		d = min(d, length(q - vec2(-0.3, -0.36)) - 0.23);
	} else if (k == 22) {           // réalité mixte : visière
		d = boite(q, vec2(0.84, 0.46), 0.3);
		d = max(d, -(length(q - vec2(0.0, -0.52)) - 0.2));
		d = max(d, -boite(a - vec2(0.39, 0.04), vec2(0.21, 0.16), 0.15));
	} else if (k == 23) {           // tutoriel : point d'interrogation
		d = arc(q - vec2(0.0, 0.38), 0.34, 0.44, 2.0);
		d = min(d, seg(q, vec2(0.219, 0.12), vec2(0.0, -0.12)));
		d = min(d, seg(q, vec2(0.0, -0.12), vec2(0.0, -0.26)));
		d -= 0.095;
		d = min(d, length(q - vec2(0.0, -0.68)) - 0.125);
	} else if (k == 24) {           // menu de départ : maison
		d = seg(a, vec2(0.0, 0.78), vec2(0.8, 0.08)) - 0.085;
		float m = boite(q - vec2(0.0, -0.36), vec2(0.5, 0.42), 0.08);
		m = max(m, -boite(q - vec2(0.0, -0.53), vec2(0.15, 0.27), 0.04));
		d = min(d, m);
	} else if (k == 25) {           // quitter : marche/arrêt
		d = arc(vec2(q.x, -q.y - 0.08), 0.6, 0.0, 2.45) - 0.085;
		d = min(d, seg(q, vec2(0.0, 0.12), vec2(0.0, 0.84)) - 0.085);
	} else if (k == 26) {           // fermer : croix
		d = seg(abs(q), vec2(0.0), vec2(0.56, 0.56)) - 0.1;
	} else if (k == 27) {           // lecture
		d = max(-q.x - 0.36, (q.x - 0.62) * 0.496 + abs(q.y) * 0.868) - 0.08;
	} else if (k == 28) {           // arrêt
		d = boite(q, vec2(0.52), 0.14);
	} else if (k == 29) {           // chevron droit
		d = seg(vec2(q.x, abs(q.y)), vec2(0.28, 0.0), vec2(-0.22, 0.5)) - 0.1;
	} else if (k == 30) {           // chevron gauche
		d = seg(vec2(-q.x, abs(q.y)), vec2(0.28, 0.0), vec2(-0.22, 0.5)) - 0.1;
	} else if (k == 31) {           // accueil : étincelle
		vec2 b = abs(q + vec2(0.1, 0.1));
		d = (pow(b.x, 0.6) + pow(b.y, 0.6) - 0.86) * 0.45;
		vec2 e = abs(q - vec2(0.62, 0.62));
		d = min(d, (pow(e.x, 0.6) + pow(e.y, 0.6) - 0.44) * 0.45);
	} else if (k == 32) {           // écoute : ondes de la voix (elles ondulent doucement, sans clignoter)
		for (int i = 0; i < 5; i++) {
			float x = -0.72 + 0.36 * float(i);
			float h = 0.2 + 0.5 * (0.5 + 0.5 * sin(temps * 2.6 + float(i) * 1.7));
			d = min(d, seg(q, vec2(x, -h), vec2(x, h)) - 0.1);
		}
	} else if (k == 34) {           // montrer : calques
		d = (a.x / 0.82 + abs(q.y - 0.3) / 0.4 - 1.0) * 0.36;
		d = min(d, seg(a, vec2(0.8, -0.12), vec2(0.0, -0.5)) - 0.07);
		d = min(d, seg(a, vec2(0.8, -0.46), vec2(0.0, -0.84)) - 0.07);
	} else {                        // pastille
		d = length(q) - 0.55;
	}
	return d;
}

void sur(inout vec3 c, inout float a, vec3 c2, float a2) {
	a2 = clamp(a2, 0.0, 1.0);
	float s = a2 + a * (1.0 - a2);
	c = (c2 * a2 + c * a * (1.0 - a2)) / max(s, 0.0001);
	a = s;
}

void fragment() {
	vec2 demi = donnees.xy * 0.5;
	vec3 c = vec3(0.0);
	float a = 0.0;
	if (genre < 0.5) {
		// la carte : aplat nuit, coins généreux, ombre portée pour se détacher d'une pièce claire
		float d = boite(p, demi, 0.036);
		float l = max(fwidth(d), 0.00002);
		float dedans = 1.0 - smoothstep(-l, l, d);
		c = vec3(0.0, 0.002, 0.008);
		a = 0.45 * exp(-max(d, 0.0) / 0.0045) * (1.0 - dedans);
		vec3 f = mix(nuit_bas, nuit_haut, smoothstep(-demi.y, demi.y, p.y + p.x * 0.3));
		if (donnees.z > 0.001 && donnees.z < 0.999) {
			// à l'ouverture, une seule vague de lumière descend sur la carte
			float y = mix(demi.y + 0.04, -demi.y - 0.04, donnees.z);
			f += lisere * 0.3 * exp(-abs(p.y - y) / 0.016) * sin(donnees.z * 3.14159);
		}
		sur(c, a, f, 0.955 * dedans);
		float ep = max(0.001, 1.2 * l);
		float trait = smoothstep(-ep - l, -ep + l, d) * dedans;
		sur(c, a, lisere, 0.3 * trait);
		a *= etat.a;
	} else if (genre < 1.5) {
		// tuile : aplat, pas de contour au repos ; survol = plus claire + anneau blanc ; pressée = blanc chaud ;
		// active = or plein
		float s = etat.r;
		float e = etat.g;
		float al = etat.b;
		float r = 0.017;
		vec3 f = tuile;
		float fa = 0.97;
		float bord = 0.0;
		if (style > 0.5 && style < 1.5) {           // 1 : action principale (indigo)
			r = 0.03;
			f = mix(indigo_a, indigo_b, smoothstep(-demi.x, demi.x, p.x + p.y));
			fa = 1.0;
		} else if (style > 1.5 && style < 2.5) {    // 2 : discrète (contour seul)
			r = demi.y;
			fa = 0.22;
			bord = 0.34;
		} else if (style > 2.5 && style < 3.5) {    // 3 : onglet (transparent)
			r = 0.019;
			fa = 0.0;
		} else if (style > 3.5 && style < 4.5) {    // 4 : pastille de l'onglet actif
			r = 0.019;
			f = pastille;
			fa = 1.0;
		} else if (style > 4.5 && style < 5.5) {    // 5 : plateau des onglets
			r = 0.025;
			f = plateau;
			fa = 0.8;
		} else if (style > 5.5) {                   // 6 : disque
			r = demi.y;
			f = mix(clair, encre, max(al, e));
			fa = 1.0;
			al = 0.0;
			e = 0.0;
		}
		r = min(r, min(demi.x, demi.y));
		float d = boite(p, demi, r);
		float l = max(fwidth(d), 0.00002);
		float dedans = 1.0 - smoothstep(-l, l, d);
		f += vec3(0.012, 0.014, 0.02) * smoothstep(-demi.y, demi.y, p.y) * step(style, 4.5);
		f = mix(f, f * 1.28 + vec3(0.02, 0.024, 0.034), s);
		fa = mix(fa, max(fa, 0.62), s);
		f = mix(f, mix(dore_b, dore, smoothstep(-demi.y, demi.y, p.y)), al);
		fa = mix(fa, 1.0, al);
		if (donnees.z > 0.001) {
			float x = (p.x + demi.x) / (2.0 * demi.x);
			float lx = max(fwidth(x), 0.0005);
			float rempli = 1.0 - smoothstep(donnees.z - lx, donnees.z + lx, x);
			f = mix(f, braise, rempli);
			fa = mix(fa, 1.0, rempli);
		}
		f = mix(f, clair, e);
		fa = mix(fa, 1.0, e);
		c = f;
		a = fa * dedans;
		if (style > 5.5) {
			float rr = length(p);
			float da = abs(rr - demi.y - 0.0055) - 0.0007;
			float tour = 0.5 + 0.5 * sin(atan(p.y, p.x) * 2.0 - TIME * 0.9);
			float arcs = mix(0.38, smoothstep(0.25, 0.75, tour), etat.b);
			sur(c, a, mix(vec3(1.0), encre, etat.b), (1.0 - smoothstep(-l, l, da)) * arcs * (1.0 - etat.g));
		}
		float ep = max(0.0015, 1.2 * l);
		float trait = smoothstep(-ep - l, -ep + l, d) * dedans;
		sur(c, a, vec3(1.0), trait * max(bord * (1.0 - e), 0.95 * s * (1.0 - e)));
		a *= etat.a;
	} else if (genre < 2.5) {
		// pictogramme
		vec2 q = p / (donnees.x * 0.5);
		float d = icone(q, int(donnees.y + 0.5), TIME);
		float l = max(fwidth(d), 0.0005);
		c = etat.rgb;
		a = (1.0 - smoothstep(-l, l, d)) * etat.a;
	} else if (genre < 3.5) {
		// curseur : anneau clair cerné de sombre
		float r_ext = donnees.x * 0.5;
		float ep = r_ext * 0.24;
		float rr = length(p);
		float d = abs(rr - (r_ext - ep * 0.5)) - ep * 0.5;
		float l = max(fwidth(d), 0.00002);
		c = vec3(0.0, 0.01, 0.03);
		a = 0.5 * (1.0 - smoothstep(0.0, ep * 1.3, d));
		sur(c, a, vec3(1.0), 1.0 - smoothstep(-l, l, d));
		sur(c, a, vec3(1.0), (1.0 - smoothstep(-l, l, rr - r_ext * 0.36)) * etat.g);
		a *= etat.r;
	} else if (genre < 4.5) {
		// poignée : une simple barre arrondie, qui s'éclaircit et s'allonge quand on la vise
		float s = etat.r;
		vec2 dm = vec2(mix(0.04, 0.05, s), mix(0.003, 0.0045, s));
		float d = boite(p, dm, dm.y);
		float l = max(fwidth(d), 0.00002);
		c = vec3(0.0, 0.002, 0.008);
		a = 0.45 * exp(-max(d, 0.0) / 0.003);
		sur(c, a, mix(vec3(0.5, 0.54, 0.62), vec3(1.0), s), 1.0 - smoothstep(-l, l, d));
		a *= etat.a;
	} else {
		// interrupteur
		float on = donnees.z;
		float d = boite(p, demi, demi.y);
		float l = max(fwidth(d), 0.00002);
		c = mix(rail, dore, on);
		a = 1.0 - smoothstep(-l, l, d);
		float dk = length(p - vec2(mix(-1.0, 1.0, on) * (demi.x - demi.y), 0.0)) - (demi.y - 0.0035);
		sur(c, a, mix(clair, encre, on), (1.0 - smoothstep(-l, l, dk)) * a);
		a *= etat.a;
	}
	ALBEDO = c;
	ALPHA = a * opacite;
}
"

class Texte:
	var l: Label3D
	var pos := Vector2.ZERO     # par rapport au centre de l'élément
	var coul := Color.WHITE
	var mm := 16.0              # taille voulue
	var largeur := 0.0          # largeur disponible (0 : libre)
	var voulu := ""
	var cle := -1               # dernière couleur peinte (quantifiée)
	var p_ecrit := Vector3(1e9, 0, 0)
	var g_ecrit := -1.0


class Elem:
	var id := ""                # action renvoyée (ou navigation interne : nav:…, pg, vis)
	var page := -1              # −1 : toujours là (en-tête, onglets)
	var ecran := -1             # sous-écran des visites (−1 : tous)
	var c := Vector2.ZERO
	var t := Vector2.ZERO
	var zone := Vector2.ZERO    # zone sensible (ZERO : décor)
	var zc := Vector2.ZERO      # centre de la zone sensible (par défaut : celui du dessin)
	var style := 0
	var plaque := true
	var remplit := true         # l'état actif remplit la plaque d'or
	var maintien := 0.0
	var heros := false          # le gros bouton « Parler » : disque + ondes
	var icone := -1
	var ic_pos := Vector2.ZERO
	var ic_t := 0.03
	var ic_coul := Color.WHITE
	var ic_actif := Color(0.05, 0.05, 0.07)
	var bascule := false        # interrupteur dessiné à droite
	var b_pos := Vector2.ZERO
	var texte: Texte
	var sous: Texte
	var tx_actif := Color(0.05, 0.05, 0.07)
	var so_actif := Color(0.05, 0.05, 0.07)
	var actif := false
	var visible := true
	var rang := 0.0             # ordre d'apparition (échelonnée)
	var i0 := 0                 # première instance dans le MultiMesh
	var n := 0
	# animation
	var s := 0.0
	var e := 0.0
	var al := 0.0
	var av := 0.0
	var on := 0.0
	var ech := 1.0
	var v := 0.0
	var ap := 1.0
	var venue := Vector2.ZERO
	var eclat := 0.0
	var dessine := false


static var _shader_commun: Shader
static var _maille_commune: ArrayMesh

var survol := false                     # vrai si un pointeur vise ou touche le menu à cette image
var survol_id := ""                     # action de l'élément visé à cette image, sinon ""
var impacts: Array[Vector3] = []        # points (repère monde) où les rayons touchent le menu
var survol_point := Vector3.ZERO
var ouvert := false
var page := ACCUEIL                     # onglet affiché (lecture ; pour changer : aller_page)

var _police: Font
var _serrees := {}
var _pret := false
var _elems: Array[Elem] = []
var _onglets: Array[Elem] = []
var _etat := {"micro": false, "visite": "", "filtre": "tout", "etiquettes": false, "niveau": 1, "mixte": false, "tuto": false}
var _filtres: Array = []
var _visites: Array = []
var _el_micro: Elem
var _el_noms: Elem
var _el_montrer: Elem
var _el_visite: Elem
var _el_mixte: Elem
var _el_tuto: Elem
var _el_stop: Elem
var _el_suite: Elem
var _el_filtres := {}
var _el_visites := {}
var _el_niveaux: Array[Elem] = []
var _sous_visites := {}                 # id de visite → sous-titre au repos (« 8 étapes »)
var _ecran := 0                         # écran courant des visites
var _nb_ecrans := 1
var _sort := -1                         # page en train de sortir
var _t_sort := 0.0
var _dir := 1.0
var _ind_x := 0.0
var _balai := 1.0
var _t_ferme := 0.0

var _survol_el: Elem
var _presse: Elem
var _t_presse := 0.0
var _fait := false
var _doigts := {}
var _rayons := {}                       # par pointeur : survol stable au rayon {el, depuis, hist, appui, gele, t_gele, vu}
var _horloge := 0.0
var _sourd := -1.0                      # instant jusqu'auquel les clics sont ignorés

var _racine: Node3D
var _mm: MultiMesh
var _mat: ShaderMaterial
var _curseurs: MultiMeshInstance3D
var _mm_c: MultiMesh
var _cibles: Array = []
var _nc_ecrit := 0
var _c_pos := PackedVector3Array()
var _c_ech := PackedFloat32Array()
var _c_cu := PackedColorArray()
var _c_co := PackedColorArray()
var _anim := 0.0
var _e := 0.0
var _alpha := -1.0
var _image_maj := -1
var _poignee_s := 0.0
var _image_poignee := -10


func _init() -> void:
	if _shader_commun == null:
		_shader_commun = Shader.new()
		_shader_commun.code = CODE
		var t := []
		t.resize(Mesh.ARRAY_MAX)
		t[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)])
		t[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		t[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
		_maille_commune = ArrayMesh.new()
		_maille_commune.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, t)
	_racine = Node3D.new()
	_racine.visible = false
	add_child(_racine)
	_mat = ShaderMaterial.new()
	_mat.shader = _shader_commun
	_mm = _multi(0)
	_racine.add_child(_instance(_mm, _mat))
	var mc := ShaderMaterial.new()
	mc.shader = _shader_commun
	mc.render_priority = 4
	_mm_c = _multi(2)
	for i in 2:
		_mm_c.set_instance_custom_data(i, Color(0, 0, 0, 3))
	_curseurs = _instance(_mm_c, mc)
	_curseurs.visible = false
	_racine.add_child(_curseurs)
	var boite := AABB(Vector3(-0.27, -0.28, -0.02), Vector3(0.54, 0.56, 0.06))
	_mm.custom_aabb = boite
	_mm_c.custom_aabb = boite


func _multi(n: int) -> MultiMesh:
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = true
	m.use_custom_data = true
	m.mesh = _maille_commune
	m.instance_count = n
	return m


func _instance(m: MultiMesh, mat: ShaderMaterial) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ───────── construction ─────────

## Construit le menu à partir des visites et des filtres de contenus.json. `police` : de préférence en champ de
## distance (celle de main.gd) ; null : la police par défaut, convertie.
func preparer(police: Font, visites: Array, filtres: Array) -> void:
	_police = police
	if _police == null:
		var base := ThemeDB.fallback_font
		if base is FontFile:
			var f := (base as FontFile).duplicate() as FontFile
			f.multichannel_signed_distance_field = true
			f.msdf_pixel_range = 12
			_police = f
		else:
			_police = base
	for e in _elems:
		for tx: Texte in [e.texte, e.sous]:
			if tx != null:
				tx.l.queue_free()
	_elems.clear()
	_serrees.clear()
	_onglets.clear()
	_el_filtres.clear()
	_el_visites.clear()
	_el_niveaux.clear()
	_sous_visites.clear()
	_survol_el = null
	_presse = null
	_doigts.clear()
	_visites = visites
	_filtres = filtres
	_entete()
	_page_accueil()
	_page_montrer()
	_page_visites()
	_page_reglages()
	# instances : 0 carte, 1 poignée, 2 plateau des onglets, 3 pastille de l'onglet actif, puis les éléments
	var n := 4
	for e in _elems:
		e.i0 = n
		e.n = (1 if e.plaque else 0) + (1 if e.icone >= 0 else 0) + (2 if e.heros else 0) + (1 if e.bascule else 0)
		n += e.n
	_mm.instance_count = n
	_c_pos.resize(n)
	_c_ech.resize(n)
	_c_cu.resize(n)
	_c_co.resize(n)
	for i in n:
		_c_ech[i] = -1.0
		_c_cu[i] = Color(0, 0, 0, 0)
		_c_co[i] = Color(0, 0, 0, 0)
		_mm.set_instance_transform(i, Transform3D.IDENTITY)
		_mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
		_mm.set_instance_color(i, Color(0, 0, 0, 0))
	_ind_x = _onglets[page].c.x
	_pret = true
	_alpha = -1.0
	_appliquer_etat()
	_appliquer_anim()


func _lab(mm: float, gauche: bool) -> Label3D:
	var l := Label3D.new()
	l.font = _police
	l.font_size = 64
	l.pixel_size = mm * 0.001 / 64.0
	l.outline_size = 0
	l.shaded = false
	l.render_priority = 2
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if gauche else HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.visible = false
	_racine.add_child(l)
	return l


func _texte(t: String, mm: float, pos: Vector2, coul: Color, gauche := false, largeur := 0.0) -> Texte:
	var tx := Texte.new()
	tx.l = _lab(mm, gauche)
	tx.pos = pos
	tx.coul = coul
	tx.mm = maxf(mm, TEXTE_MIN)
	tx.largeur = largeur
	_dire(tx, t)
	return tx


func _largeur(t: String, mm: float, police: Font = null) -> float:
	return (_police if police == null else police).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x / 64.0 * mm * 0.001


## La même police, lettres resserrées de `n` soixante-quatrièmes de corps (pour un libellé qui déborde d'un rien).
func _serree(n: int) -> Font:
	if not _serrees.has(n):
		var fv := FontVariation.new()
		fv.base_font = _police
		fv.spacing_glyph = -n
		_serrees[n] = fv
	return _serrees[n]


## Écrit un texte : à la taille voulue ; s'il déborde, lettres un peu resserrées, puis réduit jusqu'au plancher de
## 16 mm, puis coupé (« … »).
func _dire(tx: Texte, t: String) -> void:
	if tx.voulu == t and tx.l.text != "":
		return
	tx.voulu = t
	var mm := tx.mm
	var s := t
	var police := _police
	if tx.largeur > 0.0 and t != "":
		var w := _largeur(t, mm)
		if w > tx.largeur:
			mm = maxf(TEXTE_MIN, mm * tx.largeur / w)
			for n in [1, 2, 3]:
				if _largeur(t, mm, police) > tx.largeur:
					police = _serree(n)
			if _largeur(t, mm, police) > tx.largeur:
				while s.length() > 2 and _largeur(s + "…", mm, police) > tx.largeur:
					s = s.substr(0, s.length() - 1).strip_edges()
				s += "…"
	if tx.l.font != police:
		tx.l.font = police
	tx.l.text = s
	var px := mm * 0.001 / 64.0
	if not is_equal_approx(tx.l.pixel_size, px):
		tx.l.pixel_size = px


func _elem(id: String, pg: int, c: Vector2, t: Vector2, style := 0, zone := Vector2(-1, -1)) -> Elem:
	var e := Elem.new()
	e.id = id
	e.page = pg
	e.c = c
	e.t = t
	e.style = style
	e.zone = t if zone.x < 0.0 else zone
	e.zc = c
	_elems.append(e)
	return e


## Élément « icône au-dessus, libellé dessous ».
func _tuile_haute(id: String, pg: int, c: Vector2, t: Vector2, picto: int, coul: Color, libelle: String, mm := 17.0) -> Elem:
	var e := _elem(id, pg, c, t)
	e.icone = picto
	e.ic_coul = coul
	e.ic_t = minf(0.046, t.y * 0.46)
	e.ic_pos = Vector2(0, t.y * 0.13)
	e.texte = _texte(libelle, mm, Vector2(0, -t.y * 0.27), CLAIR, false, t.x - 0.006)
	return e


## Élément « icône à gauche, libellé à droite ».
func _tuile_large(id: String, pg: int, c: Vector2, t: Vector2, picto: int, coul: Color, libelle: String, mm := 18.0, style := 0) -> Elem:
	var e := _elem(id, pg, c, t, style)
	e.icone = picto
	e.ic_coul = coul
	e.ic_t = 0.032
	e.ic_pos = Vector2(-t.x * 0.5 + 0.034, 0)
	e.texte = _texte(libelle, mm, Vector2(-t.x * 0.5 + 0.062, 0), CLAIR, true, t.x - 0.072)
	return e


func _entete() -> void:
	for i in TITRES.size():
		var e := _elem("", i, Vector2(X0 + 0.004, Y_ENTETE), Vector2.ZERO, 0, Vector2.ZERO)
		e.plaque = false
		e.texte = _texte(TITRES[i], 27.0, Vector2.ZERO, BLANC, true)
		e.tx_actif = BLANC
		var note := ""
		if i == ACCUEIL:
			note = "le corps galaxie"
		elif i == MONTRER:
			note = "un système à la fois"
		elif i == VISITES:
			note = "%d parcours guidés" % _visites.size()
		if note != "":
			e.sous = _texte(note, 16.0, Vector2(_largeur(TITRES[i], 27.0) + 0.012, -0.0035), GRIS, true)
			e.so_actif = GRIS
	var f := _elem("reduire", -1, Vector2(X0 + LC - 0.052, Y_ENTETE), Vector2(0.104, 0.042), 2, Vector2(L_CARTE, 0.07))
	# zone sensible : tout l'en-tête (46 × 7 cm), titre compris. Viser le titre allume « Fermer » ; cliquer ferme.
	f.zc = Vector2(0, 0.22)
	f.texte = _texte("Fermer", 16.0, Vector2(-0.011, 0), CLAIR)
	f.icone = 26
	f.ic_t = 0.017
	f.ic_pos = Vector2(0.032, 0)
	f.ic_coul = CLAIR
	f.rang = 1
	for i in ONGLETS.size():
		var o := _elem("nav:%d" % i, -1, Vector2(X0 + 0.0545 + 0.109 * i, Y_ONGLETS), Vector2(0.105, 0.054), 3, Vector2(0.109, 0.06))
		o.remplit = false
		o.icone = ONGLETS[i][1]
		o.ic_t = 0.024
		o.ic_pos = Vector2(0, 0.0115)
		o.ic_coul = GRIS
		o.ic_actif = OR
		o.texte = _texte(ONGLETS[i][0], 16.0, Vector2(0, -0.0135), GRIS)
		o.tx_actif = BLANC
		o.rang = 5 + i
		_onglets.append(o)


func _page_accueil() -> void:
	# 1. parler au guide : l'action la plus fréquente, la plus grosse
	var m := _elem("micro", ACCUEIL, Vector2(0, Y_CONTENU - 0.056), Vector2(LC, 0.112), 1)
	m.heros = true
	m.icone = 16
	m.ic_t = 0.044
	m.ic_pos = Vector2(-LC * 0.5 + 0.062, 0)
	m.ic_coul = NUIT_ICONE
	m.ic_actif = OR
	m.texte = _texte("Parler au guide", 26.0, Vector2(-LC * 0.5 + 0.116, 0.014), BLANC, true, 0.3)
	m.sous = _texte("Pose ta question à voix haute", 16.0, Vector2(-LC * 0.5 + 0.117, -0.019), Color(0.86, 0.88, 1.0), true, 0.3)
	m.rang = 0
	_el_micro = m
	# 2. trois gestes courants
	var y := Y_CONTENU - 0.112 - 0.008 - 0.05
	var t := Vector2(0.14, 0.1)
	var r := _tuile_haute("recentrer", ACCUEIL, Vector2(-0.148, y), t, 17, CLAIR, "Recentrer")
	r.rang = 1
	var h := _tuile_haute("home", ACCUEIL, Vector2(0, y), t, 18, CLAIR, "Corps entier")
	h.rang = 2
	_el_noms = _tuile_haute("etiquettes", ACCUEIL, Vector2(0.148, y), t, 19, CLAIR, "Noms")
	_el_noms.rang = 3
	# 3. où en est-on : ce qui est montré, la visite en cours (deux raccourcis vers les onglets)
	y -= 0.05 + 0.008 + 0.049
	t = Vector2(0.214, 0.098)
	_el_montrer = _carte_etat("nav:1", Vector2(-0.111, y), t, "Montrer")
	_el_montrer.rang = 4
	_el_visite = _carte_etat("vis", Vector2(0.111, y), t, "Visite guidée")
	_el_visite.icone = 20
	_el_visite.rang = 5


func _carte_etat(id: String, c: Vector2, t: Vector2, surtitre: String) -> Elem:
	var e := _elem(id, ACCUEIL, c, t)
	e.icone = 0
	e.ic_t = 0.04
	e.ic_pos = Vector2(-t.x * 0.5 + 0.034, 0)
	e.ic_coul = CLAIR
	var x := -t.x * 0.5 + 0.063
	e.sous = _texte(surtitre, 16.0, Vector2(x, 0.016), GRIS, true, t.x - 0.069)
	e.texte = _texte("", 21.0, Vector2(x, -0.012), BLANC, true, t.x - 0.069)
	return e


func _page_montrer() -> void:
	# 4 × 4 : une tuile par système, pictogramme dans la couleur du système
	var t := Vector2(0.106, 0.0765)
	for i in _filtres.size():
		var f: Dictionary = _filtres[i]
		var id := str(f.get("id", ""))
		var pc: Array = PICTOS.get(id, [33, CLAIR])
		var col := i % 4
		var lig := i / 4
		var nom := str(f.get("nom", id))
		if _largeur(nom, 16.0, _serree(3)) > t.x - 0.007 and COURTS.has(id):
			nom = COURTS[id]
		var e := _elem("f:" + id, MONTRER, Vector2(X0 + t.x * 0.5 + 0.11 * col, Y_CONTENU - t.y * 0.5 - 0.0832 * lig), t)
		e.icone = pc[0]
		e.ic_coul = pc[1]
		e.ic_t = 0.034
		e.ic_pos = Vector2(0, 0.0125)
		e.texte = _texte(nom, 16.0, Vector2(0, -0.0215), CLAIR, false, t.x - 0.007)
		e.rang = col + lig
		_el_filtres[id] = e


func _page_visites() -> void:
	_nb_ecrans = maxi(1, ceili(_visites.size() / float(PAR_ECRAN)))
	# les cartes commencent 2 cm sous l'en-tête : aucune visite à moins de 2,5 cm de la zone « Fermer »
	var t := Vector2(LC, 0.058)
	for i in _visites.size():
		var v: Dictionary = _visites[i]
		var id := str(v.get("id", ""))
		var k := i % PAR_ECRAN
		var e := _elem("v:" + id, VISITES, Vector2(0, Y_CONTENU - 0.02 - t.y * 0.5 - 0.063 * k), t)
		e.ecran = i / PAR_ECRAN
		e.icone = 27
		e.ic_t = 0.026
		e.ic_pos = Vector2(-LC * 0.5 + 0.032, 0)
		e.ic_coul = OR
		var x := -LC * 0.5 + 0.062
		e.texte = _texte(str(v.get("titre", id)), 18.5, Vector2(x, 0.0115), BLANC, true, LC - 0.074)
		var note := ""
		if v.has("duree"):
			note = str(v.duree)
		elif v.get("etapes") is Array:
			note = "%d étapes" % (v.etapes as Array).size()
		_sous_visites[id] = note
		e.sous = _texte(note, 16.0, Vector2(x, -0.0135), GRIS, true, LC - 0.074)
		e.rang = k
		_el_visites[id] = e
	var y := Y_CONTENU - 0.326 + 0.026
	_el_stop = _tuile_large("quitter", VISITES, Vector2(X0 + 0.107, y), Vector2(0.214, 0.052), 28, BRAISE, "Arrêter la visite", 16.0, 2)
	_el_stop.ic_t = 0.02
	_el_stop.ic_pos.x = -0.107 + 0.026
	_el_stop.texte.pos.x = -0.107 + 0.046
	_el_stop.rang = 4
	_el_suite = _elem("pg", VISITES, Vector2(X0 + LC - 0.097, y), Vector2(0.194, 0.052), 2)
	_el_suite.texte = _texte("Autres visites", 16.0, Vector2(-0.012, 0), CLAIR)
	_el_suite.icone = 29
	_el_suite.ic_t = 0.018
	_el_suite.ic_pos = Vector2(0.071, 0)
	_el_suite.ic_coul = CLAIR
	_el_suite.visible = _nb_ecrans > 1
	_el_suite.rang = 5


func _page_reglages() -> void:
	var s := _elem("", REGLAGES, Vector2(X0 + 0.004, Y_CONTENU - 0.012), Vector2.ZERO, 0, Vector2.ZERO)
	s.plaque = false
	s.texte = _texte("Public", 16.0, Vector2.ZERO, GRIS, true)
	s.tx_actif = GRIS
	var y := Y_CONTENU - 0.026 - 0.031
	for i in NIVEAUX.size():
		var e := _elem("niveau:%d" % i, REGLAGES, Vector2(-0.148 + 0.148 * i, y), Vector2(0.14, 0.062))
		e.texte = _texte(NIVEAUX[i], 17.0, Vector2.ZERO, CLAIR, false, 0.132)
		e.rang = 1 + i
		_el_niveaux.append(e)
	y -= 0.031 + 0.01 + 0.031
	_el_mixte = _tuile_large("mixte", REGLAGES, Vector2(0, y), Vector2(LC, 0.062), 22, CLAIR, "Réalité mixte")
	_el_mixte.remplit = false
	_el_mixte.tx_actif = CLAIR
	_el_mixte.ic_actif = OR
	_el_mixte.bascule = true
	_el_mixte.b_pos = Vector2(LC * 0.5 - 0.042, 0)
	_el_mixte.rang = 4
	y -= 0.031 + 0.008 + 0.031
	_el_tuto = _tuile_large("tuto", REGLAGES, Vector2(-0.111, y), Vector2(0.214, 0.062), 23, CLAIR, "Tutoriel")
	_el_tuto.rang = 5
	var d := _tuile_large("depart", REGLAGES, Vector2(0.111, y), Vector2(0.214, 0.062), 24, CLAIR, "Menu de départ")
	d.rang = 6
	# tout en bas, à l'écart : quitter l'application (maintien 1,5 s)
	var q := _elem("exit", REGLAGES, Vector2(0, Y_CONTENU - 0.326 + 0.026), Vector2(LC, 0.052), 2)
	q.maintien = 1.5
	q.texte = _texte("Quitter l'application · maintenir", 16.0, Vector2(0.016, 0), GRIS)
	q.tx_actif = GRIS
	q.icone = 25
	q.ic_t = 0.02
	q.ic_pos = Vector2(-_largeur("Quitter l'application · maintenir", 16.0) * 0.5 - 0.004, 0)
	q.ic_coul = GRIS
	q.rang = 8


# ───────── état ─────────

## État de l'application, à refléter : {"micro", "visite", "filtre", "etiquettes", "niveau", "mixte", "tuto"}.
## Peut être appelé à chaque image (sans effet si rien n'a changé) ; les clés absentes gardent leur valeur.
func etat(e: Dictionary) -> void:
	var change := false
	for k in e:
		if not _etat.has(k) or _etat[k] != e[k]:
			_etat[k] = e[k]
			change = true
	if change and _pret:
		_appliquer_etat()


func _appliquer_etat() -> void:
	var micro: bool = _etat.micro
	_el_micro.actif = micro
	_dire(_el_micro.texte, "Je t'écoute" if micro else "Parler au guide")
	_dire(_el_micro.sous, "Touche pour couper le micro" if micro else "Pose ta question à voix haute")
	_el_micro.so_actif = ENCRE
	_el_noms.actif = _etat.etiquettes
	var filtre := str(_etat.filtre)
	var nom := filtre
	for f: Dictionary in _filtres:
		if str(f.get("id", "")) == filtre:
			nom = str(f.get("nom", filtre))
	if _largeur(nom, TEXTE_MIN) > _el_montrer.texte.largeur and COURTS.has(filtre):
		nom = COURTS[filtre]
	_dire(_el_montrer.texte, nom)
	var pc: Array = PICTOS.get(filtre, [33, CLAIR])
	_el_montrer.icone = pc[0]
	_el_montrer.ic_coul = pc[1]
	for id: String in _el_filtres:
		(_el_filtres[id] as Elem).actif = id == filtre
	var visite := str(_etat.visite)
	_dire(_el_visite.sous, "Visite en cours" if visite != "" else "Visite guidée")
	_dire(_el_visite.texte, "Arrêter" if visite != "" else "Choisir")
	_el_visite.icone = 28 if visite != "" else 20
	_el_visite.ic_coul = BRAISE if visite != "" else CLAIR
	for id: String in _el_visites:
		var e: Elem = _el_visites[id]
		e.actif = id == visite
		e.icone = 32 if id == visite else 27
		_dire(e.sous, "En cours" if id == visite else str(_sous_visites.get(id, "")))
	_el_stop.visible = visite != ""
	for i in _el_niveaux.size():
		_el_niveaux[i].actif = i == int(_etat.niveau)
	_el_mixte.actif = _etat.mixte
	_el_tuto.actif = _etat.tuto


# ───────── ouverture, pages ─────────

## Apparition animée (échelle, opacité, éléments échelonnés). Rouvert après plus de 20 s, le menu revient à l'accueil.
func ouvrir() -> void:
	if ouvert:
		return
	ouvert = true
	if _t_ferme > 20.0 or not _pret:
		page = ACCUEIL
		_ecran = 0
	_t_ferme = 0.0
	_sort = -1
	_balai = 0.0
	if _pret:
		_ind_x = _onglets[page].c.x
		_entrer(Vector2(0, -0.014), true)
	_appliquer_anim()


## Disparition animée ; le menu cesse tout de suite d'être interactif, puis ne dessine plus rien.
func fermer() -> void:
	if not ouvert:
		return
	ouvert = false
	_presse = null
	_survol_el = null
	_doigts.clear()
	_rayons.clear()
	survol = false
	survol_id = ""
	if not is_visible_in_tree():
		_anim = 0.0
	_appliquer_anim()


## Change d'onglet (0 accueil, 1 montrer, 2 visites, 3 réglages), avec la transition glissée.
func aller_page(i: int) -> void:
	i = clampi(i, 0, ONGLETS.size() - 1)
	if i == page or not _pret:
		return
	_dir = 1.0 if i > page else -1.0
	_sort = page
	_t_sort = 1.0
	page = i
	_entrer(Vector2(0.024 * _dir, 0), false)


## Position (repère monde) du centre d'un élément de la page affichée, par son action ; Vector3.ZERO s'il n'y est pas.
func centre_de(id: String) -> Vector3:
	for e in _elems:
		if e.id == id and _present(e) and e.zone != Vector2.ZERO:
			return global_transform * Vector3(e.c.x, e.c.y, 0)
	return Vector3.ZERO


func _present(e: Elem) -> bool:
	return e.visible and (e.page < 0 or e.page == page) and (e.ecran < 0 or e.ecran == _ecran)


## Relance l'apparition échelonnée des éléments de la page courante (et des permanents si `tout`).
func _entrer(venue: Vector2, tout: bool) -> void:
	var rang_max := 1.0
	for e in _elems:
		if e.page == page:
			rang_max = maxf(rang_max, e.rang)
	var pas := minf(0.022, 0.16 / rang_max) / 0.26
	for e in _elems:
		if e.page == page or (tout and e.page < 0):
			e.ap = -e.rang * pas
			e.venue = venue
			e.s = 0.0
			e.ech = 1.0
			e.v = 0.0


func _appliquer_anim() -> void:
	var r := 1.0 - _anim
	_e = 1.0 - (r * r * r if ouvert else r * r)
	_racine.scale = Vector3(lerpf(0.93, 1.0, _e), lerpf(0.93, 1.0, _e), 1.0)
	_racine.position = Vector3(0, -0.02 * (1.0 - _e), 0)
	_racine.visible = _e > 0.002 and _pret
	if _e != _alpha:
		_alpha = _e
		_mat.set_shader_parameter("opacite", _e)


func _animer(dt: float) -> void:
	var cible := 1.0 if ouvert else 0.0
	if not ouvert:
		_t_ferme += dt
	if _anim != cible:
		_anim = move_toward(_anim, cible, dt / (0.26 if ouvert else 0.16))
		_appliquer_anim()


# ───────── à chaque image ─────────

func _dans(e: Elem, p: Vector2, marge := 0.0) -> bool:
	return absf(p.x - e.zc.x) <= e.zone.x * 0.5 + marge and absf(p.y - e.zc.y) <= e.zone.y * 0.5 + marge


func _sous(p: Vector2, marge := 0.0) -> Elem:
	for e in _elems:
		if e.zone != Vector2.ZERO and _present(e) and _dans(e, p, marge):
			return e
	return null


## Change l'élément survolé par un rayon, et le note dans son historique.
func _survoler(r: Dictionary, b: Elem) -> void:
	r.el = b
	r.depuis = _horloge
	var hist: Array = r.hist
	hist.append([b, _horloge])
	while hist.size() > 1 and float(hist[1][1]) < _horloge - MEMOIRE:
		hist.pop_front()


## L'élément qu'un clic au rayon doit activer : celui survolé sans interruption depuis STABLE ; sinon (le rayon vient
## de bouger, typiquement la main qui tremble en pinçant) celui survolé le plus longtemps dans les MEMOIRE dernières
## secondes, s'il l'a été au moins STABLE ; sinon rien.
func _stable(r: Dictionary) -> Elem:
	var cur: Elem = r.el
	if cur != null and _present(cur) and _horloge - float(r.depuis) >= STABLE - 0.0005:
		return cur
	var hist: Array = r.hist
	var mieux: Elem = null
	var duree := 0.0
	var cumul := {}
	for j in hist.size():
		var el: Elem = hist[j][0]
		if el == null or not _present(el):
			continue
		var t0 := maxf(float(hist[j][1]), _horloge - MEMOIRE)
		var t1 := float(hist[j + 1][1]) if j + 1 < hist.size() else _horloge
		if t1 <= t0:
			continue
		var c: float = cumul.get(el, 0.0) + t1 - t0
		cumul[el] = c
		if c > duree:
			duree = c
			mieux = el
	return mieux if duree >= STABLE - 0.0005 else null


## (x, y, score) : score < 0 si le pointeur ne vise pas la poignée, distance du doigt (< 0,05) s'il est tout près,
## 1 + longueur du rayon s'il la vise de loin.
func _vise_poignee(p: Dictionary, inv: Transform3D) -> Vector3:
	var l: Vector3 = inv * (p.bout as Vector3)
	var ecart := Vector3(maxf(absf(l.x) - POIGNEE.x * 0.5, 0.0), maxf(absf(l.y - Y_POIGNEE) - POIGNEE.y * 0.5, 0.0), l.z).length()
	if ecart < 0.05 and l.y < Y_POIGNEE + 0.02:
		return Vector3(l.x, l.y, ecart)
	var o: Vector3 = inv * (p.o as Vector3)
	var d: Vector3 = inv.basis * (p.d as Vector3)
	if o.z > 0.0 and d.z < -1e-4:
		var t := -o.z / d.z
		var h := o + d * t
		if t <= PORTEE and absf(h.x) <= POIGNEE.x * 0.5 + 0.012 and absf(h.y - Y_POIGNEE) <= POIGNEE.y * 0.5 + 0.008:
			return Vector3(h.x, h.y, 1.0 + t)
	return Vector3(0, 0, -1)


## Id du pointeur dont le doigt (à moins de 5 cm) ou, à défaut, le rayon vise la poignée de déplacement ; sinon "".
func sur_poignee(pointeurs: Array) -> String:
	if not ouvert or _e < 0.6 or not is_visible_in_tree():
		return ""
	var inv := global_transform.affine_inverse()
	var mieux := ""
	var score := 1e9
	for i in pointeurs.size():
		var p: Dictionary = pointeurs[i]
		var v := _vise_poignee(p, inv)
		if v.z >= 0.0 and v.z < score:
			score = v.z
			mieux = str(p.get("id", i))
	if mieux != "":
		_image_poignee = Engine.get_process_frames()
	return mieux


## Lit les pointeurs, anime, et renvoie l'action déclenchée à cette image (sinon "").
func maj(pointeurs: Array, dt: float) -> String:
	var image := Engine.get_process_frames()
	_image_maj = image
	dt = minf(dt, 0.05)
	_horloge += dt
	_animer(dt)
	impacts.clear()
	_cibles.clear()
	survol_point = Vector3.ZERO
	survol = false
	var vise: Elem = null           # élément visé (rayon ou doigt tout proche)
	var tenu: Elem = null           # élément tenu à cette image
	var declenche: Elem = null      # élément sur lequel un appui vient de commencer
	var ok := _pret and ouvert and _e > 0.6 and is_visible_in_tree()
	if not ok:
		_doigts.clear()
		_rayons.clear()
	else:
		var inv := global_transform.affine_inverse()
		for i in pointeurs.size():
			var p: Dictionary = pointeurs[i]
			var par_doigt := false
			var v := _vise_poignee(p, inv)
			if v.z >= 0.0:
				_image_poignee = image
				survol = true
				if v.z >= 1.0:
					_cibles.append([v.x, v.y, ANNEAU * clampf((v.z - 1.0) / 0.7, 1.0, 3.0), 1.0, 1.0 if p.get("appui", false) else 0.0])
			if p.get("doigt", false):
				var l: Vector3 = inv * (p.bout as Vector3)
				var e: Dictionary = _doigts.get(i, {"devant": false, "sur": null})
				var dans := absf(l.x) <= DEMI.x + 0.03 and absf(l.y) <= DEMI.y + 0.03
				if e.sur != null:
					# doigt posé : il le reste tant qu'il n'est pas nettement ressorti (ou parti derrière, ou sur le côté)
					var b: Elem = e.sur
					if not _present(b) or l.z > DEGAGE or l.z < -0.07 or not _dans(b, Vector2(l.x, l.y), 0.012):
						e.sur = null
						e.devant = l.z > DEGAGE
					else:
						tenu = b
						vise = b
						par_doigt = true
				elif l.z > DEGAGE:
					e.devant = true         # le doigt est (re)passé devant : il peut appuyer
				elif l.z < -0.05:
					e.devant = false        # passé nettement derrière (par le côté) : il devra revenir par l'avant
				elif l.z < -0.01 and not e.devant:
					pass                    # il arrive par l'arrière : on l'ignore
				elif l.z <= ENFONCE and l.z > -0.05 and e.devant:
					e.devant = false
					var b := _sous(Vector2(l.x, l.y))
					if b != null:
						e.sur = b
						tenu = b
						vise = b
						declenche = b
						par_doigt = true
				if e.sur == null and e.devant and dans and l.z < 0.09:
					# tout près du menu : c'est le doigt qui désigne, pas le rayon
					par_doigt = true
					survol = true
					var b := _sous(Vector2(l.x, l.y))
					if b != null and vise == null:
						vise = b
					if absf(l.x) <= DEMI.x and absf(l.y) <= DEMI.y:
						var pres := clampf(1.0 - l.z / 0.09, 0.0, 1.0)
						_cibles.append([l.x, l.y, ANNEAU * (2.0 - pres), pres, 0.0])
						if survol_point == Vector3.ZERO:
							survol_point = global_transform * Vector3(l.x, l.y, 0.0)
				_doigts[i] = e
			if par_doigt:
				survol = true
				continue
			var o: Vector3 = inv * (p.o as Vector3)
			var d: Vector3 = inv.basis * (p.d as Vector3)
			if o.z <= 0.0 or d.z >= -1e-4:
				continue
			var t := -o.z / d.z
			if t > PORTEE:
				continue
			var h := o + d * t
			if absf(h.x) > DEMI.x or h.y > DEMI.y or h.y < Y_CARTE - H_CARTE * 0.5:
				continue
			survol = true
			var monde := global_transform * h
			impacts.append(monde)
			if survol_point == Vector3.ZERO:
				survol_point = monde
			_cibles.append([h.x, h.y, ANNEAU * clampf(t / 0.7, 1.0, 3.0), 1.0, 1.0 if p.get("appui", false) else 0.0])
			# survol magnétique et clic sur la cible stable (voir _stable)
			var hp := Vector2(h.x, h.y)
			var cle := str(p.get("id", i))
			var r: Dictionary = _rayons.get(cle, {"el": null, "depuis": 0.0, "hist": [], "appui": false, "gele": null, "t_gele": -9.0, "vu": 0})
			r.vu = image
			var b: Elem = r.el
			if b == null or not _present(b) or not _dans(b, hp, AIMANT):
				b = _sous(hp)
			if b != r.el:
				_survoler(r, b)
			var en_appui: bool = p.get("appui", false)
			var clic: bool = p.get("clic", false)
			if en_appui and not r.appui and not clic:
				# début d'un pincement : la cible est figée maintenant, avant que la main ne bouge
				r.gele = _stable(r)
				r.t_gele = _horloge
			r.appui = en_appui
			_rayons[cle] = r
			if b != null and vise == null:
				vise = b
			if clic:
				var c := _stable(r)
				var g: Elem = r.gele
				if g != null and _horloge - float(r.t_gele) <= GEL_PINCE and _present(g):
					c = g
				r.gele = null
				if c != null:
					declenche = c
					tenu = c
					if c != r.el:
						_survoler(r, c)
					vise = c
			elif en_appui and _presse != null and (b == _presse or _dans(_presse, hp, AIMANT)):
				tenu = _presse
		for cle: String in _rayons:
			var r: Dictionary = _rayons[cle]
			if r.vu != image:
				# ce rayon ne touche plus le menu
				r.appui = false
				if r.el != null:
					_survoler(r, null)
	if declenche != null and _horloge < _sourd:
		declenche = null
		tenu = null
	if vise != _survol_el and vise != null:
		touche.emit(vise.id)
	_survol_el = vise
	survol_id = vise.id if vise != null else ""
	# appui : immédiat pour un élément ordinaire, après le temps de maintien pour « Quitter »
	var resultat := ""
	if declenche != null:
		_presse = declenche
		_t_presse = 0.0
		_fait = false
	elif tenu != _presse or tenu == null:
		_presse = null
		_t_presse = 0.0
	if _presse != null and not _fait:
		_t_presse += dt
		if _presse.maintien <= 0.0 or _t_presse >= _presse.maintien:
			_fait = true
			_presse.eclat = 1.0
			resultat = _interne(_presse)
			if resultat.begins_with("v:"):
				_sourd = _horloge + SOURD_VISITE
	_rafraichir(dt)
	if resultat != "":
		active.emit(resultat)
	return resultat


## Navigation interne (onglets, écrans de visites) : ne renvoie rien. Le reste est l'action pour main.gd.
func _interne(e: Elem) -> String:
	if e.id.begins_with("nav:"):
		aller_page(int(e.id.substr(4)))
		return ""
	if e.id == "pg":
		_ecran = (_ecran + 1) % _nb_ecrans
		_entrer(Vector2(0.024, 0), false)
		_el_stop.ap = 1.0
		_el_suite.ap = 1.0
		return ""
	if e.id == "vis":
		if str(_etat.visite) != "":
			return "quitter"
		aller_page(VISITES)
		return ""
	return e.id


## Quand personne n'appelle maj à cette image, l'animation et le dessin avancent seuls.
func _process(dt: float) -> void:
	if _image_maj == Engine.get_process_frames():
		return
	dt = minf(dt, 0.05)
	_animer(dt)
	if _racine.visible and is_visible_in_tree():
		_cibles.clear()
		_survol_el = null
		_presse = null
		survol = false
		survol_id = ""
		_rafraichir(dt)


static func _vers(x: float, cible: float, k: float) -> float:
	var y := lerpf(x, cible, k)
	return cible if absf(y - cible) < 0.004 else y


func _ecrire(i: int, pos: Vector3, g: float, custom: Color, coul: Color) -> void:
	if _c_ech[i] != g or _c_pos[i] != pos:
		_c_ech[i] = g
		_c_pos[i] = pos
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(g, g, 1.0)), pos))
	if _c_cu[i] != custom:
		_c_cu[i] = custom
		_mm.set_instance_custom_data(i, custom)
	if _c_co[i] != coul:
		_c_co[i] = coul
		_mm.set_instance_color(i, coul)


## Les Label3D reconstruisent leur maillage quand leur couleur change : on quantifie, et on ne repeint que si ça change.
func _peindre(tx: Texte, coul: Color, alpha: float) -> void:
	var qa := roundi(clampf(alpha, 0.0, 1.0) * 5.0)
	var cle := coul.to_rgba32() * 8 + qa
	if cle == tx.cle:
		return
	tx.cle = cle
	tx.l.visible = qa > 0
	if qa > 0:
		tx.l.modulate = Color(coul.r, coul.g, coul.b, qa / 5.0)


func _poser(tx: Texte, base: Vector3, g: float) -> void:
	var p := Vector3(base.x + tx.pos.x * g, base.y + tx.pos.y * g, base.z + 0.0016)
	if p != tx.p_ecrit:
		tx.p_ecrit = p
		tx.l.position = p
	if g != tx.g_ecrit:
		tx.g_ecrit = g
		tx.l.scale = Vector3(g, g, 1.0)


func _cacher(tx: Texte) -> void:
	if tx != null and tx.cle != 0:
		tx.cle = 0
		tx.l.visible = false


func _rafraichir(dt: float) -> void:
	if not _pret or not _racine.visible:
		return
	var image := Engine.get_process_frames()
	var k := 1.0 - exp(-dt * 20.0)
	if _sort >= 0:
		_t_sort = maxf(0.0, _t_sort - dt / 0.11)
		if _t_sort <= 0.0:
			_sort = -1
	_balai = minf(1.0, _balai + dt / 0.55)
	_ecrire(0, Vector3(0, Y_CARTE, 0), 1.0, Color(L_CARTE, H_CARTE, _balai, 0), Color(0, 0, 0, 1))
	_poignee_s = _vers(_poignee_s, 1.0 if image - _image_poignee <= 1 else 0.0, k)
	_ecrire(1, Vector3(0, Y_POIGNEE, 0.001), 1.0, Color(POIGNEE.x, POIGNEE.y, 0, 4), Color(_poignee_s, 0, 0, 1))
	_ecrire(2, Vector3(0, Y_ONGLETS, 0.001), 1.0, Color(LC, 0.06, 0, 1 + 8 * 5), Color(0, 0, 0, 1))
	_ind_x = lerpf(_ind_x, _onglets[page].c.x, 1.0 - exp(-dt * 18.0))
	if absf(_ind_x - _onglets[page].c.x) < 0.0003:
		_ind_x = _onglets[page].c.x
	_ecrire(3, Vector3(_ind_x, Y_ONGLETS, 0.0015), 1.0, Color(0.103, 0.054, 0, 1 + 8 * 4), Color(0, 0, 0, 1))
	for i in _onglets.size():
		_onglets[i].actif = i == page
	for e in _elems:
		var sortant := e.page >= 0 and e.page == _sort
		var montre := e.visible and (e.page < 0 or e.page == page or sortant) and (e.ecran < 0 or e.ecran == _ecran)
		if not montre:
			if e.dessine:
				e.dessine = false
				for j in e.n:
					_ecrire(e.i0 + j, Vector3.ZERO, 1.0, Color(0, 0, 0, 0), Color(0, 0, 0, 0))
				_cacher(e.texte)
				_cacher(e.sous)
			e.s = 0.0
			e.e = 0.0
			e.av = 0.0
			e.ech = 1.0
			e.v = 0.0
			e.al = 1.0 if e.actif else 0.0
			e.on = e.al
			continue
		e.dessine = true
		var alpha := 1.0
		var dec := Vector2.ZERO
		var g := 1.0
		if sortant:
			alpha = _t_sort * _t_sort
			dec = Vector2(-_dir * 0.012 * (1.0 - _t_sort), 0)
		else:
			if e.ap < 1.0:
				e.ap = minf(1.0, e.ap + dt / 0.26)
			var a := clampf(e.ap, 0.0, 1.0)
			var q := 1.0 - pow(1.0 - a, 3.0)
			alpha = clampf(a * 2.4, 0.0, 1.0)
			dec = e.venue * (1.0 - q)
			g = lerpf(0.93, 1.0, q)
		var s := 1.0 if e == _survol_el and not sortant else 0.0
		var encre := 0.0
		var jauge := 0.0
		var av := s
		if e == _presse:
			av = 0.0
			if e.maintien > 0.0 and not _fait:
				jauge = clampf(_t_presse / e.maintien, 0.0, 1.0)
				s = 1.0
			else:
				encre = 1.0
		e.eclat = maxf(0.0, e.eclat - dt * 4.0)
		e.s = _vers(e.s, s, k)
		e.e = maxf(_vers(e.e, encre, k), e.eclat)
		e.al = _vers(e.al, 1.0 if e.actif else 0.0, k)
		e.on = e.al
		e.av = _vers(e.av, av, k)
		# ressort léger : l'élément survolé grossit d'un rien et dépasse un peu sa taille avant de se poser
		var cible := 1.0 + minf(0.035, 0.01 / maxf(e.t.x, e.t.y)) * s - (0.02 if e == _presse else 0.0)
		e.v += ((cible - e.ech) * 420.0 - e.v * 24.0) * dt
		e.ech += e.v * dt
		if absf(e.ech - cible) < 0.0004 and absf(e.v) < 0.004:
			e.ech = cible
			e.v = 0.0
		g *= e.ech
		var base := Vector3(e.c.x + dec.x, e.c.y + dec.y, 0.002 + AVANCE * e.av)
		var i := e.i0
		if e.plaque:
			_ecrire(i, base, g, Color(e.t.x, e.t.y, jauge, 1 + 8 * e.style), Color(e.s, e.e, e.al if e.remplit else 0.0, alpha))
			i += 1
		if e.heros:
			_ecrire(i, base + Vector3(e.ic_pos.x * g, e.ic_pos.y * g, 0.0003), g, Color(0.076, 0.076, 0, 1 + 8 * 6), Color(0, e.e, e.al, alpha))
			i += 1
		if e.icone >= 0:
			var ci := e.ic_coul.lerp(e.ic_actif, e.al)
			ci = ci.lerp(CLAIR if e.heros else ENCRE, e.e)
			if jauge > 0.0:
				ci = BLANC
			_ecrire(i, base + Vector3(e.ic_pos.x * g, e.ic_pos.y * g, 0.0006), g, Color(e.ic_t, e.icone, 0, 2), Color(ci.r, ci.g, ci.b, alpha))
			i += 1
		if e.heros:
			_ecrire(i, base + Vector3((e.t.x * 0.5 - 0.05) * g, 0, 0.0006), g, Color(0.05, 32, 0, 2), Color(ENCRE.r, ENCRE.g, ENCRE.b, alpha * e.al * (1.0 - e.e)))
			i += 1
		if e.bascule:
			_ecrire(i, base + Vector3(e.b_pos.x * g, e.b_pos.y * g, 0.0006), g, Color(0.05, 0.028, e.on, 5), Color(0, 0, 0, alpha))
		var m := roundf(e.al * 4.0) / 4.0
		var me := roundf(e.e * 4.0) / 4.0
		var at := alpha * _alpha
		if e.texte != null:
			_poser(e.texte, base, g)
			_peindre(e.texte, BLANC if jauge > 0.0 else e.texte.coul.lerp(e.tx_actif, m).lerp(ENCRE, me), at)
		if e.sous != null:
			_poser(e.sous, base, g)
			_peindre(e.sous, e.sous.coul.lerp(e.so_actif, m).lerp(ENCRE, me), at)
	# curseurs (un par rayon ou doigt tout proche, deux au plus)
	var nc := mini(_cibles.size(), 2)
	for i in maxi(nc, _nc_ecrit):
		if i < nc:
			var c: Array = _cibles[i]
			_mm_c.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(c[0], c[1], 0.012)))
			_mm_c.set_instance_custom_data(i, Color(c[2], c[2], 0, 3))
			_mm_c.set_instance_color(i, Color(c[3], c[4], 0, 0))
		else:
			_mm_c.set_instance_custom_data(i, Color(0, 0, 0, 3))
	_nc_ecrit = nc
	_curseurs.visible = nc > 0
