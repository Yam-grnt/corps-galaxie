extends Node3D
## Le corps galaxie — application native pour Meta Quest (Godot 4, OpenXR).
##
## Le modèle (modele.bin + modele.json) est un arbre de nuages de points : chaque nœud est un nuage dont certains
## points s'ouvrent sur un autre nœud (organe → tissu → cellule → … → quark).
## Ce script : charge le modèle, choisit à chaque instant quels nuages afficher et avec quel détail, lit les mains
## (pincer d'une main pour attraper, des deux mains pour zoomer et tourner) et gère l'entrée dans les niveaux.

const OPEN := 12.0          # rayon apparent (pixels) à partir duquel un point-enfant est remplacé par son nuage
const DENS := 0.14          # points affichés par pixel² de surface apparente
const MAX_OBJETS := 500
const MAX_POINTS := 340000
const ENTREE := 0.15        # on entre dans un enfant dès que son rayon dépasse 15 cm autour du point manipulé

class Noeud:
	var nom: String
	var desc: String
	var cat: String
	var couleur: Color
	var n: int
	var ns: int
	var max_r: float
	var min_r: float
	var nk: int
	var kp: PackedVector3Array      # position des enfants (triés du plus gros au plus petit)
	var kr: PackedFloat32Array      # rayon
	var kk: PackedInt32Array        # nœud enfant
	var ko: PackedInt32Array        # orientation (indice dans la table des rotations)
	var pos_off: int
	var att_off: int
	var lod_n: PackedInt32Array     # nombre de points de chaque niveau de détail
	var lod_mesh: Array = []

var bin: PackedByteArray
var noeuds: Array[Noeud] = []
var rots: Array[Basis] = []
var racine := 0
var shader: Shader

# État : pile des niveaux traversés, et placement du niveau courant dans la pièce.
# Un point local x du niveau courant se trouve dans la pièce à : w_p + w_s * (w_a * x)
var chemin: Array = []              # [{n, k}] : nœud et indice d'enfant dans son parent
var w_p := Vector3(0, 1.15, -0.95)
var w_a := Basis.IDENTITY
var w_s := 0.55

var origine: XROrigin3D
var camera: XRCamera3D
var manettes := {}
var monde: Node3D
var reserve: Array[MeshInstance3D] = []
var x_liste := Transform3D.IDENTITY     # repère de la liste affichée → repère du niveau courant
var x_calcul := Transform3D.IDENTITY    # idem pour la liste en cours de calcul
var fil: Thread
var resultat: Array = []
var en_vr := false
var mains: Array = []
var prec = null
var pince := {"left": false, "right": false}
var mm_mains: MultiMesh
var carte: Node3D
var carte_titre: Label3D
var carte_cat: Label3D
var carte_texte: Label3D
var carte_lieu: Label3D
var menu: Node3D
var boutons: Array = []
var appui := ""
var cle_carte := ""
var nb_points := 0
var ips := 72.0
var essai := false


func _ready() -> void:
	essai = "--essai" in OS.get_cmdline_user_args()
	_charger()
	_scene()
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		en_vr = true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		xr.session_begun.connect(func() -> void:
			var f: Array = xr.get_available_display_refresh_rates()
			if 90.0 in f:
				xr.display_refresh_rate = 90.0)
	else:
		camera.position = Vector3(0, 1.25, 0.25)
	chemin = [{"n": racine, "k": -1}]
	_placer_devant()
	if essai:
		_essai()


## Lecture du modèle : positions et couleurs restent dans le tampon binaire, on n'en fait des maillages qu'à la demande.
func _charger() -> void:
	bin = FileAccess.get_file_as_bytes("res://modele.bin")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://modele.json"))
	shader = load("res://points.gdshader")
	var rf := bin.slice(meta.rot_off, meta.rot_off + int(meta.rot_n) * 36).to_float32_array()
	for i in int(meta.rot_n):
		var o := i * 9
		# la table est écrite ligne par ligne ; Basis attend ses trois colonnes
		rots.append(Basis(Vector3(rf[o], rf[o + 3], rf[o + 6]), Vector3(rf[o + 1], rf[o + 4], rf[o + 7]), Vector3(rf[o + 2], rf[o + 5], rf[o + 8])))
	for m: Dictionary in meta.noeuds:
		var nd := Noeud.new()
		nd.nom = m.nom
		nd.desc = m.desc
		nd.cat = m.cat
		nd.couleur = Color.html(m.hex)
		nd.n = int(m.n)
		nd.ns = int(m.ns)
		nd.max_r = m.max_r
		nd.min_r = m.min_r
		nd.nk = int(m.nk)
		nd.pos_off = int(m.pos)
		nd.att_off = int(m.att)
		var kf := bin.slice(int(m.kp), int(m.kp) + nd.nk * 12).to_float32_array()
		nd.kp.resize(nd.nk)
		for k in nd.nk:
			nd.kp[k] = Vector3(kf[3 * k], kf[3 * k + 1], kf[3 * k + 2])
		nd.kr = bin.slice(int(m.kr), int(m.kr) + nd.nk * 4).to_float32_array()
		nd.kk = bin.slice(int(m.kk), int(m.kk) + nd.nk * 4).to_int32_array()
		nd.ko = bin.slice(int(m.ko), int(m.ko) + nd.nk * 4).to_int32_array()
		var c := nd.n
		while true:
			nd.lod_n.append(c)
			nd.lod_mesh.append(null)
			if c <= 96:
				break
			c = c / 2
		noeuds.append(nd)
	racine = int(meta.racine)


## Maillage d'un niveau de détail : les `c` premiers points du nœud (ils sont mélangés, donc tout préfixe est représentatif).
func _maillage(nd: Noeud, lod: int) -> ArrayMesh:
	if nd.lod_mesh[lod] != null:
		return nd.lod_mesh[lod]
	var c := nd.lod_n[lod]
	var pf := bin.slice(nd.pos_off, nd.pos_off + c * 12).to_float32_array()
	var pv := PackedVector3Array()
	pv.resize(c)
	for i in c:
		pv[i] = Vector3(pf[3 * i], pf[3 * i + 1], pf[3 * i + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pv
	arr[Mesh.ARRAY_CUSTOM0] = bin.slice(nd.att_off, nd.att_off + c * 16).to_float32_array()
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("cnt", float(c))
	mat.set_shader_parameter("boost", minf(1.5, sqrt(float(nd.n) / float(c))))
	m.surface_set_material(0, mat)
	m.custom_aabb = AABB(Vector3(-1.3, -1.3, -1.3), Vector3(2.6, 2.6, 2.6))
	nd.lod_mesh[lod] = m
	return m


func _scene() -> void:
	origine = XROrigin3D.new()
	add_child(origine)
	camera = XRCamera3D.new()
	camera.near = 0.02
	camera.far = 4000.0
	origine.add_child(camera)
	for cote in ["left", "right"]:
		var c := XRController3D.new()
		c.tracker = cote + "_hand"
		origine.add_child(c)
		manettes[cote] = c
	monde = Node3D.new()
	add_child(monde)
	for i in MAX_OBJETS:
		var mi := MeshInstance3D.new()
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		monde.add_child(mi)
		reserve.append(mi)
	# mains : une petite bille par articulation, plus un trait de billes dorées entre les deux mains pendant le zoom
	mm_mains = MultiMesh.new()
	mm_mains.transform_format = MultiMesh.TRANSFORM_3D
	mm_mains.use_colors = true
	var bille := SphereMesh.new()
	bille.radius = 0.5
	bille.height = 1.0
	bille.radial_segments = 8
	bille.rings = 4
	var mb := StandardMaterial3D.new()
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.vertex_color_use_as_albedo = true
	bille.material = mb
	mm_mains.mesh = bille
	mm_mains.instance_count = 80
	mm_mains.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm_mains
	mmi.custom_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	add_child(mmi)
	_panneaux()


func _fond(taille: Vector2) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = taille
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.02, 0.02, 0.03, 0.86)
	m.render_priority = -1      # le fond se dessine avant le texte
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	return mi


func _texte(parent: Node3D, pos: Vector3, taille: int, couleur: Color, largeur := 0.0) -> Label3D:
	var l := Label3D.new()
	l.pixel_size = 0.0004
	l.font_size = taille
	l.outline_size = 0
	l.modulate = couleur
	l.shaded = false
	l.render_priority = 2
	l.no_depth_test = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if largeur > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = largeur / l.pixel_size
	l.position = pos
	parent.add_child(l)
	return l


## Deux panneaux posés dans la pièce : la carte d'explication à droite, le menu à gauche.
func _panneaux() -> void:
	carte = Node3D.new()
	add_child(carte)
	carte.add_child(_fond(Vector2(0.44, 0.2)))
	carte_lieu = _texte(carte, Vector3(-0.205, 0.092, 0.002), 22, Color(0.56, 0.56, 0.58), 0.41)
	carte_titre = _texte(carte, Vector3(-0.205, 0.072, 0.002), 60, Color(0.95, 0.95, 0.93))
	carte_cat = _texte(carte, Vector3(-0.205, 0.04, 0.002), 22, Color.WHITE)
	carte_texte = _texte(carte, Vector3(-0.205, 0.022, 0.002), 30, Color(0.95, 0.95, 0.93), 0.41)
	menu = Node3D.new()
	add_child(menu)
	var defs := [["home", "Revenir au corps", -0.09], ["exit", "Quitter", 0.09]]
	for d in defs:
		var f := _fond(Vector2(0.17, 0.08))
		f.position = Vector3(d[2], 0, 0)
		menu.add_child(f)
		var l := _texte(menu, Vector3(d[2], 0, 0.002), 40, Color(0.95, 0.95, 0.93))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.text = d[1]
		boutons.append({"id": d[0], "x": d[2], "fond": f})


func _tete() -> Vector3:
	return camera.global_position


## Replace le corps entier devant soi, et les panneaux de part et d'autre.
func _placer_devant() -> void:
	var h := _tete()
	var f := -camera.global_basis.z
	f.y = 0
	f = f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)
	chemin = [{"n": racine, "k": -1}]
	w_s = 0.5
	w_a = Basis(Vector3.UP, atan2(-f.x, -f.z))
	w_p = Vector3(h.x + f.x * 0.9, maxf(0.9, h.y - 0.35), h.z + f.z * 0.9)
	prec = null
	x_liste = Transform3D.IDENTITY
	x_calcul = Transform3D.IDENTITY
	for def in [[carte, 0.75, -0.12, 0.75], [menu, -0.75, -0.3, 0.6]]:
		var dir := f.rotated(Vector3.UP, -def[1])
		var c := Vector3(h.x + dir.x * def[3], h.y + def[2], h.z + dir.z * def[3])
		(def[0] as Node3D).look_at_from_position(c, c + (c - h), Vector3.UP)   # la face avant (+z) regarde la tête


func _courant() -> Noeud:
	return noeuds[chemin[-1].n]


func _local(nd: Noeud, k: int) -> Transform3D:
	return Transform3D(rots[nd.ko[k]] * nd.kr[k], nd.kp[k])


func _entrer(k: int) -> void:
	var nd := _courant()
	var c := _local(nd, k)
	w_p = w_p + (w_a * nd.kp[k]) * w_s
	w_a = w_a * rots[nd.ko[k]]
	w_s *= nd.kr[k]
	chemin.append({"n": nd.kk[k], "k": k})
	var ci := c.affine_inverse()
	x_liste = ci * x_liste
	x_calcul = ci * x_calcul


func _sortir() -> void:
	var e: Dictionary = chemin.pop_back()
	var nd := _courant()
	var k: int = e.k
	w_s /= nd.kr[k]
	w_a = w_a * rots[nd.ko[k]].transposed()
	w_p = w_p - (w_a * nd.kp[k]) * w_s
	var c := _local(nd, k)
	x_liste = c * x_liste
	x_calcul = c * x_calcul


## Après chaque geste : entre dans l'enfant qui entoure le point manipulé, ou ressort du niveau devenu petit.
## Dans le vide, l'enfant assez gros le plus proche est attiré vers le point manipulé, pour qu'on tombe toujours dans quelque chose.
func _relier(foyer: Vector3, dt: float) -> void:
	var ressorti := false
	for it in 8:
		var nd := _courant()
		if chemin.size() > 1 and (w_s < 0.06 or foyer.distance_to(w_p) > 1.5 * w_s + 0.3):
			_sortir()
			ressorti = true
			continue
		var f := (w_a.transposed() * (foyer - w_p)) / w_s
		var smax := (0.5 / nd.min_r) if nd.nk > 0 else 5.0
		var mieux := -1
		var proche := -1
		var ecart := 1e9 if w_s >= smax * 0.98 else maxf(0.5 / w_s, 0.3)
		for k in nd.nk:
			var r := nd.kr[k]
			if r * w_s < ENTREE:
				break
			var d := nd.kp[k].distance_to(f)
			if d < r * 0.9:
				mieux = k      # triés par taille : le premier qui contient le foyer est le plus gros
				break
			elif d - r < ecart:
				proche = k
				ecart = d - r
		if mieux < 0 and proche >= 0 and not ressorti:
			var c := w_p + (w_a * nd.kp[proche]) * w_s
			w_p += (foyer - c) * (1.0 - exp(-dt * 6.0))
			break
		if mieux >= 0:
			_entrer(mieux)
			continue
		break
	var cur := _courant()
	var lim := clampf(w_s, 0.05 if chemin.size() == 1 else 0.01, (0.5 / cur.min_r) if cur.nk > 0 else 5.0)
	if lim != w_s:
		w_p = foyer + (w_p - foyer) * (lim / w_s)
		w_s = lim
	w_a = w_a.orthonormalized()


# ───────── choix de ce qu'on affiche (calculé dans un fil à part, dans le repère du niveau courant) ─────────

func _collecter(ni: int, t: Vector3, a: Basis, s: float, prof: int, sortie: Array, st: Dictionary) -> void:
	var nd := noeuds[ni]
	var d := maxf(st.dmin, t.distance_to(st.tete))
	var px: float = s / d * st.f
	var veut := nd.ns + px * px * DENS
	var lod := 0
	while lod < nd.lod_n.size() - 1 and nd.lod_n[lod + 1] >= veut:
		lod += 1
	sortie.append([ni, lod, Transform3D(a * s, t)])
	st.total += nd.lod_n[lod]
	if nd.nk == 0 or prof >= 7:
		return
	var dpres := maxf(st.dmin * 1.7, d - s)
	var cand: Array = []
	for k in nd.nk:
		var r := nd.kr[k] * s
		if r / dpres * st.f < OPEN * 0.5:
			break
		var c := t + a * (nd.kp[k] * s)
		var dv: Vector3 = c - st.tete
		var dd := maxf(st.dmin, dv.length())
		var pr: float = r / dd * st.f
		if pr < OPEN * 0.5:
			continue
		if dd > r and dv.dot(st.avant) < 0.25 * dd - r:
			continue      # hors du champ de vision
		cand.append([pr, k, c])
	cand.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	for c in cand:
		if sortie.size() >= MAX_OBJETS or st.total > MAX_POINTS:
			break
		var k: int = c[1]
		_collecter(nd.kk[k], c[2], a * rots[nd.ko[k]], s * nd.kr[k], prof + 1, sortie, st)


func _calculer(inst: Dictionary) -> void:
	var sortie: Array = []
	var t := Vector3.ZERO
	var a := Basis.IDENTITY
	var s := 1.0
	var haut: int = inst.chemin.size() - 1
	for montee in 2:      # on remonte de deux niveaux au plus, pour voir les voisins sans perdre en précision
		if haut <= 0:
			break
		var e: Dictionary = inst.chemin[haut]
		var par := noeuds[inst.chemin[haut - 1].n]
		var k: int = e.k
		var sp := s / par.kr[k]
		if sp * inst.w_s > 2500.0:
			break
		var ap := a * rots[par.ko[k]].transposed()
		t = t - (ap * par.kp[k]) * sp
		a = ap
		s = sp
		haut -= 1
	var st := {"tete": inst.tete, "avant": inst.avant, "f": inst.f, "dmin": 0.03 / inst.w_s, "total": 0}
	_collecter(inst.chemin[haut].n, t, a, s, 0, sortie, st)
	resultat = [sortie, st.total]


func _lancer_calcul() -> void:
	var inv := w_a.transposed()
	var h := _tete()
	var vh := float(get_viewport().size.y)
	var fov := deg_to_rad(96.0 if en_vr else camera.fov)
	var inst := {"chemin": chemin.duplicate(true), "w_s": w_s, "tete": (inv * (h - w_p)) / w_s, "avant": inv * (-camera.global_basis.z), "f": vh * 0.5 / tan(fov * 0.5)}
	x_calcul = Transform3D.IDENTITY
	if essai:
		_calculer(inst)
		_appliquer()
		return
	fil = Thread.new()
	fil.start(_calculer.bind(inst))


func _appliquer() -> void:
	var liste: Array = resultat[0]
	nb_points = resultat[1]
	x_liste = x_calcul
	for i in reserve.size():
		var mi := reserve[i]
		if i < liste.size():
			var it: Array = liste[i]
			mi.mesh = _maillage(noeuds[it[0]], it[1])
			mi.transform = it[2]
			mi.visible = true
		else:
			mi.visible = false


# ───────── mains et manettes ─────────

func _lire_mains(dt: float) -> void:
	mains.clear()
	var nb := 0
	var o := origine.global_transform
	for cote in ["left", "right"]:
		var m := {}
		var tr := XRServer.get_tracker("/user/hand_tracker/" + cote) as XRHandTracker
		if tr and tr.has_tracking_data:
			var pouce := o * tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP).origin
			var index := o * tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP).origin
			var d := pouce.distance_to(index)
			pince[cote] = d < 0.055 if pince[cote] else d < 0.028
			m = {"id": cote, "pos": (pouce + index) * 0.5, "bout": index, "pince": pince[cote],
				"q": (o.basis * tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST).basis).orthonormalized().get_rotation_quaternion()}
			var coul := Color(1, 0.85, 0.3) if pince[cote] else Color(0.45, 0.85, 1)
			for j in XRHandTracker.HAND_JOINT_MAX:
				if nb < 80:
					mm_mains.set_instance_transform(nb, Transform3D(Basis.IDENTITY * 0.009, o * tr.get_hand_joint_transform(j).origin))
					mm_mains.set_instance_color(nb, coul)
					nb += 1
		else:
			var c: XRController3D = manettes[cote]
			if en_vr and c.get_has_tracking_data():
				var p := c.global_position
				var serre := c.is_button_pressed("trigger_click") or c.get_float("trigger") > 0.5 or c.get_float("grip") > 0.5
				m = {"id": cote, "pos": p, "bout": p, "pince": serre, "q": c.global_basis.orthonormalized().get_rotation_quaternion()}
				var joy := c.get_vector2("primary").y      # joystick : pousser agrandit, tirer réduit
				if absf(joy) > 0.2:
					var k := exp(joy * dt * 2.2)
					w_s *= k
					w_p = p + (w_p - p) * k
					_relier(p, dt)
				if c.is_button_pressed("by_button"):
					get_tree().quit()
				if nb < 80:
					mm_mains.set_instance_transform(nb, Transform3D(Basis.IDENTITY * 0.024, p))
					mm_mains.set_instance_color(nb, Color(1, 0.85, 0.3) if serre else Color(0.45, 0.85, 1))
					nb += 1
		if not m.is_empty():
			mains.append(m)
	var g := mains.filter(func(x: Dictionary) -> bool: return x.pince)
	if g.size() == 2:
		for i in range(1, 24):
			if nb < 80:
				mm_mains.set_instance_transform(nb, Transform3D(Basis.IDENTITY * 0.006, (g[0].pos as Vector3).lerp(g[1].pos, i / 24.0)))
				mm_mains.set_instance_color(nb, Color(1, 0.85, 0.3))
				nb += 1
	mm_mains.visible_instance_count = nb


## Chaque image applique le petit mouvement des mains depuis l'image précédente, directement sur le monde.
func _gestes(dt: float) -> void:
	var g := mains.filter(func(x: Dictionary) -> bool: return x.pince)
	var cle := ""
	for m in g:
		cle += m.id
	if prec != null and prec.cle == cle and g.size() == 1:
		# une main : l'objet suit la main et tourne avec le poignet
		var dq := Basis((g[0].q as Quaternion) * (prec.q as Quaternion).inverse())
		w_a = dq * w_a
		w_p = g[0].pos + dq * (w_p - prec.a)
		_relier(g[0].pos, dt)
	elif prec != null and prec.cle == cle and g.size() == 2:
		# deux mains : écarter pour grossir, tourner pour faire pivoter, autour du point entre les mains
		var a: Vector3 = g[0].pos
		var b: Vector3 = g[1].pos
		var m := (a + b) * 0.5
		var m0: Vector3 = (prec.a + prec.b) * 0.5
		var k := pow(maxf(0.03, a.distance_to(b)) / maxf(0.03, (prec.a as Vector3).distance_to(prec.b)), 1.6)
		var v0: Vector3 = (prec.b - prec.a).normalized()
		var v1 := (b - a).normalized()
		var dq := Basis(Quaternion(v0, v1)) if v0.distance_to(v1) > 1e-5 else Basis.IDENTITY
		w_a = dq * w_a
		w_s *= k
		w_p = m + (dq * (w_p - m0)) * k
		_relier(m, dt)
	if g.size() > 0:
		prec = {"cle": cle, "a": g[0].pos, "q": g[0].q, "b": g[1].pos if g.size() > 1 else Vector3.ZERO}
	else:
		prec = null


## L'index touche un bouton du menu.
func _toucher_menu() -> void:
	var touche := ""
	var inv := menu.global_transform.affine_inverse()
	for m in mains:
		var l: Vector3 = inv * (m.bout as Vector3)
		if absf(l.z) > 0.03 or absf(l.y) > 0.04:
			continue
		for b in boutons:
			if absf(l.x - b.x) < 0.085:
				touche = b.id
	if touche != "" and touche != appui:
		if touche == "exit":
			get_tree().quit()
		else:
			_placer_devant()
	appui = touche
	for b in boutons:
		((b.fond as MeshInstance3D).mesh as QuadMesh).material.albedo_color = Color(0.9, 0.9, 0.88, 0.95) if b.id == appui else Color(0.02, 0.02, 0.03, 0.86)


## La carte montre ce que touche l'index, sinon le niveau où l'on se trouve.
func _maj_carte() -> void:
	var nd := _courant()
	var cle := nd.nom + str(chemin.size())
	if cle == cle_carte:
		return
	cle_carte = cle
	var lieu := ""
	for e in chemin:
		lieu += ("  ›  " if lieu != "" else "") + noeuds[e.n].nom
	carte_lieu.text = lieu.right(64)
	carte_titre.text = nd.nom
	carte_cat.text = nd.cat.to_upper()
	carte_cat.modulate = nd.couleur
	carte_texte.text = nd.desc


var images := 0

func _process(dt: float) -> void:
	if essai:
		return
	images += 1
	if "--photo" in OS.get_cmdline_user_args():      # capture d'écran automatique, pour vérifier le rendu sans casque
		if images == 20:
			w_p = Vector3(0, 1.15 - 0.868 * 6.0, -0.95)
			w_s = 6.0
			_relier(FOYER, 0.016)
		if images == 90 or images == 200:
			get_viewport().get_texture().get_image().save_png("user://photo%d.png" % images)
		if images == 201:
			get_tree().quit()
	ips = lerpf(ips, 1.0 / maxf(dt, 0.001), 0.05)
	_lire_mains(dt)
	_gestes(dt)
	_toucher_menu()
	_maj_carte()
	if fil != null and not fil.is_alive():
		fil.wait_to_finish()
		fil = null
		_appliquer()
	if fil == null:
		_lancer_calcul()
	monde.transform = Transform3D(w_a * w_s, w_p) * x_liste


func _exit_tree() -> void:
	if fil != null:
		fil.wait_to_finish()


# ───────── aperçu sur ordinateur (sans casque) : glisser pour tourner, molette pour zoomer ─────────

const FOYER := Vector3(0, 1.15, -0.95)

func _unhandled_input(ev: InputEvent) -> void:
	if en_vr:
		return
	if ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_zoom_foyer(1.25 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8, 0.05)
	elif ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var dq := Basis(Vector3.UP, ev.relative.x * 0.006) * Basis(Vector3.RIGHT, ev.relative.y * 0.006)
		w_a = dq * w_a
		w_p = FOYER + dq * (w_p - FOYER)


func _zoom_foyer(k: float, dt: float) -> void:
	w_s *= k
	w_p = FOYER + (w_p - FOYER) * k
	_relier(FOYER, dt)


## Essai automatique (godot --headless -- --essai) : zoome sans s'arrêter et vérifie qu'on descend bien dans les niveaux.
func _essai() -> void:
	w_p = Vector3(0, 1.15 - 0.868 * w_s, -0.95)      # la tête du modèle sous le point manipulé
	var plus_profond := 1
	for i in 900:
		_zoom_foyer(1.06, 0.016)
		plus_profond = maxi(plus_profond, chemin.size())
		if i % 150 == 149:
			_lancer_calcul()
			var lieu := ""
			for e in chemin:
				lieu += " > " + noeuds[e.n].nom
			print("zoom ", i + 1, lieu, " | échelle ", snappedf(w_s, 0.01), " | objets ", resultat[0].size(), " | points ", nb_points)
	for i in 1200:
		_zoom_foyer(0.94, 0.016)
	print("retour : ", noeuds[chemin[-1].n].nom, " (", chemin.size(), " niveau)")
	print("ESSAI ", "OK" if plus_profond >= 6 and chemin.size() == 1 else "ÉCHEC", " — profondeur atteinte : ", plus_profond)
	get_tree().quit(0 if plus_profond >= 6 and chemin.size() == 1 else 1)
