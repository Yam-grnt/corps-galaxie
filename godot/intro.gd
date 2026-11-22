class_name Intro extends Node3D
## Introduction du corps galaxie : un seul nuage de points qui se métamorphose au fil de la voix
## (nuit → galaxie → poussière d'étoiles → corps → cellule → atome → corps), puis le menu de départ.
##
## Tout est exprimé dans le repère de ce nœud : l'origine est la tête du spectateur au moment de `placer`,
## −Z est devant lui. Le nuage tient dans ~2 m, centré à 1,8 m, 20 cm sous les yeux. Rien ne bouge le spectateur.
## Les positions de chaque scène sont rangées une fois pour toutes dans les attributs du maillage ; les passages
## sont calculés par intro.gdshader (aucune mise à jour point par point pendant l'animation).

signal termine(choix: Dictionary)      # {"corps": "femme"|"homme", "niveau": 0|1|2, "mode": "descriptif"|"incarne", "nom": String, "tutoiement": bool}
signal touche(id: String)              # un bouton vient d'être survolé (pour le petit clic de main.gd)
signal demande_nom()                   # « Dis-le-moi » : ouvrir le micro, puis répondre par nom_entendu ou nom_refuse

const PanneauScript := preload("res://panneau.gd")

const N := 30000                        # points du nuage (un seul appel de dessin)
const CENTRE := Vector3(0, -0.2, -1.8)
const A_GAUCHE := Vector3(-0.58, 0, 0)  # décalage du corps quand le menu est ouvert
const T_PASSAGE := 3.8                  # durée d'une métamorphose, en secondes
const RESPIRATION := 1.2                # silence après chaque phrase
const FORMES := {"nuit": 0, "galaxie": 1, "poussiere": 2, "corps": 3, "plongee": 4, "atome": 5, "retour": 3, "menu": 3}
const NIVEAUX := ["enfant", "curieux", "scientifique"]
## Prénoms proposés pour le guide : courts, sonores, bien reconnus par une dictée française.
const PRENOMS := ["Lune", "Alba", "Zélie", "Jade", "Inès", "Sol"]
const NOM_MAX := 16                     # caractères, au plus, pour le nom du guide
const T_MESSAGE := 4.5                  # durée d'affichage d'un message (« micro indisponible »)
const Y_SOUS_TITRE := -0.55             # sous-titre de la voix : −19° d'élévation à 1,6 m
const CLAIR := Color(0.925, 0.91, 0.875)
const DEFAUT := [
	{"scene": "nuit", "texte": "Au commencement, il y a la nuit."},
	{"scene": "galaxie", "texte": "Dans la nuit, des galaxies tournent lentement."},
	{"scene": "poussiere", "texte": "Les étoiles y fabriquent une poussière qui retombe."},
	{"scene": "corps", "texte": "De cette poussière, un corps se dessine : le tien."},
	{"scene": "plongee", "texte": "En lui, des milliards de cellules, et dans chacune, des atomes."},
	{"scene": "menu", "texte": "Choisis ton corps, et entre."},
]

enum { ATTENTE, ANIMATION, MENU, FIN, TERMINE }

var impacts: Array[Vector3] = []        # bouts de rayons sur les panneaux (repère monde), pour main.gd
var choix := {"corps": "femme", "niveau": 1, "mode": "descriptif", "nom": "", "tutoiement": true}

var _sequences: Array = []
var _voix: Node
var _police: Font
var _nuage: MeshInstance3D
var _mat: ShaderMaterial
var _texte: Label3D
var _plaque: MeshInstance3D
var _bouton_passer: PanneauScript
var _menu: Depart
var _en_ligne := true
var _ecoute := false            # « Dis-le-moi » attend la réponse de main.gd
var _message := ""              # message bref à la place de la phrase du nom
var _t_message := 0.0
var _phase := ATTENTE
var _i := -1                    # séquence en cours
var _t := 0.0                   # temps écoulé dans la séquence
var _duree := 0.0               # durée sans voix (d'après la longueur du texte)
var _a_parle := false
var _t_silence := 0.0
var _temps := 0.0
var _forme := 0
var _melange := 1.0
var _fondu := 0.0
var _genre := 0.0
var _decal := Vector3.ZERO
var _t_menu := 0.0
var _t_fin := 0.0
var _texte_voulu := ""
var _alpha_texte := 0.0


# ───────── préparation ─────────

## `sequences` : [{"scene", "texte"}] ; `voix` : nœud voix.gd (ou équivalent) ; `silhouettes` : {"femme", "homme"} en
## PackedVector3Array dans le repère du modèle ; `choix_defaut` : {"corps", "niveau", "mode", "nom", "tutoiement", "en_ligne"}, toutes
## facultatives. Sans `mode`, le guide est « incarne » si `en_ligne` est donné et vrai, « descriptif » sinon ; si
## `en_ligne` est faux, la carte « Incarné » porte la mention « demande une connexion » (elle reste choisissable).
func preparer(sequences: Array, voix: Node, police: Font, silhouettes: Dictionary, choix_defaut: Dictionary) -> void:
	for e in get_children():
		e.queue_free()
	_sequences = sequences if not sequences.is_empty() else DEFAUT
	_voix = voix
	_police = police
	_en_ligne = bool(choix_defaut.get("en_ligne", true))
	var mode_defaut := "incarne" if choix_defaut.has("en_ligne") and _en_ligne else "descriptif"
	choix = {"corps": "homme" if str(choix_defaut.get("corps", "femme")) == "homme" else "femme",
		"niveau": clampi(int(choix_defaut.get("niveau", 1)), 0, 2),
		"mode": "incarne" if str(choix_defaut.get("mode", mode_defaut)) == "incarne" else "descriptif",
		"nom": former_nom(str(choix_defaut.get("nom", ""))),
		"tutoiement": bool(choix_defaut.get("tutoiement", true))}
	_ecoute = false
	_message = ""
	_t_message = 0.0
	_genre = 1.0 if choix.corps == "homme" else 0.0
	_construire_nuage(silhouettes)
	_construire_panneaux()
	_phase = ATTENTE
	_i = -1
	_forme = 0
	_melange = 1.0
	_fondu = 0.0
	_decal = Vector3.ZERO
	_alpha_texte = 0.0
	_texte_voulu = ""
	visible = true


## (Re)centre toute l'intro devant le spectateur. `avant` : direction horizontale du regard, normalisée.
func placer(tete: Vector3, avant: Vector3) -> void:
	var f := Vector3(avant.x, 0, avant.z)
	f = f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)
	# une tête trop basse (casque pas encore suivi, spectateur assis par terre) ne doit pas enfoncer le corps dans le sol
	global_transform = Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.z)), Vector3(tete.x, maxf(tete.y, 1.05), tete.z))


## Saute l'animation et ouvre le menu.
func passer() -> void:
	if _phase != ATTENTE and _phase != ANIMATION:
		return
	if _voix != null:
		_voix.call("taire")
	_i = _sequences.size()
	_texte_voulu = ""
	_ouvrir_menu()


func _hasard_boule(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if v.length_squared() <= 1.0:
			return v
	return Vector3.ZERO


func _hasard_sphere(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1, 1)
	var a := rng.randf() * TAU
	var r := sqrt(1.0 - z * z)
	return Vector3(r * cos(a), z, r * sin(a))


## Silhouette de secours : un bonhomme fait d'ellipsoïdes et de membres, dans le repère du modèle (pieds −0,98, crâne +0,96).
func _silhouette_secours(homme: bool, n: int, rng: RandomNumberGenerator) -> PackedVector3Array:
	var ep := 0.2 if homme else 0.165       # demi-largeur des épaules
	var ta := 0.135 if homme else 0.115     # taille
	var ha := 0.15 if homme else 0.17       # hanches
	# ellipsoïdes : [centre, rayons, poids]
	var blocs := [
		[Vector3(0, 0.835, 0.01), Vector3(0.09, 0.125, 0.105), 9.0],
		[Vector3(0, 0.67, 0.0), Vector3(0.05, 0.07, 0.05), 1.5],
		[Vector3(0, 0.46, 0.0), Vector3(ep, 0.17, 0.105), 16.0],
		[Vector3(0, 0.24, 0.005), Vector3(ta, 0.16, 0.09), 9.0],
		[Vector3(0, 0.05, 0.0), Vector3(ha, 0.13, 0.1), 10.0]]
	# membres : [départ, arrivée, rayon au départ, rayon à l'arrivée, poids] (côté droit ; l'autre par symétrie)
	var membres := [
		[Vector3(ep + 0.015, 0.56, 0), Vector3(ep + 0.065, 0.28, -0.01), 0.048, 0.037, 4.0],
		[Vector3(ep + 0.065, 0.28, -0.01), Vector3(ep + 0.085, 0.03, 0.03), 0.036, 0.026, 3.0],
		[Vector3(ep + 0.085, 0.03, 0.03), Vector3(ep + 0.09, -0.11, 0.04), 0.03, 0.02, 1.5],
		[Vector3(ha * 0.58, -0.02, 0), Vector3(0.095, -0.5, 0.0), 0.08, 0.052, 9.0],
		[Vector3(0.095, -0.5, 0.0), Vector3(0.09, -0.92, -0.01), 0.052, 0.032, 6.0],
		[Vector3(0.09, -0.95, -0.03), Vector3(0.095, -0.955, 0.13), 0.033, 0.025, 1.5]]
	var total := 0.0
	for b in blocs:
		total += b[2]
	for m in membres:
		total += 2.0 * m[4]
	var pts := PackedVector3Array()
	pts.resize(n)
	for i in n:
		var u := rng.randf() * total
		var fait := false
		for b in blocs:
			u -= b[2]
			if u <= 0.0:
				# plus dense vers la surface, pour que la silhouette se lise
				pts[i] = b[0] + _hasard_sphere(rng) * pow(rng.randf(), 0.25) * (b[1] as Vector3)
				fait = true
				break
		if fait:
			continue
		for m in membres:
			for cote in [1.0, -1.0]:
				u -= m[4]
				if u <= 0.0 and not fait:
					var t := rng.randf()
					var p: Vector3 = (m[0] as Vector3).lerp(m[1], t) + _hasard_sphere(rng) * pow(rng.randf(), 0.3) * lerpf(m[2], m[3], t)
					pts[i] = Vector3(p.x * cote, p.y, p.z)
					fait = true
	return pts


## Ramène une silhouette à N points, rangés par hauteur puis de gauche à droite : ainsi le point n° j de la femme et
## celui de l'homme sont voisins, et passer de l'une à l'autre ne déplace chaque point que de quelques centimètres.
func _ranger(sil: PackedVector3Array, rng: RandomNumberGenerator) -> PackedVector3Array:
	var cles := PackedInt64Array()
	cles.resize(N)
	var tmp := PackedVector3Array()
	tmp.resize(N)
	var m := sil.size()
	for i in N:
		var p := sil[i % m]
		if i >= m:
			p += _hasard_boule(rng) * 0.009     # les points réutilisés sont un peu décalés
		tmp[i] = p
		var bande := clampi(int((p.y + 1.0) * 30.0), 0, 63)
		var cx := clampi(int((p.x + 0.7) / 1.4 * 1023.0), 0, 1023)
		cles[i] = ((bande * 1024 + cx) << 16) | i
	cles.sort()
	var v := PackedVector3Array()
	v.resize(N)
	for j in N:
		v[j] = tmp[cles[j] & 0xFFFF]
	return v


func _construire_nuage(silhouettes: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122
	var fem: PackedVector3Array = silhouettes.get("femme", PackedVector3Array())
	var hom: PackedVector3Array = silhouettes.get("homme", PackedVector3Array())
	if fem.is_empty():
		fem = _silhouette_secours(false, 6000, rng)
	if hom.is_empty():
		hom = _silhouette_secours(true, 6000, rng)
	fem = _ranger(fem, rng)
	hom = _ranger(hom, rng)
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var c2 := PackedFloat32Array()
	var c3 := PackedFloat32Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	c0.resize(N * 4)
	c1.resize(N * 4)
	c2.resize(N * 4)
	c3.resize(N * 4)
	uv.resize(N)
	uv2.resize(N)
	# organites de la cellule, tirés une fois
	var noyau := Vector3(-0.13, 0.05, 0.04)
	var mitos: Array = []
	while mitos.size() < 8:
		var c := _hasard_boule(rng) * 0.56
		if c.distance_to(noyau) > 0.4:
			mitos.append([c, _hasard_sphere(rng)])
	var vesicules: Array = []
	while vesicules.size() < 16:
		var c := _hasard_boule(rng) * 0.62
		if c.distance_to(noyau) > 0.33:
			vesicules.append([c, rng.randf_range(0.022, 0.042)])
	var chromatine: Array = []
	for k in 7:
		chromatine.append(noyau + _hasard_boule(rng) * 0.15)
	# noyau de l'atome : douze nucléons serrés (six protons, six neutrons : du carbone)
	var nucleons: Array = []
	while nucleons.size() < 12:
		var c := _hasard_boule(rng) * 0.075
		var libre := true
		for o: Vector3 in nucleons:
			if o.distance_to(c) < 0.045:
				libre = false
		if libre:
			nucleons.append(c)
	var axe := Vector3(0.35, 1.0, 0.25).normalized()
	for i in N:
		var o := i * 4
		# graine de départ : liée à la hauteur dans le corps, pour que la poussière le dessine des pieds vers la tête
		var g0 := clampf(0.7 * (fem[i].y + 0.98) / 1.94 + 0.3 * rng.randf(), 0.0, 1.0)
		c0[o] = hom[i].x
		c0[o + 1] = hom[i].y
		c0[o + 2] = hom[i].z
		c0[o + 3] = g0
		uv[i] = Vector2(rng.randf(), rng.randf())
		uv2[i] = Vector2(rng.randf(), rng.randf())
		# galaxie : un bulbe et deux bras en spirale logarithmique, dans le plan xz
		var p: Vector3
		var u := rng.randf()
		if u < 0.2:
			p = _hasard_boule(rng) * pow(rng.randf(), 1.5) * Vector3(0.2, 0.09, 0.2)
		else:
			var r := 0.07 + 0.88 * pow(rng.randf(), 0.8)
			var a := rng.randf() * TAU
			if u < 0.86:
				a = float(rng.randi() % 2) * PI + log(r / 0.07) * 2.3 + rng.randfn() * 0.22 / (0.35 + r)
			p = Vector3(r * cos(a), rng.randfn() * 0.022 * (1.2 - r), r * sin(a))
		c1[o] = p.x
		c1[o + 1] = p.y
		c1[o + 2] = p.z
		c1[o + 3] = rng.randf()
		# cellule
		var nature := 0
		u = rng.randf()
		if u < 0.3:
			p = _hasard_sphere(rng) * (0.72 + rng.randfn() * 0.008) * Vector3(1.0, 0.92, 0.95)
		elif u < 0.42:
			nature = 1
			p = _hasard_boule(rng) * 0.68
		elif u < 0.58:
			nature = 2
			p = noyau + _hasard_sphere(rng) * (0.24 + rng.randfn() * 0.004)
		elif u < 0.68:
			nature = 3
			p = (chromatine[rng.randi() % chromatine.size()] as Vector3) + _hasard_boule(rng) * 0.075
		elif u < 0.84:
			nature = 4
			var mt: Array = mitos[rng.randi() % mitos.size()]
			var s := _hasard_sphere(rng)
			var long: Vector3 = mt[1]
			# capsule allongée, avec quelques crêtes à l'intérieur
			p = mt[0] + (s - long * s.dot(long)) * 0.045 * (1.0 if rng.randf() < 0.7 else rng.randf()) + long * (s.dot(long) * 0.045 + rng.randf_range(-0.07, 0.07))
		elif u < 0.94:
			nature = 5
			var s := _hasard_sphere(rng)
			if s.x < 0.0:
				s.x = -s.x
			var rr := 0.29 + 0.035 * float(rng.randi() % 4)
			p = noyau + s * (rr + 0.012 * sin(s.y * 22.0 + rr * 60.0))
		else:
			nature = 6
			var ve: Array = vesicules[rng.randi() % vesicules.size()]
			p = ve[0] + _hasard_sphere(rng) * ve[1]
		c2[o] = p.x
		c2[o + 1] = p.y
		c2[o + 2] = p.z
		c2[o + 3] = float(nature)
		# atome : le nuage électronique est tiré selon des densités de probabilité (couches s diffuses, lobes p), jamais sur une orbite
		u = rng.randf()
		if u < 0.07:
			var k := rng.randi() % nucleons.size()
			nature = k % 2
			p = (nucleons[k] as Vector3) + _hasard_boule(rng) * 0.026
		else:
			nature = 2
			var dir := _hasard_sphere(rng)
			var r := 0.0
			if u < 0.22:
				r = -0.055 * log(maxf(1e-6, rng.randf() * rng.randf()))
			elif u < 0.68:
				# lobes : la direction est d'autant plus probable qu'elle est proche de l'axe (densité en cos²)
				while pow(dir.dot(axe), 2.0) < rng.randf():
					dir = _hasard_sphere(rng)
				r = -0.085 * log(maxf(1e-6, rng.randf() * rng.randf() * rng.randf()))
			else:
				r = -0.12 * log(maxf(1e-6, rng.randf() * rng.randf() * rng.randf()))
			p = dir * minf(r, 0.6 + 0.35 * rng.randf())
		c3[o] = p.x
		c3[o + 1] = p.y
		c3[o + 2] = p.z
		c3[o + 3] = float(nature)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = fem
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_CUSTOM0] = c0
	arr[Mesh.ARRAY_CUSTOM1] = c1
	arr[Mesh.ARRAY_CUSTOM2] = c2
	arr[Mesh.ARRAY_CUSTOM3] = c3
	var format := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
	var maillage := ArrayMesh.new()
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr, [], {}, format)
	maillage.custom_aabb = AABB(Vector3(-2, -1.5, -1.5), Vector3(4, 3, 3))
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://intro.gdshader")
	_mat.render_priority = -10      # le nuage se dessine avant les panneaux et les textes
	_mat.set_shader_parameter("cnt", float(N))
	maillage.surface_set_material(0, _mat)
	_nuage = MeshInstance3D.new()
	_nuage.mesh = maillage
	_nuage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nuage.position = CENTRE
	add_child(_nuage)
	_regler_materiau()


func _vers_la_tete(n: Node3D, c: Vector3, droit: bool) -> void:
	# la face avant (+z) regarde la tête (origine de ce repère) ; `droit` garde le panneau vertical
	var cible := Vector3(0, c.y if droit else 0.0, 0)
	n.transform = Transform3D(Basis.IDENTITY, c).looking_at(c + (c - cible), Vector3.UP)


func _construire_panneaux() -> void:
	# sous-titre : 1,6 m devant, à −19° sous l'horizon (plus bas, il fallait baisser la tête pour le lire)
	_plaque = MeshInstance3D.new()
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.02, 0.024, 0.04, 0.0)
	m.render_priority = 1
	q.material = m
	_plaque.mesh = q
	_plaque.position = Vector3(0, Y_SOUS_TITRE, -1.602)
	add_child(_plaque)
	_texte = Label3D.new()
	_texte.font = _police if _police != null else ThemeDB.fallback_font
	_texte.font_size = 64
	_texte.pixel_size = 0.05 / 64.0       # 50 mm à 1,6 m (le plancher de lisibilité y est de 43 mm)
	_texte.outline_size = 0
	_texte.shaded = false
	_texte.render_priority = 3
	_texte.modulate = Color(CLAIR, 0.0)
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.width = 1.1 / _texte.pixel_size
	_texte.position = Vector3(0, Y_SOUS_TITRE, -1.6)
	add_child(_texte)
	# « Passer l'introduction » : en bas, à portée de doigt
	_bouton_passer = PanneauScript.new(_police)
	add_child(_bouton_passer)
	_bouton_passer.bouton("passer", "Passer l'introduction", Vector2.ZERO, Vector2(0.3, 0.07))
	_bouton_passer.taille_texte("passer", 17.0)
	_vers_la_tete(_bouton_passer, Vector3(0, -0.43, -0.64), false)
	_bouton_passer.opacite = 0.0
	_bouton_passer.touche.connect(func(id: String) -> void: touche.emit(id))
	# menu de départ : à droite, à portée de regard (lu au rayon, à 1,3 m)
	_menu = Depart.new(_police, PRENOMS, _en_ligne)
	add_child(_menu)
	var a := deg_to_rad(23.0)
	_vers_la_tete(_menu, Vector3(sin(a) * 1.3, -0.12, -cos(a) * 1.3), true)
	_menu.opacite = 0.0
	_menu.visible = false
	_menu.touche.connect(func(id: String) -> void: touche.emit(id))
	_maj_choix()


func _maj_choix() -> void:
	_menu.etat(choix, _ecoute, _message)


# ───────── nom du guide ─────────

## Met en forme un nom dicté ou enregistré : un mot ou deux, capitale initiale, NOM_MAX caractères au plus.
## « elle s'appelle marie-christine de la tour. » → « Marie-Christine » ; rien d'utilisable → "".
static func former_nom(texte: String) -> String:
	var t := texte.strip_edges().to_lower().replace("’", "'")
	for debut: String in ["elle s'appellera ", "elle s'appelle ", "je l'appelle ", "appelle-la ", "appelle la ", "son nom est ", "ce sera ", "c'est "]:
		if t.begins_with(debut):
			t = t.substr(debut.length())
			break
	var net := ""
	for c in t:
		net += c if c == "-" or c == "'" or c.to_upper() != c.to_lower() else " "
	var mots: Array[String] = []
	for m in net.split(" ", false):
		var mot := m.lstrip("-'").rstrip("-'")
		if mot != "" and mots.size() < 2:
			var parties := mot.split("-")
			for i in parties.size():
				parties[i] = parties[i].substr(0, 1).to_upper() + parties[i].substr(1)
			mots.append("-".join(parties))
	if mots.is_empty():
		return ""
	var nom := mots[0]
	if mots.size() > 1 and nom.length() + 1 + mots[1].length() <= NOM_MAX:
		nom += " " + mots[1]
	if nom.length() > NOM_MAX:
		nom = nom.substr(0, NOM_MAX).rstrip("-' ")
	# un prénom de la liste est rendu avec son orthographe (« zelie » → « Zélie »)
	for p: String in PRENOMS:
		if _sans_accents(p) == _sans_accents(nom):
			return p
	return nom


static func _sans_accents(t: String) -> String:
	var r := t.to_lower()
	var paires := ["éèêë", "e", "àâä", "a", "îï", "i", "ôö", "o", "ùûü", "u", "ç", "c"]
	for i in range(0, paires.size(), 2):
		for c in paires[i]:
			r = r.replace(c, paires[i + 1])
	return r


## Réponse de main.gd à `demande_nom` : ce que le micro a entendu. Ignoré si le visiteur a choisi autre chose entre-temps.
func nom_entendu(texte: String) -> void:
	if not _ecoute:
		return
	_ecoute = false
	var nom := former_nom(texte)
	if nom == "":
		_dire_message("Je n'ai pas compris.\nRedis-le, ou choisis dessous." if choix.tutoiement else "Je n'ai pas compris.\nChoisissez ci-dessous.")
	else:
		choix.nom = nom
		_message = ""
	if _menu != null:
		_maj_choix()


## Réponse de main.gd à `demande_nom` : pas de micro. Un mot bref, puis on revient à la liste (le nom ne change pas).
func nom_refuse() -> void:
	_ecoute = false
	_dire_message("Le micro n'est pas disponible.\n" + ("Choisis un nom ci-dessous." if choix.tutoiement else "Choisissez un nom ci-dessous."))
	if _menu != null:
		_maj_choix()


func _dire_message(m: String) -> void:
	_message = m
	_t_message = T_MESSAGE


# ───────── déroulement ─────────

func _lancer_sequence(i: int) -> void:
	_i = i
	_t = 0.0
	_a_parle = false
	_t_silence = 0.0
	var s: Dictionary = _sequences[i]
	var texte := str(s.get("texte", ""))
	var scene := str(s.get("scene", "nuit"))
	_duree = 2.5 + 0.075 * texte.length()
	_texte_voulu = texte
	_vers_forme(int(FORMES.get(scene, 0)))
	if _voix != null:
		_voix.call("dire", ["intro_%d" % i])
	if scene == "menu":
		_ouvrir_menu()


func _vers_forme(f: int) -> void:
	if f == _forme:
		return
	# si un passage était encore en cours, on repart de sa forme d'arrivée
	_mat.set_shader_parameter("forme_a", _forme)
	_mat.set_shader_parameter("forme_b", f)
	# vers la cellule puis l'atome, on plonge ; en revenant au corps, on remonte (c'est le nuage qui grandit, pas le spectateur qui avance)
	var plongee := 1 if (f == 4 or f == 5) and (_forme == 3 or _forme == 4) else (-1 if f == 3 and (_forme == 4 or _forme == 5) else 0)
	_mat.set_shader_parameter("plongee", plongee)
	_forme = f
	_melange = 0.0


func _ouvrir_menu() -> void:
	if _phase == MENU or _phase == FIN or _phase == TERMINE:
		return
	_phase = MENU
	_t_menu = 0.0
	_vers_forme(3)
	_menu.visible = true
	_menu.ouvrir()


## Vrai tant que la phrase de la séquence n'est pas finie (voix, ou à défaut durée de lecture du sous-titre).
func _phrase_en_cours(dt: float) -> bool:
	var parle: bool = _voix != null and bool(_voix.get("a_des_clips")) and bool(_voix.call("parle"))
	if parle:
		_a_parle = true
		_t_silence = 0.0
		return true
	if _a_parle:
		_t_silence += dt
		return _t_silence < RESPIRATION or _t < T_PASSAGE
	# pas de clip pour cette phrase (ou aperçu sur ordinateur) : on laisse le temps de lire
	return _t < _duree


## À appeler à chaque image, avec les pointeurs de main.gd (voir panneau.gd).
func maj(dt: float, pointeurs: Array) -> void:
	impacts.clear()
	if _phase == TERMINE or _mat == null:
		return
	_temps += dt
	if _phase == ATTENTE:
		_phase = ANIMATION
		_lancer_sequence(0)
	_t += dt
	if (_phase == ANIMATION or _phase == MENU) and _i < _sequences.size() and not _phrase_en_cours(dt):
		if _i + 1 < _sequences.size():
			_lancer_sequence(_i + 1)
		else:
			_i = _sequences.size()
			_texte_voulu = ""
			_ouvrir_menu()      # sans scène « menu » dans la liste, le menu s'ouvre après la dernière phrase
	# le nuage
	_melange = minf(1.0, _melange + dt / T_PASSAGE)
	_fondu = clampf(_fondu + (-dt / 0.6 if _phase == FIN else dt / 2.5), 0.0, 1.0)
	_genre = lerpf(_genre, 1.0 if choix.corps == "homme" else 0.0, 1.0 - exp(-dt * 5.0))
	var cible := A_GAUCHE if _phase == MENU or _phase == FIN else Vector3.ZERO
	_decal = _decal.lerp(cible, 1.0 - exp(-dt * 1.6))
	_nuage.position = CENTRE + _decal
	# le sous-titre suit le corps quand le menu s'ouvre : il ne passe jamais devant le panneau
	_texte.position.x = _decal.x * 1.05
	_plaque.position.x = _texte.position.x
	_regler_materiau()
	# le sous-titre : l'ancien s'efface, le nouveau apparaît
	var meme := _texte.text == _texte_voulu
	_alpha_texte = clampf(_alpha_texte + (dt / 0.5 if meme and _texte_voulu != "" and _phase != FIN else -dt / 0.35), 0.0, 1.0)
	if not meme and _alpha_texte <= 0.0:
		_poser_texte(_texte_voulu)
	_texte.modulate = Color(CLAIR, _alpha_texte)
	((_plaque.mesh as QuadMesh).material as StandardMaterial3D).albedo_color.a = 0.85 * _alpha_texte     # assez dense pour rester lisible devant le nuage
	_plaque.visible = _alpha_texte > 0.0
	# les panneaux
	_bouton_passer.opacite = clampf(_bouton_passer.opacite + (dt / 0.8 if _phase == ANIMATION and _temps > 1.5 else -dt / 0.3), 0.0, 1.0)
	_bouton_passer.visible = _bouton_passer.opacite > 0.0
	if _phase == ANIMATION:
		if _bouton_passer.maj(pointeurs, dt) == "passer":
			passer()
		impacts.append_array(_bouton_passer.impacts)
	elif _phase == MENU:
		_t_menu += dt
		_menu.opacite = clampf((_t_menu - 0.9) / 0.7, 0.0, 1.0)
		var id := _menu.maj(pointeurs, dt)
		impacts.append_array(_menu.impacts)
		match id:
			"femme", "homme":
				choix.corps = id
			"enfant", "curieux", "scientifique":
				choix.niveau = NIVEAUX.find(id)
			"descriptif", "incarne":
				choix.mode = id
			"tu", "vous":
				choix.tutoiement = id == "tu"
			"sans":
				choix.nom = ""
				_ecoute = false
				_message = ""
			"dis":
				_ecoute = true
				_message = ""
				demande_nom.emit()
			"demarrer":
				_phase = FIN
				_t_fin = 0.0
				_ecoute = false
				if _voix != null:
					_voix.call("taire")
		if id.begins_with("nom:"):
			choix.nom = PRENOMS[int(id.substr(4))]
			_ecoute = false
			_message = ""
		if _message != "":
			_t_message -= dt
			if _t_message <= 0.0:
				_message = ""
		_maj_choix()        # sans effet si rien n'a changé (et suit `choix` s'il est modifié de l'extérieur)
	elif _phase == FIN:
		_t_fin += dt
		_menu.opacite = clampf(1.0 - _t_fin / 0.45, 0.0, 1.0)
		_menu.maj([], dt)
		if _t_fin >= 0.6:
			_phase = TERMINE
			visible = false
			termine.emit(choix.duplicate())


func _poser_texte(t: String) -> void:
	_texte.text = t
	if t == "":
		return
	var taille := _texte.font.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, _texte.width, _texte.font_size) * _texte.pixel_size
	(_plaque.mesh as QuadMesh).size = Vector2(minf(taille.x, 1.12) + 0.09, taille.y + 0.05)


func _regler_materiau() -> void:
	_mat.set_shader_parameter("melange", _melange)
	_mat.set_shader_parameter("temps", _temps)
	_mat.set_shader_parameter("genre", _genre)
	_mat.set_shader_parameter("fondu", _fondu)


# ───────── le menu de départ ─────────

class CarteTexte:
	var l: Label3D
	var pos := Vector2.ZERO     # par rapport au centre de l'élément
	var coul := Color.WHITE
	var actif := Color.WHITE    # couleur quand l'élément est choisi
	var mm := 35.0              # taille voulue
	var largeur := 0.0          # largeur disponible (0 : libre)
	var voulu := ""
	var cle := -1


class CarteElem:
	var id := ""
	var ecran := -1             # −1 : sur les deux écrans
	var c := Vector2.ZERO
	var t := Vector2.ZERO
	var style := 0
	var plaque := true
	var sensible := true
	var fond := false           # décor posé sous les autres (plateau)
	var remplit := true         # choisi = plaque d'or pleine
	var icone := -1
	var ic_pos := Vector2.ZERO
	var ic_t := 0.04
	var ic_coul := Color.WHITE
	var textes: Array[CarteTexte] = []
	var actif := false
	var i0 := 0
	var s := 0.0
	var e := 0.0
	var al := 0.0
	var av := 0.0
	var ap := 1.0
	var eclat := 0.0
	var dessine := false


## Le menu de départ, dans le langage du menu en jeu (menu.gd) : une carte nuit aux coins généreux, des aplats, un
## seul code d'état (or plein = choisi ; anneau blanc = visé), deux niveaux de texte (40 mm blanc pour ce qu'on choisit,
## 35 mm gris pour ce qui l'explique). Il est lu au rayon à 1,3 m : rien sous 35 mm (16 mm à 60 cm), cibles ≥ 7 cm.
##
## Deux écrans plutôt qu'un formulaire : « Toi » (corps, public) puis « Ton guide » (façon de parler, nom). Les deux
## onglets du haut disent où l'on est et permettent de revenir ; en bas, une seule action évidente (« Suivant », puis
## « Démarrer »).
##
## Plan local XY, face avant vers +Z, dimensions en mètres (0,95 × 0,62). Pointeurs : ceux de panneau.gd.
class Depart extends Node3D:
	signal touche(id: String)

	const CLAIR := Color(0.925, 0.91, 0.875)
	const BLANC := Color(1.0, 0.99, 0.97)
	const GRIS := Color(0.66, 0.7, 0.78)
	const OR := Color(1, 0.85, 0.3)
	const ENCRE := Color(0.05, 0.05, 0.07)
	const ALERTE := Color(1.0, 0.72, 0.56)
	const NIVEAUX := ["enfant", "curieux", "scientifique"]
	const L := 0.95
	const H := 0.62
	const LC := 0.89                    # largeur du contenu
	const X0 := -0.445                  # bord gauche du contenu
	const Y_ONGLETS := 0.252
	const L_ONGLETS := 0.64             # les deux onglets ; à leur droite, le réglage « Tu / Vous »
	const Y_ACTION := -0.2325           # le bouton du bas (8,5 cm de haut)
	const H_ACTION := 0.085
	const MM_MIN := 35.0                # plancher de lisibilité à 1,3 m (16 mm à 60 cm)
	const MM_CHOIX := 40.0
	const ENFONCE := 0.004
	const DEGAGE := 0.018
	const PORTEE := 6.0
	const AVANCE := 0.01
	const ANNEAU := 0.008
	const AIMANT := 0.02                # au rayon, on ne quitte la cible visée qu'en en sortant de 2 cm
	const STABLE := 0.15
	const MEMOIRE := 0.4
	const GEL_PINCE := 0.8
	const SOURD := 0.45                 # après un changement d'écran, les clics sont ignorés un instant

	## CUSTOM = (largeur, hauteur, paramètre, genre + 8 × style), COLOR = états ou couleur.
	##   genre 0 carte · 1 tuile · 2 pictogramme · 3 curseur
	##   style 0 carte de choix · 1 action principale · 2 discrète (contour) · 3 onglet · 4 pastille de l'onglet actif
	##         5 plateau des onglets · 6 pastille de choix
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
uniform vec3 plateau : source_color = vec3(0.02, 0.026, 0.05);
uniform vec3 pastille : source_color = vec3(0.27, 0.32, 0.46);
uniform vec3 lisere : source_color = vec3(0.62, 0.72, 0.95);
const float MARGE = 0.02;
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

// pictogrammes : q dans [-1, 1]², distance signée
float icone(vec2 q, int k, float temps) {
	float d = 1.0;
	if (k == 0) {                   // micro
		d = seg(q, vec2(0.0, 0.12), vec2(0.0, 0.52)) - 0.25;
		d = min(d, arc(vec2(q.x, 0.12 - q.y), 0.47, 0.0, 1.5708) - 0.07);
		d = min(d, seg(q, vec2(0.0, -0.36), vec2(0.0, -0.72)) - 0.07);
		d = min(d, seg(q, vec2(-0.27, -0.76), vec2(0.27, -0.76)) - 0.07);
	} else if (k == 1) {            // chevron droit
		d = seg(vec2(q.x, abs(q.y)), vec2(0.28, 0.0), vec2(-0.22, 0.5)) - 0.1;
	} else if (k == 2) {            // chevron gauche
		d = seg(vec2(-q.x, abs(q.y)), vec2(0.28, 0.0), vec2(-0.22, 0.5)) - 0.1;
	} else {                        // écoute : ondes de la voix (elles ondulent doucement, sans clignoter)
		for (int i = 0; i < 5; i++) {
			float x = -0.72 + 0.36 * float(i);
			float h = 0.2 + 0.5 * (0.5 + 0.5 * sin(temps * 2.6 + float(i) * 1.7));
			d = min(d, seg(q, vec2(x, -h), vec2(x, h)) - 0.1);
		}
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
		// la carte : aplat nuit, coins généreux, ombre portée
		float d = boite(p, demi, 0.06);
		float l = max(fwidth(d), 0.00002);
		float dedans = 1.0 - smoothstep(-l, l, d);
		c = vec3(0.0, 0.002, 0.008);
		a = 0.45 * exp(-max(d, 0.0) / 0.008) * (1.0 - dedans);
		vec3 f = mix(nuit_bas, nuit_haut, smoothstep(-demi.y, demi.y, p.y + p.x * 0.3));
		if (donnees.z > 0.001 && donnees.z < 0.999) {
			// à l'ouverture, une seule vague de lumière descend sur la carte
			float y = mix(demi.y + 0.06, -demi.y - 0.06, donnees.z);
			f += lisere * 0.3 * exp(-abs(p.y - y) / 0.03) * sin(donnees.z * 3.14159);
		}
		sur(c, a, f, 0.955 * dedans);
		float ep = max(0.0018, 1.2 * l);
		float trait = smoothstep(-ep - l, -ep + l, d) * dedans;
		sur(c, a, lisere, 0.3 * trait);
		a *= etat.a;
	} else if (genre < 1.5) {
		// tuile : aplat, sans contour au repos ; visée = plus claire + anneau blanc ; pressée = blanc chaud ; choisie = or plein
		float s = etat.r;
		float e = etat.g;
		float al = etat.b;
		float r = 0.03;
		vec3 f = tuile;
		float fa = 0.97;
		float bord = 0.0;
		if (style > 0.5 && style < 1.5) {
			r = demi.y;
			f = mix(indigo_a, indigo_b, smoothstep(-demi.x, demi.x, p.x + p.y));
			fa = 1.0;
		} else if (style > 1.5 && style < 2.5) {
			r = demi.y;
			fa = 0.22;
			bord = 0.34;
		} else if (style > 2.5 && style < 3.5) {
			r = demi.y;
			fa = 0.0;
		} else if (style > 3.5 && style < 4.5) {
			r = demi.y;
			f = pastille;
			fa = 1.0;
		} else if (style > 4.5 && style < 5.5) {
			r = demi.y;
			f = plateau;
			fa = 0.8;
		} else if (style > 5.5) {
			r = demi.y;
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
		f = mix(f, clair, e);
		fa = mix(fa, 1.0, e);
		c = f;
		a = fa * dedans;
		float ep = max(0.0028, 1.2 * l);
		float trait = smoothstep(-ep - l, -ep + l, d) * dedans;
		sur(c, a, vec3(1.0), trait * max(bord * (1.0 - e), 0.95 * s * (1.0 - e)));
		a *= etat.a;
	} else if (genre < 2.5) {
		vec2 q = p / (donnees.x * 0.5);
		float d = icone(q, int(donnees.y + 0.5), TIME);
		float l = max(fwidth(d), 0.0005);
		c = etat.rgb;
		a = (1.0 - smoothstep(-l, l, d)) * etat.a;
	} else {
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
	}
	ALBEDO = c;
	ALPHA = a * opacite;
}
"

	var impacts: Array[Vector3] = []        # points (repère monde) où les rayons touchent le menu
	var opacite := 1.0: set = _regler_opacite
	var ecran := 0                          # 0 « Toi », 1 « Ton guide »

	var _police: Font
	var _serrees := {}
	var _prenoms: Array = []
	var _elems: Array[CarteElem] = []
	var _par_id := {}
	var _onglets: Array[CarteElem] = []
	var _el_phrase: CarteElem
	var _el_dis: CarteElem
	var _l_phrase := 0.5
	var _tu_vous: Array = []                # [texte, version « tu », version « vous »]
	var _tutoie := true
	var _el_suivant: CarteElem
	var _cle_etat := ""
	var _survol_el: CarteElem
	var _doigts := {}
	var _rayons := {}
	var _horloge := 0.0
	var _sourd := -1.0
	var _balai := 1.0
	var _ind_x := 0.0
	var _mm: MultiMesh
	var _mat: ShaderMaterial
	var _curseurs: MultiMeshInstance3D
	var _mm_c: MultiMesh
	var _cibles: Array = []
	var _nc_ecrit := 0
	var _c_pos := PackedVector3Array()
	var _c_cu := PackedColorArray()
	var _c_co := PackedColorArray()


	func _init(police: Font, prenoms: Array, en_ligne: bool) -> void:
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
		_prenoms = prenoms
		var shader := Shader.new()
		shader.code = CODE
		var t := []
		t.resize(Mesh.ARRAY_MAX)
		t[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)])
		t[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		t[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
		var maille := ArrayMesh.new()
		maille.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, t)
		_mat = ShaderMaterial.new()
		_mat.shader = shader
		_mm = _multi(maille, 0)
		add_child(_instance(_mm, _mat))
		var mc := ShaderMaterial.new()
		mc.shader = shader
		mc.render_priority = 4
		_mm_c = _multi(maille, 2)
		for i in 2:
			_mm_c.set_instance_custom_data(i, Color(0, 0, 0, 3))
		_curseurs = _instance(_mm_c, mc)
		_curseurs.visible = false
		add_child(_curseurs)
		var boite := AABB(Vector3(-L * 0.5 - 0.04, -H * 0.5 - 0.04, -0.02), Vector3(L + 0.08, H + 0.08, 0.06))
		_mm.custom_aabb = boite
		_mm_c.custom_aabb = boite
		_construire(en_ligne)
		var n := 3
		for e in _elems:
			e.i0 = n
			n += (1 if e.plaque else 0) + (1 if e.icone >= 0 else 0)
		_mm.instance_count = n
		_c_pos.resize(n)
		_c_cu.resize(n)
		_c_co.resize(n)
		for i in n:
			_c_pos[i] = Vector3(1e9, 0, 0)
			_c_cu[i] = Color(0, 0, 0, 0)
			_c_co[i] = Color(0, 0, 0, 0)
			_mm.set_instance_transform(i, Transform3D.IDENTITY)
			_mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
			_mm.set_instance_color(i, Color(0, 0, 0, 0))
		_ind_x = _onglets[0].c.x


	func _multi(maille: Mesh, n: int) -> MultiMesh:
		var m := MultiMesh.new()
		m.transform_format = MultiMesh.TRANSFORM_3D
		m.use_colors = true
		m.use_custom_data = true
		m.mesh = maille
		m.instance_count = n
		return m


	func _instance(m: MultiMesh, mat: ShaderMaterial) -> MultiMeshInstance3D:
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = m
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi


	# ── construction ──

	func _largeur(t: String, mm: float, police: Font = null) -> float:
		return (_police if police == null else police).get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x / 64.0 * mm * 0.001


	func _serree(n: int) -> Font:
		if not _serrees.has(n):
			var fv := FontVariation.new()
			fv.base_font = _police
			fv.spacing_glyph = -n
			_serrees[n] = fv
		return _serrees[n]


	## Écrit un texte à la taille voulue ; s'il déborde : réduit jusqu'au plancher, puis lettres resserrées, puis coupé.
	func _dire(tx: CarteTexte, t: String) -> void:
		if tx.voulu == t and tx.l.text != "":
			return
		tx.voulu = t
		var mm := tx.mm
		var s := t
		var police := _police
		if tx.largeur > 0.0 and t != "":
			var w := _largeur(t, mm)
			if w > tx.largeur:
				mm = maxf(MM_MIN, mm * tx.largeur / w)
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


	func _tx(e: CarteElem, t: String, mm: float, pos: Vector2, coul: Color, actif: Color, gauche := false, largeur := 0.0) -> CarteTexte:
		var tx := CarteTexte.new()
		var l := Label3D.new()
		l.font = _police
		l.font_size = 64
		l.pixel_size = mm * 0.001 / 64.0
		l.line_spacing = -9.0           # interligne de 1,2 : les sous-titres sur deux lignes restent groupés
		l.outline_size = 0
		l.shaded = false
		l.render_priority = 2
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if gauche else HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.visible = false
		add_child(l)
		tx.l = l
		tx.pos = pos
		tx.coul = coul
		tx.actif = actif
		tx.mm = maxf(mm, MM_MIN)
		tx.largeur = largeur
		_dire(tx, t)
		e.textes.append(tx)
		return tx


	func _elem(id: String, ec: int, c: Vector2, t: Vector2, style := 0) -> CarteElem:
		var e := CarteElem.new()
		e.id = id
		e.ecran = ec
		e.c = c
		e.t = t
		e.style = style
		_elems.append(e)
		if id != "":
			_par_id[id] = e
		return e


	## Intitulé de groupe : second niveau de texte, aligné à gauche.
	func _tv(tx: CarteTexte, tu: String, vous: String) -> CarteTexte:
		_tu_vous.append([tx, tu, vous])
		_dire(tx, tu)
		return tx


	func _intitule(ec: int, t: String, y: float) -> CarteTexte:
		var e := _elem("", ec, Vector2(X0 + 0.008, y), Vector2.ZERO)
		e.plaque = false
		e.sensible = false
		return _tx(e, t, MM_MIN, Vector2.ZERO, GRIS, GRIS, true)


	## Carte de choix : un mot (premier niveau) et son explication sur deux lignes (second niveau).
	func _carte(id: String, ec: int, c: Vector2, t: Vector2, mot: String, explication: String) -> CarteElem:
		var e := _elem(id, ec, c, t)
		_tx(e, mot, MM_CHOIX, Vector2(0, t.y * 0.5 - 0.038), BLANC, ENCRE, false, t.x - 0.02)
		_tx(e, explication, MM_MIN, Vector2(0, t.y * 0.5 - 0.109), GRIS, ENCRE, false, t.x - 0.016)
		return e


	func _construire(en_ligne: bool) -> void:
		# les deux onglets : où l'on est, et le moyen de revenir
		var lo := L_ONGLETS * 0.5
		for i in 2:
			var o := _elem("nav:%d" % i, -1, Vector2(X0 + (i + 0.5) * lo, Y_ONGLETS), Vector2(lo - 0.01, 0.06), 3)
			o.remplit = false
			_tv(_tx(o, "", MM_CHOIX, Vector2.ZERO, GRIS, BLANC, false, lo - 0.03), ["1 · Toi", "2 · Ton guide"][i], ["1 · Vous", "2 · Votre guide"][i])
			_onglets.append(o)
		# réglage discret, en haut à droite : être tutoyé ou vouvoyé (le menu lui-même change de ton)
		var lt := 0.235
		var pl := _elem("", -1, Vector2(X0 + LC - lt * 0.5, Y_ONGLETS), Vector2(lt, 0.07), 5)
		pl.sensible = false
		pl.fond = true
		for i in 2:
			var e := _elem(["tu", "vous"][i], -1, Vector2(X0 + LC - lt + 0.0625 + 0.11 * i, Y_ONGLETS), Vector2(0.11, 0.06), 3)
			_tx(e, ["Tu", "Vous"][i], MM_MIN + 1.0, Vector2.ZERO, GRIS, ENCRE)
		# ── écran « Toi » ──
		_tv(_intitule(0, "", 0.186), "Ton corps", "Votre corps")
		var l2 := (LC - 0.012) * 0.5
		for i in 2:
			var e := _elem(["femme", "homme"][i], 0, Vector2((i - 0.5) * (l2 + 0.012), 0.118), Vector2(l2, 0.08))
			_tx(e, ["Femme", "Homme"][i], MM_CHOIX, Vector2.ZERO, BLANC, ENCRE)
		_tv(_intitule(0, "", 0.047), "Je suis…", "Je suis…")
		var l3 := (LC - 0.024) / 3.0
		var mots := ["Enfant", "Curieux", "Scientifique"]
		var sous := ["un conte\ndans le corps", "entre art\net sciences", "le détail\ndes mécanismes"]
		for k in 3:
			_carte(NIVEAUX[k], 0, Vector2((k - 1) * (l3 + 0.012), -0.06), Vector2(l3, 0.17), mots[k], sous[k])
		var su := _elem("suivant", 0, Vector2(0, Y_ACTION), Vector2(LC, H_ACTION), 1)
		_tv(_tx(su, "", 44.0, Vector2(-0.02, 0), BLANC, BLANC), "Suivant : ton guide", "Suivant : votre guide")
		su.icone = 1
		su.ic_t = 0.036
		su.ic_coul = BLANC
		_el_suivant = su
		# ── écran « Ton guide » ──
		# sa façon de parler : deux cartes. Hors ligne, « Incarné » porte une troisième ligne, discrète.
		var hm := 0.168 if en_ligne else 0.208
		var haut := 0.205
		var ids := ["descriptif", "incarne"]
		var noms := ["Descriptif", "Incarné"]
		var expl := ["Elle décrit\nce que tu vois.", "Elle raconte, s'étonne,\nconverse avec toi."]
		var expl_v := ["Elle décrit\nce que vous voyez.", "Elle raconte, s'étonne,\nconverse avec vous."]
		for i in 2:
			var e := _carte(ids[i], 1, Vector2((i - 0.5) * (l2 + 0.012), haut - hm * 0.5), Vector2(l2, hm), noms[i], "")
			_tv(e.textes[1], expl[i], expl_v[i])
			if i == 1 and not en_ligne:
				_tx(e, "demande une connexion", MM_MIN, Vector2(0, -hm * 0.5 + 0.032), ALERTE, ENCRE, false, l2 - 0.016)
		# son nom : une phrase vivante, « Dis-le-moi » à sa droite, les prénoms dessous
		var bas := haut - hm
		var jeu := (bas - (Y_ACTION + H_ACTION * 0.5) - 0.14) / 3.0
		var yp := bas - jeu - 0.035
		var yc := yp - 0.07 - jeu
		var ld := 0.3
		_l_phrase = LC - ld - 0.03
		_el_phrase = _elem("", 1, Vector2(X0 + 0.008, yp), Vector2.ZERO)
		_el_phrase.plaque = false
		_el_phrase.sensible = false
		_tx(_el_phrase, " ", MM_CHOIX, Vector2.ZERO, BLANC, BLANC, true)
		_tx(_el_phrase, " ", MM_CHOIX, Vector2.ZERO, OR, OR, true)
		_el_dis = _elem("dis", 1, Vector2(X0 + LC - ld * 0.5, yp), Vector2(ld, 0.07), 6)
		_el_dis.icone = 0
		_el_dis.ic_t = 0.04
		_el_dis.ic_pos = Vector2(-ld * 0.5 + 0.042, 0)
		_el_dis.ic_coul = CLAIR
		_tx(_el_dis, "Dis-le-moi", MM_MIN + 1.0, Vector2(0.022, 0), BLANC, ENCRE, false, ld - 0.085)
		var esp := 0.009
		var ls := _largeur("Sans nom", MM_MIN + 1.0) + 0.04
		var lp := (LC - ls - esp * _prenoms.size()) / _prenoms.size()
		var x := X0
		for i in _prenoms.size():
			var e := _elem("nom:%d" % i, 1, Vector2(x + lp * 0.5, yc), Vector2(lp, 0.07), 6)
			_tx(e, str(_prenoms[i]), MM_MIN + 1.0, Vector2.ZERO, BLANC, ENCRE, false, lp - 0.012)
			x += lp + esp
		var sn := _elem("sans", 1, Vector2(x + ls * 0.5, yc), Vector2(ls, 0.07), 6)
		_tx(sn, "Sans nom", MM_MIN + 1.0, Vector2.ZERO, BLANC, ENCRE, false, ls - 0.012)
		# en bas : revenir (discret), démarrer (évident)
		var lr := 0.25
		var re := _elem("retour", 1, Vector2(X0 + lr * 0.5, Y_ACTION), Vector2(lr, H_ACTION), 2)
		_tx(re, "Retour", MM_MIN + 1.0, Vector2(0.02, 0), CLAIR, CLAIR)
		re.icone = 2
		re.ic_t = 0.03
		re.ic_pos = Vector2(-_largeur("Retour", MM_MIN + 1.0) * 0.5 - 0.004, -0.001)
		re.ic_coul = CLAIR
		var ldm := LC - lr - 0.012
		var de := _elem("demarrer", 1, Vector2(X0 + LC - ldm * 0.5, Y_ACTION), Vector2(ldm, H_ACTION), 1)
		_tx(de, "Démarrer", 48.0, Vector2.ZERO, BLANC, BLANC)


	# ── état ──

	## Reflète les choix (sans effet si rien n'a changé). `ecoute` : on attend le nom dicté ; `message` : un mot bref
	## à la place de la phrase du nom.
	func etat(choix: Dictionary, ecoute: bool, message: String) -> void:
		var tu := bool(choix.get("tutoiement", true))
		var cle := "%s|%s|%s|%s|%s|%s|%s" % [choix.corps, choix.niveau, choix.mode, choix.nom, ecoute, message, tu]
		if cle == _cle_etat:
			return
		if tu != _tutoie or _cle_etat == "":
			_tutoie = tu
			for tv: Array in _tu_vous:
				_dire(tv[0], tv[1] if tu else tv[2])
			_el_suivant.ic_pos = Vector2(_largeur(_el_suivant.textes[0].voulu, 44.0) * 0.5 + 0.012, -0.001)
		_cle_etat = cle
		_par_id["tu"].actif = tu
		_par_id["vous"].actif = not tu
		_par_id["femme"].actif = choix.corps == "femme"
		_par_id["homme"].actif = choix.corps == "homme"
		for k in 3:
			_par_id[NIVEAUX[k]].actif = int(choix.niveau) == k
		_par_id["descriptif"].actif = choix.mode == "descriptif"
		_par_id["incarne"].actif = choix.mode == "incarne"
		var nom := str(choix.nom)
		var liste := false
		for i in _prenoms.size():
			var choisi: bool = nom == str(_prenoms[i]) and not ecoute
			_par_id["nom:%d" % i].actif = choisi
			liste = liste or choisi
		_par_id["sans"].actif = nom == "" and not ecoute
		# « Dis-le-moi » est doré pendant l'écoute, et tant que le nom vient de la voix
		_el_dis.actif = ecoute or (nom != "" and not liste)
		_el_dis.icone = 3 if ecoute else 0
		_dire(_el_dis.textes[0], "J'écoute…" if ecoute else ("Dis-le-moi" if tu else "Dites-le-moi"))
		# la phrase : « Elle s'appellera » en blanc, le nom en or
		var a := _el_phrase.textes[0]
		var b := _el_phrase.textes[1]
		var debut := ""
		var fin := ""
		a.coul = BLANC
		if message != "":
			debut = message
			a.coul = ALERTE
		elif ecoute:
			debut = "Je t'écoute : dis son nom…" if tu else "Je vous écoute : dites son nom…"
		elif nom == "":
			debut = "Donne-lui un nom, si tu veux." if tu else "Vous pouvez lui donner un nom."
		else:
			debut = "Elle s'appellera "
			fin = nom + "."
			if _largeur(debut + fin, MM_MIN) > _l_phrase:
				debut = "Ce sera "
		a.actif = a.coul
		var mm := MM_MIN if message != "" else MM_CHOIX
		var w := _largeur(debut + fin, mm)
		if w > _l_phrase:
			mm = maxf(MM_MIN, mm * _l_phrase / w)
		for tx: CarteTexte in [a, b]:
			tx.mm = mm
			tx.voulu = ""
			tx.cle = -1
		_dire(a, debut.strip_edges(false, true))
		_dire(b, fin if fin != "" else " ")
		b.pos.x = _largeur(debut + "|", mm) - _largeur("|", mm)


	## À l'ouverture : premier écran, vague de lumière.
	func ouvrir() -> void:
		ecran = 0
		_ind_x = _onglets[0].c.x
		_balai = 0.0
		_survol_el = null
		_doigts.clear()
		_rayons.clear()
		for e in _elems:
			e.ap = 1.0


	func aller(ec: int) -> void:
		if ec == ecran:
			return
		ecran = ec
		_sourd = _horloge + SOURD
		for e in _elems:
			if e.ecran == ec:
				e.ap = 0.0


	## Centre d'un élément dans le repère monde (pour les essais).
	func centre_de(id: String) -> Vector3:
		var e: CarteElem = _par_id[id]
		return global_transform * Vector3(e.c.x, e.c.y, 0)


	func _regler_opacite(v: float) -> void:
		opacite = clampf(v, 0.0, 1.0)
		if _mat != null:
			_mat.set_shader_parameter("opacite", opacite)


	# ── à chaque image ──

	func _present(e: CarteElem) -> bool:
		return e.sensible and (e.ecran < 0 or e.ecran == ecran)


	func _dans(e: CarteElem, p: Vector2, marge := 0.0) -> bool:
		return absf(p.x - e.c.x) <= e.t.x * 0.5 + marge and absf(p.y - e.c.y) <= e.t.y * 0.5 + marge


	func _sous(p: Vector2) -> CarteElem:
		for e in _elems:
			if _present(e) and _dans(e, p):
				return e
		return null


	## La cible d'un clic au rayon : celle visée sans interruption depuis STABLE ; sinon (la main vient de trembler en
	## pinçant) la précédente, si elle l'a été assez longtemps et vient d'être quittée ; sinon celle sous le rayon.
	func _stable(r: Dictionary) -> CarteElem:
		var cur: CarteElem = r.el
		if cur != null and _horloge - float(r.depuis) >= STABLE - 0.0005:
			return cur
		var prec: CarteElem = r.prec
		if prec != null and _present(prec) and float(r.prec_duree) >= STABLE and _horloge - float(r.prec_fin) <= MEMOIRE:
			return prec
		return cur


	## Lit les pointeurs, anime, et renvoie l'identifiant de l'élément activé à cette image (sinon "").
	func maj(pointeurs: Array, dt: float) -> String:
		dt = minf(dt, 0.05)
		_horloge += dt
		impacts.clear()
		_cibles.clear()
		var image := Engine.get_process_frames()
		var vise: CarteElem = null
		var declenche: CarteElem = null
		if opacite <= 0.5 or not is_visible_in_tree():
			_doigts.clear()
			_rayons.clear()
		else:
			var inv := global_transform.affine_inverse()
			for i in pointeurs.size():
				var p: Dictionary = pointeurs[i]
				if p.get("doigt", false):
					# au doigt (si le visiteur s'est approché) : on traverse le plan par l'avant, une fois
					var l: Vector3 = inv * (p.bout as Vector3)
					var d: Dictionary = _doigts.get(i, {"devant": false})
					var pres := absf(l.x) <= L * 0.5 and absf(l.y) <= H * 0.5 and l.z < 0.09 and l.z > -0.05
					if l.z > DEGAGE:
						d.devant = true
					elif l.z < -0.05:
						d.devant = false
					elif l.z <= ENFONCE and d.devant:
						d.devant = false
						var b := _sous(Vector2(l.x, l.y))
						if b != null:
							declenche = b
							vise = b
					_doigts[i] = d
					if pres:
						var b := _sous(Vector2(l.x, l.y))
						if b != null and vise == null:
							vise = b
						var k := clampf(1.0 - l.z / 0.09, 0.0, 1.0)
						_cibles.append([l.x, l.y, ANNEAU * (2.0 - k), k, 0.0])
						continue
				var o: Vector3 = inv * (p.o as Vector3)
				var dir: Vector3 = inv.basis * (p.d as Vector3)
				if o.z <= 0.0 or dir.z >= -1e-4:
					continue
				var t := -o.z / dir.z
				if t > PORTEE:
					continue
				var h := o + dir * t
				if absf(h.x) > L * 0.5 or absf(h.y) > H * 0.5:
					continue
				impacts.append(global_transform * h)
				var en_appui: bool = p.get("appui", false)
				var clic: bool = p.get("clic", false)
				_cibles.append([h.x, h.y, ANNEAU * clampf(t / 0.7, 1.0, 3.0), 1.0, 1.0 if en_appui else 0.0])
				var hp := Vector2(h.x, h.y)
				var cle := str(p.get("id", i))
				var r: Dictionary = _rayons.get(cle, {"el": null, "depuis": 0.0, "prec": null, "prec_duree": 0.0, "prec_fin": -9.0,
					"appui": false, "gele": null, "t_gele": -9.0, "vu": 0})
				r.vu = image
				var b: CarteElem = r.el
				if b == null or not _present(b) or not _dans(b, hp, AIMANT):
					b = _sous(hp)
				if b != r.el:
					if r.el != null:
						r.prec = r.el
						r.prec_duree = _horloge - float(r.depuis)
						r.prec_fin = _horloge
					r.el = b
					r.depuis = _horloge
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
					var g: CarteElem = r.gele
					if g != null and _horloge - float(r.t_gele) <= GEL_PINCE and _present(g):
						c = g
					r.gele = null
					if c != null:
						declenche = c
						vise = c
			for cle: String in _rayons:
				var r: Dictionary = _rayons[cle]
				if r.vu != image and r.el != null:
					r.prec = r.el
					r.prec_duree = _horloge - float(r.depuis)
					r.prec_fin = _horloge
					r.el = null
					r.appui = false
		if declenche != null and _horloge < _sourd:
			declenche = null
		if vise != _survol_el and vise != null:
			touche.emit(vise.id)
		_survol_el = vise
		var resultat := ""
		if declenche != null:
			declenche.eclat = 1.0
			resultat = declenche.id
			match resultat:
				"nav:0", "retour":
					aller(0)
				"nav:1", "suivant":
					aller(1)
		_rafraichir(dt)
		return resultat


	func _ecrire(i: int, pos: Vector3, custom: Color, coul: Color) -> void:
		if _c_pos[i] != pos:
			_c_pos[i] = pos
			_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
		if _c_cu[i] != custom:
			_c_cu[i] = custom
			_mm.set_instance_custom_data(i, custom)
		if _c_co[i] != coul:
			_c_co[i] = coul
			_mm.set_instance_color(i, coul)


	static func _vers(x: float, cible: float, k: float) -> float:
		var y := lerpf(x, cible, k)
		return cible if absf(y - cible) < 0.004 else y


	## Les Label3D reconstruisent leur maillage quand leur couleur change : on quantifie, et on ne repeint que si ça change.
	func _peindre(tx: CarteTexte, coul: Color, alpha: float) -> void:
		var qa := roundi(clampf(alpha, 0.0, 1.0) * 5.0)
		var cle := coul.to_rgba32() * 8 + qa
		if cle == tx.cle:
			return
		tx.cle = cle
		tx.l.visible = qa > 0
		if qa > 0:
			tx.l.modulate = Color(coul.r, coul.g, coul.b, qa / 5.0)


	func _rafraichir(dt: float) -> void:
		var k := 1.0 - exp(-dt * 20.0)
		_balai = minf(1.0, _balai + dt / 0.9)
		_ecrire(0, Vector3.ZERO, Color(L, H, _balai, 0), Color(0, 0, 0, 1))
		_ecrire(1, Vector3(X0 + L_ONGLETS * 0.5, Y_ONGLETS, 0.001), Color(L_ONGLETS, 0.07, 0, 1 + 8 * 5), Color(0, 0, 0, 1))
		var cible_x := _onglets[ecran].c.x
		_ind_x = lerpf(_ind_x, cible_x, 1.0 - exp(-dt * 18.0))
		if absf(_ind_x - cible_x) < 0.0005:
			_ind_x = cible_x
		_ecrire(2, Vector3(_ind_x, Y_ONGLETS, 0.0015), Color(_onglets[0].t.x, 0.06, 0, 1 + 8 * 4), Color(0, 0, 0, 1))
		for i in _onglets.size():
			_onglets[i].actif = i == ecran
		for e in _elems:
			var n := (1 if e.plaque else 0) + (1 if e.icone >= 0 else 0)
			if e.ecran >= 0 and e.ecran != ecran:
				if e.dessine:
					e.dessine = false
					for j in n:
						_ecrire(e.i0 + j, Vector3.ZERO, Color(0, 0, 0, 0), Color(0, 0, 0, 0))
					for tx in e.textes:
						if tx.cle != 0:
							tx.cle = 0
							tx.l.visible = false
				e.s = 0.0
				e.e = 0.0
				e.av = 0.0
				e.eclat = 0.0
				e.al = 1.0 if e.actif else 0.0
				continue
			e.dessine = true
			e.ap = minf(1.0, e.ap + dt / 0.22)
			var alpha := e.ap
			var s := 1.0 if e == _survol_el else 0.0
			e.eclat = maxf(0.0, e.eclat - dt * 4.0)
			e.s = _vers(e.s, s, k)
			e.e = e.eclat
			e.al = _vers(e.al, 1.0 if e.actif else 0.0, k)
			e.av = _vers(e.av, s, k)
			var base := Vector3(e.c.x, e.c.y - 0.012 * (1.0 - alpha) * (1.0 - alpha), 0.001 if e.fond else 0.002 + AVANCE * e.av)
			var i := e.i0
			if e.plaque:
				_ecrire(i, base, Color(e.t.x, e.t.y, 0, 1 + 8 * e.style), Color(e.s, e.e, e.al if e.remplit else 0.0, alpha))
				i += 1
			var m := roundf(e.al * 4.0) / 4.0
			var me := roundf(e.e * 4.0) / 4.0
			if e.icone >= 0:
				var ci := e.ic_coul.lerp(ENCRE, maxf(e.al if e.remplit else 0.0, e.e))
				_ecrire(i, base + Vector3(e.ic_pos.x, e.ic_pos.y, 0.0006), Color(e.ic_t, e.icone, 0, 2), Color(ci.r, ci.g, ci.b, alpha))
			for tx in e.textes:
				var p := Vector3(base.x + tx.pos.x, base.y + tx.pos.y, base.z + 0.0016)
				if tx.l.position != p:
					tx.l.position = p
				_peindre(tx, tx.coul.lerp(tx.actif, m).lerp(ENCRE, me), alpha * opacite)
		var nc := mini(_cibles.size(), 2)
		for i in maxi(nc, _nc_ecrit):
			if i < nc:
				var c: Array = _cibles[i]
				_mm_c.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(c[0], c[1], 0.014)))
				_mm_c.set_instance_custom_data(i, Color(c[2], c[2], 0, 3))
				_mm_c.set_instance_color(i, Color(c[3], c[4], 0, 0))
			else:
				_mm_c.set_instance_custom_data(i, Color(0, 0, 0, 3))
		_nc_ecrit = nc
		_curseurs.visible = nc > 0
