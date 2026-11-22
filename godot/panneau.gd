class_name Panneau extends Node3D
## Panneau de boutons « holographique », utilisable au doigt (on appuie vraiment dessus) et au pointeur
## (rayon + gâchette ou pincement).
##
## Le panneau vit dans son plan local XY, face avant vers +Z ; les dimensions sont en mètres.
## À chaque image, main.gd lui donne les pointeurs suivis (un par main ou manette) :
##   {"id": String, "o": Vector3, "d": Vector3, "clic": bool, "appui": bool, "bout": Vector3, "doigt": bool}
## et reçoit l'identifiant du bouton activé à cette image (ou "").
## Le panneau ne joue aucun son : il émet `touche` quand un bouton commence à être visé, et `active` quand il est déclenché.
##
## Dessin : toutes les plaques (fond, boutons, poignée) partent en UN appel de dessin (MultiMesh + un seul shader sans
## éclairage), les curseurs en un second (seulement quand un rayon vise le panneau), puis un Label3D par texte.
##
## Apparition : `apparaitre()` / `disparaitre()` animent l'échelle et l'opacité d'un nœud interne ; la transformation et
## la propriété `visible` du panneau lui-même restent entièrement à l'appelant. Un panneau fermé (`ouvert == false`) ne
## dessine rien et n'est pas interactif ; il se rouvre par `apparaitre()`, ou d'un coup si on le cache puis le remontre
## avec `visible`.

signal touche(id: String)       # un bouton vient d'être survolé (pour jouer le petit clic)
signal active(id: String)       # un bouton vient d'être activé (même valeur que le retour de maj)

const CLAIR := Color(0.925, 0.91, 0.875)
const GRIS := Color(0.6, 0.6, 0.62)
const OR := Color(1, 0.85, 0.3)
const BLEU := Color(0.45, 0.78, 1.0)                # traits lumineux
const FOND := Color(0.02, 0.024, 0.04, 0.88)        # (anciennes teintes, gardées pour compatibilité)
const REPOS := Color(0.085, 0.1, 0.15, 0.94)
const SURVOL := Color(0.2, 0.25, 0.36, 0.97)
const PRESSE := Color(0.92, 0.91, 0.88, 1.0)
const ACCENT := Color(0.12, 0.2, 0.46, 0.96)
const ALLUME := Color(0.33, 0.26, 0.06, 0.96)
const ENCRE := Color(0.05, 0.05, 0.06)
const GRIS_SOUS := Color(0.72, 0.74, 0.78)          # seconde ligne d'un bouton
const ENFONCE := 0.004          # le doigt « appuie » quand il passe à moins de 4 mm du plan
const DEGAGE := 0.018           # … et doit ressortir à plus de 18 mm avant de pouvoir réappuyer
const PORTEE := 6.0             # longueur maximale d'un rayon
const AVANCE := 0.008           # un bouton survolé s'avance de 8 mm vers l'utilisateur
const POIGNEE := Vector2(0.12, 0.015)   # barre de saisie sous le panneau
const ANNEAU := 0.008           # diamètre du curseur pour un panneau proche (il grossit avec la distance du rayon)
const TEXTE_MIN := 16.0         # hauteur minimale (mm) du texte d'un bouton lu à LECTURE mètres
const LECTURE := 0.6

## Un seul shader pour tout : `genre` 0 = fond, 1 = bouton, 2 = poignée, 3 = anneau du curseur.
## Par instance : CUSTOM = (largeur, hauteur, jauge, genre), COLOR = (survol, pressé, allumé, accent).
const CODE_PLAQUE := "
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float opacite = 1.0;
uniform float voile = 0.5;          // opacité du verre d'un bouton au repos
uniform float eclair = 0.0;         // traits plus vifs pendant l'apparition
uniform vec3 bleu : source_color = vec3(0.45, 0.78, 1.0);
uniform vec3 dore : source_color = vec3(1.0, 0.85, 0.3);
uniform vec3 clair : source_color = vec3(0.925, 0.91, 0.875);
uniform vec3 nuit : source_color = vec3(0.02, 0.035, 0.075);
uniform vec3 verre : source_color = vec3(0.09, 0.15, 0.25);
uniform vec3 verre_accent : source_color = vec3(0.09, 0.27, 0.66);
uniform vec3 verre_dore : source_color = vec3(0.36, 0.26, 0.05);
uniform vec3 braise : source_color = vec3(1.0, 0.42, 0.2);
const float MARGE = 0.008;          // débord du quad, pour le halo
varying vec2 p;                     // position dans la plaque, en mètres
varying vec4 donnees;
varying vec4 etat;

void vertex() {
	donnees = INSTANCE_CUSTOM;
	etat = COLOR;
	vec2 t = donnees.x > 0.0 ? donnees.xy + 2.0 * MARGE : vec2(0.0);
	p = VERTEX.xy * t;
	VERTEX = vec3(p, 0.0);
}

float boite(vec2 q, vec2 demi, float r) {
	vec2 w = abs(q) - demi + r;
	return length(max(w, 0.0)) + min(max(w.x, w.y), 0.0) - r;
}

void sur(inout vec3 c, inout float a, vec3 c2, float a2) {
	a2 = clamp(a2, 0.0, 1.0);
	float s = a2 + a * (1.0 - a2);
	c = (c2 * a2 + c * a * (1.0 - a2)) / max(s, 0.0001);
	a = s;
}

void fragment() {
	vec2 demi = donnees.xy * 0.5;
	float genre = donnees.w;
	vec3 c = vec3(0.0);
	float a = 0.0;
	if (genre < 0.5) {
		// fond : voile sombre très translucide, liseré fin, coins marqués
		float d = boite(p, demi, 0.008);
		float l = max(fwidth(d), 0.00002);
		float dedans = 1.0 - smoothstep(-l, l, d);
		c = nuit + bleu * 0.03 * smoothstep(-demi.y, demi.y, p.y);
		a = 0.66 * dedans;
		sur(c, a, bleu, (0.09 + 0.2 * eclair) * exp(d / 0.014) * dedans);
		vec2 k = demi - abs(p);
		float coin = 1.0 - smoothstep(0.026, 0.027, max(k.x, k.y));
		float ep = max(mix(0.0009, 0.0024, coin), 1.2 * l);
		float trait = smoothstep(-ep - l, -ep + l, d) * dedans;
		sur(c, a, mix(bleu, vec3(1.0), 0.3 * coin + 0.4 * eclair), trait * mix(0.4, 1.0, max(coin, eclair)));
	} else if (genre < 1.5) {
		// bouton de verre
		float s = etat.r;
		float e = etat.g;
		float al = etat.b;
		float ac = etat.a;
		float d = boite(p, demi, min(0.009, demi.y * 0.28));
		float l = max(fwidth(d), 0.00002);
		float dedans = 1.0 - smoothstep(-l, l, d);
		vec3 tc = mix(bleu, dore, al);
		vec3 f = mix(mix(verre, verre_accent, ac), verre_dore, al);
		float fa = min(1.0, voile + 0.14 * max(ac, al) + 0.1 * s);
		f = mix(f, f * 1.45 + tc * 0.07, s);
		f += vec3(0.018) * smoothstep(0.0, demi.y, p.y);
		if (donnees.z > 0.001) {
			float x = (p.x + demi.x) / (2.0 * demi.x);
			float lx = max(fwidth(x), 0.0005);
			float rempli = 1.0 - smoothstep(donnees.z - lx, donnees.z + lx, x);
			float front = 1.0 - smoothstep(0.0, 0.0022, abs(x - donnees.z) * 2.0 * demi.x);
			f = mix(f, braise, 0.92 * rempli);
			f = mix(f, vec3(1.0, 0.9, 0.8), front);
			fa = mix(fa, 0.94, max(rempli, front));
		}
		f = mix(f, clair, e);
		fa = mix(fa, 0.97, e);
		c = f;
		a = fa * dedans;
		sur(c, a, tc, (0.07 + 0.3 * s + 0.16 * al) * (1.0 - e) * exp(d / 0.005) * dedans);
		float ep = max(mix(0.001, 0.0018, s), 1.2 * l);
		float trait = smoothstep(-ep - l, -ep + l, d) * dedans;
		sur(c, a, mix(tc, vec3(1.0), 0.5 * s), trait * mix(0.5 + 0.35 * max(al, ac) + 0.3 * eclair, 1.0, s) * (1.0 - 0.7 * e));
		sur(c, a, mix(tc, vec3(1.0), 0.4 * e), (0.5 * s + 0.16 * al + 0.5 * e) * exp(-max(d, 0.0) / 0.0026) * (1.0 - dedans));
	} else if (genre < 2.5) {
		// poignée de saisie : pastille allongée, trois points
		float s = etat.r;
		float d = boite(p, demi, demi.y);
		float l = max(fwidth(d), 0.00002);
		float dedans = 1.0 - smoothstep(-l, l, d);
		c = mix(nuit, bleu, 0.3 * s);
		a = (0.62 + 0.2 * s) * dedans;
		float ep = max(mix(0.0009, 0.0016, s), 1.2 * l);
		float trait = smoothstep(-ep - l, -ep + l, d) * dedans;
		sur(c, a, mix(bleu, vec3(1.0), 0.5 * s), trait * mix(0.5, 1.0, s));
		float pts = min(length(p), min(length(p - vec2(0.012, 0.0)), length(p + vec2(0.012, 0.0)))) - 0.0017;
		sur(c, a, mix(bleu, vec3(1.0), 0.6 * s), (1.0 - smoothstep(-l, l, pts)) * mix(0.65, 1.0, s));
		sur(c, a, bleu, 0.55 * s * exp(-max(d, 0.0) / 0.0026) * (1.0 - dedans));
	} else {
		// curseur : anneau clair cerné de sombre (visible sur un bouton pressé comme sur le fond)
		float r_ext = demi.x;
		float ep = r_ext * 0.24;
		float rr = length(p);
		float d = abs(rr - (r_ext - ep * 0.5)) - ep * 0.5;
		float l = max(fwidth(d), 0.00002);
		c = vec3(0.0, 0.01, 0.03);
		a = 0.5 * (1.0 - smoothstep(0.0, ep * 1.3, d));
		sur(c, a, mix(clair, vec3(1.0), 0.6), 1.0 - smoothstep(-l, l, d));
		sur(c, a, vec3(1.0), (1.0 - smoothstep(-l, l, rr - r_ext * 0.36)) * etat.g);
		a *= etat.r;
	}
	ALBEDO = c;
	ALPHA = a * opacite;
}
"

class Bouton:
	var id: String
	var centre: Vector2
	var taille: Vector2
	var maintien: float
	var texte: Label3D
	var sous: Label3D
	var allume := false
	var visible := true
	var accent := false
	var mm_voulu := 0.0         # hauteur de texte demandée par taille_texte (0 : automatique)
	var mm_sous := 14.0
	var s := 0.0                # survol (0..1, lissé)
	var e := 0.0                # pressé : 0 texte clair, 1 plaque claire et texte sombre
	var al := 0.0               # allumé
	var ac := 0.0               # accent
	var av := 0.0               # avancement vers l'utilisateur (0..1)
	var eclat := 0.0            # bref éclair après une activation
	var sale := true            # à réécrire dans le MultiMesh
	var ecrit := Color(-1, -1, -1, -1)
	var jauge_ecrite := -1.0
	var av_ecrit := -1.0
	var encre_peinte := -1.0
	var or_peint := false
	var mm_tient := 16.0         # taille de texte qui tient dans ce bouton
	var mm_sous_tient := 14.0

static var _shader_commun: Shader
static var _maille_commune: ArrayMesh

var survol := ""                        # id du bouton visé à cette image
var impacts: Array[Vector3] = []        # points (repère monde) où les rayons touchent le panneau
var survol_point := Vector3.ZERO        # point (repère monde) visé sur le panneau à cette image, sinon Vector3.ZERO
var opacite := 1.0: set = _regler_opacite
var ouvert := true: set = _regler_ouvert    # faux : fermé ou en train de disparaître (non interactif)

var _police: Font
var _boutons: Array[Bouton] = []
var _par_id := {}
var _etiquettes: Array[Label3D] = []    # textes libres, avec leur couleur d'origine (pour le fondu)
var _teintes: Array[Color] = []
var _demi := Vector2.ZERO               # demi-taille de la zone sensible (fond, ou boîte englobante des boutons)
var _taille_fond := Vector2.ZERO
var _presse := ""                       # bouton actuellement tenu (doigt posé ou gâchette tenue)
var _t_presse := 0.0
var _fait := false                      # le bouton tenu a déjà été activé : il faut relâcher
var _doigts := {}                       # par pointeur : {"devant": bool, "sur": String}

var _racine: Node3D                     # tout le dessin ; c'est lui qu'on met à l'échelle pour l'apparition
var _mm: MultiMesh                      # 0 fond, 1 poignée, 2… boutons
var _mat: ShaderMaterial
var _curseurs: MultiMeshInstance3D
var _mm_c: MultiMesh
var _cibles: Array = []                 # curseurs de cette image : [x, y, diamètre, opacité, clic]
var _nc_ecrit := 0
var _tout_sale := true
var _alpha := 1.0                       # opacité réellement dessinée (opacite × apparition)
var _anim := 1.0                        # avancement de l'apparition (0 fermé, 1 ouvert)
var _e := 1.0                           # le même, adouci
var _ouvre := true
var _duree := 0.25
var _image_maj := -1
var _image_visible := -1
var _avec_poignee := false
var _poignee_s := 0.0
var _image_poignee := -10
var _facteur := 1.0                     # agrandissement du texte automatique selon la distance de lecture
var _a_mesurer := true
var _textes_sales := false


func _init(police: Font = null) -> void:
	_police = police
	if _police == null:
		# police en champ de distance : reste nette à toute taille dans le casque
		var base := ThemeDB.fallback_font
		if base is FontFile:
			var f := (base as FontFile).duplicate() as FontFile
			f.multichannel_signed_distance_field = true
			f.msdf_pixel_range = 12
			_police = f
		else:
			_police = base
	if _shader_commun == null:
		_shader_commun = Shader.new()
		_shader_commun.code = CODE_PLAQUE
		var t := []
		t.resize(Mesh.ARRAY_MAX)
		t[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)])
		t[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		t[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
		_maille_commune = ArrayMesh.new()
		_maille_commune.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, t)
	_racine = Node3D.new()
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

func _etiquette(pos: Vector3, mm: float, couleur: Color, largeur := 0.0) -> Label3D:
	var l := Label3D.new()
	l.font = _police
	l.font_size = 64
	l.pixel_size = mm * 0.001 / 64.0
	l.outline_size = 0
	l.modulate = Color(couleur, couleur.a * _alpha)
	l.shaded = false
	l.render_priority = 2
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if largeur > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = largeur / l.pixel_size
	l.position = pos
	_racine.add_child(l)
	return l


## Plaque sombre translucide derrière les boutons (facultatif). Elle délimite aussi la zone où le rayon « accroche ».
func fond(taille: Vector2) -> void:
	_taille_fond = taille
	_demi = taille * 0.5
	_tout_sale = true


## Texte libre, non cliquable (peut être appelé plusieurs fois). Hauteur en millimètres.
func titre(t: String, centre: Vector2, mm := 22.0, couleur := CLAIR) -> void:
	var l := _etiquette(Vector3(centre.x, centre.y, 0.003), mm, couleur)
	l.text = t
	_etiquettes.append(l)
	_teintes.append(couleur)


## Bouton. `maintien` > 0 : il faut rester appuyé ce nombre de secondes (une jauge se remplit).
func bouton(id: String, texte: String, centre: Vector2, taille: Vector2, maintien := 0.0) -> void:
	var b := Bouton.new()
	b.id = id
	b.centre = centre
	b.taille = taille
	b.maintien = maintien
	b.texte = _etiquette(Vector3(centre.x, centre.y, 0.003), TEXTE_MIN, CLAIR, taille.x - 0.016)
	b.texte.text = texte
	_boutons.append(b)
	_par_id[id] = b
	_ajuster(b)
	if _taille_fond == Vector2.ZERO:
		_demi = _demi.max(centre.abs() + taille * 0.5 + Vector2(0.03, 0.03))
	_tout_sale = true


## Seconde ligne, plus petite, sous le texte d'un bouton (ex. « un conte dans le corps »).
func sous_titre(id: String, texte: String, mm := 14.0) -> void:
	var b: Bouton = _par_id.get(id)
	if b == null:
		return
	if b.sous == null:
		b.sous = _etiquette(Vector3(b.centre.x, b.centre.y - b.taille.y * 0.24, b.texte.position.z), mm, GRIS_SOUS, b.taille.x - 0.012)
		b.texte.position.y = b.centre.y + b.taille.y * 0.16
	b.mm_sous = mm
	b.sous.text = texte
	b.encre_peinte = -1.0
	_ajuster(b)
	_peindre(b)


## Hauteur du texte d'un bouton, en millimètres (par défaut : proportionnelle à la hauteur du bouton et à la distance
## de lecture). Dans tous les cas le texte est réduit s'il le faut pour tenir dans le bouton.
func taille_texte(id: String, mm: float) -> void:
	var b: Bouton = _par_id.get(id)
	if b != null:
		b.mm_voulu = mm
		_ajuster(b)


func libelle(id: String, texte: String) -> void:
	var b: Bouton = _par_id.get(id)
	if b != null and b.texte.text != texte:
		b.texte.text = texte
		_ajuster(b)


## État « activé » : contour et verre dorés.
func allume(id: String, oui: bool) -> void:
	var b: Bouton = _par_id.get(id)
	if b != null:
		b.allume = oui
		if not _se_voit():
			b.al = 1.0 if oui else 0.0


## Bouton principal du panneau (verre bleu plus soutenu), pour guider l'œil.
func accent(id: String, oui: bool) -> void:
	var b: Bouton = _par_id.get(id)
	if b != null:
		b.accent = oui
		if not _se_voit():
			b.ac = 1.0 if oui else 0.0


func montre(id: String, oui: bool) -> void:
	var b: Bouton = _par_id.get(id)
	if b == null:
		return
	b.visible = oui
	b.sale = true
	b.texte.visible = oui
	if b.sous != null:
		b.sous.visible = oui
	if not oui and _presse == id:
		_presse = ""


## Barre de saisie discrète sous le panneau (≈ 12 cm × 1,5 cm). Le déplacement lui-même est fait par l'appelant.
func poignee(oui := true) -> void:
	_avec_poignee = oui
	_tout_sale = true


## Id du pointeur dont le doigt (`bout` à moins de 5 cm) ou, à défaut, le rayon vise la poignée ; sinon "".
func sur_poignee(pointeurs: Array) -> String:
	if not _avec_poignee or not ouvert or opacite <= 0.5 or not is_visible_in_tree():
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


## Fait apparaître le panneau (échelle + opacité). Le rend visible s'il ne l'était pas.
func apparaitre(duree := 0.25) -> void:
	var neuf := not is_visible_in_tree() or _image_visible == Engine.get_process_frames()
	var e := 0.0 if neuf else _e
	visible = true
	ouvert = true
	_duree = duree
	_anim = 1.0 if duree <= 0.0 or e >= 1.0 else 1.0 - pow(1.0 - e, 1.0 / 3.0)
	_a_mesurer = true
	_appliquer_anim()


## Fait disparaître le panneau : il cesse tout de suite d'être interactif, puis ne dessine plus rien.
## (`visible` n'est pas modifié : l'appelant en reste maître.)
func disparaitre(duree := 0.18) -> void:
	if not ouvert:
		return
	var e := _e
	ouvert = false
	_duree = duree
	_anim = 0.0 if duree <= 0.0 or not is_visible_in_tree() else 1.0 - sqrt(maxf(0.0, 1.0 - e))
	_appliquer_anim()


func _regler_ouvert(v: bool) -> void:
	ouvert = v
	_ouvre = v
	_anim = 1.0 if v else 0.0
	if not v:
		_presse = ""
		_doigts.clear()
	if _racine != null:
		_appliquer_anim()


func _regler_opacite(v: float) -> void:
	opacite = clampf(v, 0.0, 1.0)
	_appliquer_alpha()


func _appliquer_anim() -> void:
	var r := 1.0 - _anim
	_e = 1.0 - (r * r * r if _ouvre else r * r)
	_racine.scale = Vector3(lerpf(0.9, 1.0, _e), lerpf(0.55, 1.0, _e), 1.0)
	_racine.visible = _e > 0.002
	_mat.set_shader_parameter("eclair", 1.0 - _e if _ouvre else 0.0)
	_appliquer_alpha()


func _appliquer_alpha() -> void:
	var a := opacite * _e
	if a == _alpha:
		return
	_alpha = a
	_mat.set_shader_parameter("opacite", a)
	for i in _etiquettes.size():
		_etiquettes[i].modulate = Color(_teintes[i], _teintes[i].a * a)
	for b in _boutons:
		b.encre_peinte = -1.0
		_peindre(b)


func _se_voit() -> bool:
	return is_visible_in_tree() and _alpha > 0.02


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_image_visible = Engine.get_process_frames()
		_a_mesurer = true
		if not ouvert:
			ouvert = true       # remontré de l'extérieur par `visible` : là d'un coup, comme avant


## Ajuste les textes d'un bouton : taille demandée (ou automatique), relevée s'il le faut jusqu'au plancher de
## lisibilité (16 mm à 60 cm, proportionnel à la distance de lecture), puis réduite jusqu'à tenir dans le bouton
## (retour à la ligne compris).
func _ajuster(b: Bouton) -> void:
	var plancher := TEXTE_MIN * _facteur
	var mm := b.mm_voulu
	if mm <= 0.0:
		mm = clampf(b.taille.y * 1000.0 * 0.26, TEXTE_MIN, 30.0)
	mm = maxf(mm, minf(plancher, b.taille.y * 1000.0 * (0.42 if b.sous == null else 0.32)))
	b.mm_tient = _caser(b.texte, mm, b.taille.x - 0.016, b.taille.y * (0.84 if b.sous == null else 0.44))
	if b.sous != null:
		b.mm_sous_tient = _caser(b.sous, maxf(b.mm_sous, 0.6 * plancher), b.taille.x - 0.012, b.taille.y * 0.4)
	_textes_sales = true


## Pose le texte à `mm` millimètres, ou moins s'il le faut pour tenir dans largeur × hauteur ; renvoie la taille retenue.
func _caser(l: Label3D, mm: float, largeur: float, hauteur: float) -> float:
	if l.text != "" and _police != null:
		for _i in 40:
			var px := mm * 0.001 / 64.0
			var t := _police.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, largeur / px, 64, -1,
				TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
			if (t.x * px <= largeur + 0.0005 and t.y * px <= hauteur) or mm <= 8.0:
				break
			mm *= 0.96
	var p := mm * 0.001 / 64.0
	if not is_equal_approx(l.pixel_size, p):
		l.pixel_size = p
	l.width = largeur / p
	return mm


## Les boutons semblables (même taille, même taille de texte demandée) partagent la plus petite taille retenue :
## un libellé long ne donne pas un bouton écrit plus petit que ses voisins.
func _harmoniser() -> void:
	_textes_sales = false
	for b in _boutons:
		var m := b.mm_tient
		var ms := b.mm_sous_tient
		for c in _boutons:
			if c.texte.text != "" and c.taille.is_equal_approx(b.taille) and (c.sous == null) == (b.sous == null) and is_equal_approx(c.mm_voulu, b.mm_voulu):
				m = minf(m, c.mm_tient)
				if c.sous != null and is_equal_approx(c.mm_sous, b.mm_sous):
					ms = minf(ms, c.mm_sous_tient)
		if not is_equal_approx(b.texte.pixel_size, m * 0.001 / 64.0):
			_caser(b.texte, m, b.taille.x - 0.016, b.taille.y * (0.84 if b.sous == null else 0.44))
		if b.sous != null and not is_equal_approx(b.sous.pixel_size, ms * 0.001 / 64.0):
			_caser(b.sous, ms, b.taille.x - 0.012, b.taille.y * 0.4)


## Distance de lecture (mesurée à chaque apparition) : le plancher de lisibilité des textes en dépend.
func _mesurer() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var f := clampf(cam.global_position.distance_to(global_position) / LECTURE, 1.0, 2.5)
	if absf(f - _facteur) > 0.08:
		_facteur = f
		for b in _boutons:
			_ajuster(b)


# ───────── à chaque image ─────────

func _sous(p: Vector2, marge := 0.0) -> Bouton:
	for b in _boutons:
		if b.visible and absf(p.x - b.centre.x) <= b.taille.x * 0.5 + marge and absf(p.y - b.centre.y) <= b.taille.y * 0.5 + marge:
			return b
	return null


func _y_poignee() -> float:
	return -_demi.y - 0.014 - POIGNEE.y * 0.5


## (x, y, score) dans le repère du panneau : score < 0 si le pointeur ne vise pas la poignée, distance du doigt
## (< 0,05) s'il est tout près, 1 + longueur du rayon s'il la vise de loin.
func _vise_poignee(p: Dictionary, inv: Transform3D) -> Vector3:
	var cy := _y_poignee()
	var l: Vector3 = inv * (p.bout as Vector3)
	var ecart := Vector3(maxf(absf(l.x) - POIGNEE.x * 0.5, 0.0), maxf(absf(l.y - cy) - POIGNEE.y * 0.5, 0.0), l.z).length()
	if ecart < 0.05:
		return Vector3(l.x, l.y, ecart)
	var o: Vector3 = inv * (p.o as Vector3)
	var d: Vector3 = inv.basis * (p.d as Vector3)
	if o.z > 0.0 and d.z < -1e-4:
		var t := -o.z / d.z
		var h := o + d * t
		if t <= PORTEE and absf(h.x) <= POIGNEE.x * 0.5 + 0.012 and absf(h.y - cy) <= POIGNEE.y * 0.5 + 0.012:
			return Vector3(h.x, h.y, 1.0 + t)
	return Vector3(0, 0, -1)


## Lit les pointeurs, met à jour le retour visuel, et renvoie l'id du bouton activé à cette image (sinon "").
func maj(pointeurs: Array, dt: float) -> String:
	var image := Engine.get_process_frames()
	_image_maj = image
	_animer(dt)
	impacts.clear()
	_cibles.clear()
	survol_point = Vector3.ZERO
	var vise := ""              # bouton visé (rayon ou doigt tout proche)
	var tenu := ""              # bouton tenu à cette image (doigt posé, ou rayon + gâchette maintenue)
	var declenche := ""         # bouton sur lequel un appui vient de commencer
	var ok := ouvert and opacite > 0.5 and is_visible_in_tree()
	if not ok:
		_doigts.clear()
	else:
		var inv := global_transform.affine_inverse()
		for i in pointeurs.size():
			var p: Dictionary = pointeurs[i]
			var par_doigt := false
			if _avec_poignee:
				var v := _vise_poignee(p, inv)
				if v.z >= 0.0:
					_image_poignee = image
					if v.z >= 1.0:
						_cibles.append([v.x, v.y, ANNEAU * clampf((v.z - 1.0) / 0.7, 1.0, 3.0), 1.0, 1.0 if p.get("appui", false) else 0.0])
			if p.get("doigt", false):
				var l: Vector3 = inv * (p.bout as Vector3)
				var e: Dictionary = _doigts.get(i, {"devant": false, "sur": ""})
				var dans := absf(l.x) <= _demi.x + 0.03 and absf(l.y) <= _demi.y + 0.03
				if e.sur != "":
					# doigt posé : il reste posé tant qu'il n'est pas nettement ressorti (ou parti loin derrière, ou sur le côté)
					var b: Bouton = _par_id.get(e.sur)
					if b == null or not b.visible or l.z > DEGAGE or l.z < -0.07 or _sous(Vector2(l.x, l.y), 0.012) != b:
						e.sur = ""
						e.devant = l.z > DEGAGE
					else:
						tenu = e.sur
						vise = e.sur
						par_doigt = true
				elif l.z > DEGAGE:
					e.devant = true         # le doigt est (re)passé devant : il peut appuyer
				elif l.z < -0.01 and not e.devant:
					pass                    # il arrive par l'arrière : on l'ignore
				elif l.z <= ENFONCE and l.z > -0.05 and e.devant:
					e.devant = false
					var b := _sous(Vector2(l.x, l.y))
					if b != null:
						e.sur = b.id
						tenu = b.id
						vise = b.id
						declenche = b.id
						par_doigt = true
				if e.sur == "" and e.devant and dans and l.z < 0.09:
					# tout près du panneau : c'est le doigt qui désigne, pas le rayon
					par_doigt = true
					var b := _sous(Vector2(l.x, l.y))
					if b != null and vise == "":
						vise = b.id
					if absf(l.x) <= _demi.x and absf(l.y) <= _demi.y:
						# une petite cible se resserre sous le doigt à mesure qu'il approche
						var pres := clampf(1.0 - l.z / 0.09, 0.0, 1.0)
						_cibles.append([l.x, l.y, ANNEAU * (2.0 - pres), pres, 0.0])
						if survol_point == Vector3.ZERO:
							survol_point = global_transform * Vector3(l.x, l.y, 0.0)
				_doigts[i] = e
			if par_doigt:
				continue
			var o: Vector3 = inv * (p.o as Vector3)
			var d: Vector3 = inv.basis * (p.d as Vector3)
			if o.z <= 0.0 or d.z >= -1e-4:
				continue
			var t := -o.z / d.z
			if t > PORTEE:
				continue
			var h := o + d * t
			if absf(h.x) > _demi.x or absf(h.y) > _demi.y:
				continue
			var monde := global_transform * h
			impacts.append(monde)
			if survol_point == Vector3.ZERO:
				survol_point = monde
			_cibles.append([h.x, h.y, ANNEAU * clampf(t / 0.7, 1.0, 3.0), 1.0, 1.0 if p.get("appui", false) else 0.0])
			var b := _sous(Vector2(h.x, h.y))
			if b == null:
				continue
			if vise == "":
				vise = b.id
			if p.get("clic", false):
				declenche = b.id
				tenu = b.id
			elif p.get("appui", false) and _presse == b.id:
				tenu = b.id
	if vise != survol and vise != "":
		touche.emit(vise)
	survol = vise
	# appui : immédiat pour un bouton ordinaire, après le temps de maintien pour les autres
	var resultat := ""
	if declenche != "":
		_presse = declenche
		_t_presse = 0.0
		_fait = false
	elif tenu != _presse or tenu == "":
		_presse = ""
		_t_presse = 0.0
	if _presse != "" and not _fait:
		var b: Bouton = _par_id[_presse]
		_t_presse += dt
		if b.maintien <= 0.0 or _t_presse >= b.maintien:
			_fait = true
			b.eclat = 1.0
			resultat = b.id
	_rafraichir(dt)
	if resultat != "":
		active.emit(resultat)
	return resultat


## Quand personne n'appelle maj à cette image (panneau simplement montré), l'animation et le dessin avancent seuls.
func _process(dt: float) -> void:
	if _image_maj == Engine.get_process_frames():
		return
	_animer(dt)
	if _racine.visible and is_visible_in_tree():
		_cibles.clear()
		if survol != "" or _presse != "":
			survol = ""
			_presse = ""
		_rafraichir(dt)


func _animer(dt: float) -> void:
	var cible := 1.0 if ouvert else 0.0
	if _anim != cible:
		_anim = move_toward(_anim, cible, dt / maxf(_duree, 0.001))
		_appliquer_anim()


static func _vers(x: float, cible: float, k: float) -> float:
	var y := lerpf(x, cible, k)
	return cible if absf(y - cible) < 0.004 else y


func _ecrire(i: int, pos: Vector3, taille: Vector2, jauge: float, genre: float, etat: Color) -> void:
	_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
	_mm.set_instance_custom_data(i, Color(taille.x, taille.y, jauge, genre))
	_mm.set_instance_color(i, etat)


## Retour visuel : lisse les états et ne réécrit que ce qui a changé.
func _rafraichir(dt: float) -> void:
	if _a_mesurer:
		_a_mesurer = false
		_mesurer()
	if _textes_sales:
		_harmoniser()
	var tout := _tout_sale
	if _mm.instance_count != 2 + _boutons.size():
		_mm.instance_count = 2 + _boutons.size()
		tout = true
	var image := Engine.get_process_frames()
	var k := 1.0 - exp(-dt * 22.0)
	if not _se_voit():
		k = 1.0                 # rien à l'écran : pas de transition à montrer
	var ps := _vers(_poignee_s, 1.0 if _avec_poignee and image - _image_poignee <= 1 else 0.0, k)
	if tout:
		_tout_sale = false
		var bas := _demi.y + 0.05
		var boite := AABB(Vector3(-_demi.x - 0.03, -bas, -0.01), Vector3(_demi.x * 2.0 + 0.06, bas + _demi.y + 0.03, 0.04))
		_mm.custom_aabb = boite
		_mm_c.custom_aabb = boite
		_mat.set_shader_parameter("voile", 0.5 if _taille_fond != Vector2.ZERO else 0.8)
		_ecrire(0, Vector3.ZERO, _taille_fond, 0.0, 0.0, Color.WHITE)
	if tout or ps != _poignee_s:
		_poignee_s = ps
		_ecrire(1, Vector3(0, _y_poignee(), 0.001), POIGNEE if _avec_poignee else Vector2.ZERO, 0.0, 2.0, Color(ps, 0, 0, 0))
	for i in _boutons.size():
		var b := _boutons[i]
		if not b.visible:
			if tout or b.sale:
				b.sale = false
				b.ecrit = Color(-1, -1, -1, -1)
				_ecrire(2 + i, Vector3.ZERO, Vector2.ZERO, 0.0, 1.0, Color.BLACK)
			continue
		var s := 1.0 if b.id == survol else 0.0
		var encre := 0.0
		var jauge := 0.0
		var av := s
		if b.id == _presse:
			av = 0.0            # enfoncé
			if b.maintien > 0.0 and not _fait:
				jauge = clampf(_t_presse / b.maintien, 0.0, 1.0)
				s = 1.0
			else:
				encre = 1.0
		b.eclat = maxf(0.0, b.eclat - dt * 4.0)
		b.s = _vers(b.s, s, k)
		b.e = maxf(_vers(b.e, encre, k), b.eclat)
		b.al = _vers(b.al, 1.0 if b.allume else 0.0, k)
		b.ac = _vers(b.ac, 1.0 if b.accent else 0.0, k)
		b.av = _vers(b.av, av, k)
		var etat := Color(b.s, b.e, b.al, b.ac)
		if tout or b.sale or etat != b.ecrit or jauge != b.jauge_ecrite or b.av != b.av_ecrit:
			b.sale = false
			b.ecrit = etat
			b.jauge_ecrite = jauge
			b.av_ecrit = b.av
			var z := 0.0015 + AVANCE * b.av
			_ecrire(2 + i, Vector3(b.centre.x, b.centre.y, z), b.taille, jauge, 1.0, etat)
			b.texte.position.z = z + 0.0015
			if b.sous != null:
				b.sous.position.z = z + 0.0015
			_peindre(b)
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


## Couleur des textes d'un bouton (les Label3D reconstruisent leur maillage : on ne le fait que si ça change).
func _peindre(b: Bouton) -> void:
	if b.e == b.encre_peinte and b.allume == b.or_peint:
		return
	b.encre_peinte = b.e
	b.or_peint = b.allume
	var c := CLAIR.lerp(ENCRE, b.e)
	b.texte.modulate = Color(c, _alpha)
	if b.sous != null:
		var g := (OR.lerp(CLAIR, 0.35) if b.allume else GRIS_SOUS).lerp(ENCRE, b.e)
		b.sous.modulate = Color(g, _alpha)
