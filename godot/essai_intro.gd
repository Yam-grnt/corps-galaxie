extends Node3D
## Essai de l'introduction sur ordinateur, sans casque :
##   Godot --xr-mode off --path godot res://essai_intro.tscn            → à la souris (clic gauche = gâchette, Échap = passer)
##   Godot --xr-mode off --path godot res://essai_intro.tscn -- --photo → déroule tout seul, enregistre des captures dans user:// et quitte
##   Godot --xr-mode off --path godot res://essai_intro.tscn -- --vitrine → seulement des panneaux « comme dans main.gd », vus de près
##       (apparition, survol, jauge, appui, poignée, fond clair de réalité mixte), captures vitrine_*.png, puis quitte
## En mode photo le temps est simulé (pas fixe), un pointeur fictif vise les boutons, et le panneau est vérifié au doigt.

const IntroScript := preload("res://intro.gd")
const PanneauScript := preload("res://panneau.gd")

const SEQUENCES := [
	{"scene": "nuit", "texte": "Avant toi, il y a eu la nuit. Une nuit immense, et presque vide."},
	{"scene": "galaxie", "texte": "Dans cette nuit, des galaxies se sont mises à tourner, lentement."},
	{"scene": "poussiere", "texte": "Des étoiles y sont nées, puis mortes, en semant leur poussière."},
	{"scene": "corps", "texte": "Cette poussière, un jour, s'est rassemblée. Elle a pris ta forme."},
	{"scene": "plongee", "texte": "Approche-toi : chaque point de ton corps est une cellule vivante, avec son noyau et ses organites."},
	{"scene": "atome", "texte": "Et plus près encore, des atomes : un noyau minuscule, enveloppé d'un nuage d'électrons."},
	{"scene": "retour", "texte": "Tu es fait de tout cela. Tu es un corps galaxie."},
	{"scene": "menu", "texte": "Choisis ton corps et ta façon de voyager, puis entre."},
]

## Fausse voix : même interface que voix.gd, mais muette.
class FausseVoix extends Node:
	var a_des_clips := false
	func dire(_cles: Array, _a_la_suite := false) -> void:
		pass
	func parle() -> bool:
		return false
	func taire() -> void:
		pass

var camera: Camera3D
var intro: IntroScript
var photo := false
var secours := false         # --secours : aucune séquence, aucune voix, aucune silhouette, et on passe l'intro au bout de 3 s
var clic := false
var appui := false
var bille: MeshInstance3D
var t_sim := 0.0
var image := 0
var prises: Array = []          # [instant simulé, nom] des captures à faire
var script_menu: Array = []     # [instant après l'ouverture du menu, id visé ("" : rien, "@…" : action simulée), clic]
var attendus: Array = []        # [instant après l'ouverture du menu, clé de intro.choix (ou "ecran", "demandes"), valeur attendue]
var demandes := 0               # nombre de signaux demande_nom reçus
var ok_menu := true
var t_limite := 14.0
var t_pas := 2.0
var t_menu := -1.0
var vise := Vector3.ZERO
var a_viser := false
var clic_prevu := false
var fini := false
var vitrine := false
var v_menu: PanneauScript
var v_barre: PanneauScript
var v_env: Environment
var v_ok := true


func _ready() -> void:
	photo = "--photo" in OS.get_cmdline_user_args()
	secours = "--secours" in OS.get_cmdline_user_args()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.004, 0.006, 0.016)
	add_child(env)
	v_env = env.environment
	vitrine = "--vitrine" in OS.get_cmdline_user_args()
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 0)
	camera.fov = 90.0       # proche du champ vertical d'un casque
	camera.near = 0.02
	add_child(camera)
	bille = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.006
	s.height = 0.012
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.85, 0.3)
	m.no_depth_test = true
	m.render_priority = 10
	s.material = m
	bille.mesh = s
	add_child(bille)
	var police: Font = null
	var base := ThemeDB.fallback_font
	if base is FontFile:
		var f := (base as FontFile).duplicate() as FontFile
		f.multichannel_signed_distance_field = true
		f.msdf_pixel_range = 12
		police = f
	if vitrine:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		_vitrine_prete(police)
		return
	var voix := FausseVoix.new()
	add_child(voix)
	intro = IntroScript.new()
	add_child(intro)
	var debut := Time.get_ticks_msec()
	# la femme vient du vrai modèle s'il est là ; l'homme est laissé vide pour essayer aussi la silhouette de secours
	if secours:
		intro.preparer([], null, null, {}, {"corps": "homme", "niveau": 0})
	else:
		intro.preparer(SEQUENCES, voix, police, {"femme": _silhouette_du_modele(), "homme": PackedVector3Array()},
			{"corps": "femme", "niveau": 1, "en_ligne": "--en-ligne" in OS.get_cmdline_user_args()})
	print("préparation : ", Time.get_ticks_msec() - debut, " ms pour ", IntroScript.N, " points")
	intro.placer(camera.global_position, Vector3(0, 0, -1))
	intro.termine.connect(_termine)
	intro.demande_nom.connect(func() -> void:
		demandes += 1
		print("demande_nom"))
	intro.touche.connect(func(id: String) -> void: print("survol : ", id))
	if secours:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		return
	if photo:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("captures dans : ", ProjectSettings.globalize_path("user://"))
		_essai_doigt(police)
		# une capture à mi-passage et une à la fin de chaque séquence
		var t := 0.0
		for i in SEQUENCES.size():
			var duree := 2.5 + 0.075 * (SEQUENCES[i].texte as String).length()
			if SEQUENCES[i].scene == "menu":
				t_menu = t
				break
			if i > 0:
				prises.append([t + 1.9, "intro_%d_%s_passage" % [i, SEQUENCES[i].scene]])
			prises.append([t + duree - 0.2, "intro_%d_%s" % [i, SEQUENCES[i].scene]])
			t += duree
		ok_menu = IntroScript.former_nom("  elle s'appelle marie-christine de la tour. ") == "Marie-Christine" 			and IntroScript.former_nom("zelie") == "Zélie" and IntroScript.former_nom("anne lise") == "Anne Lise" 			and IntroScript.former_nom("…") == "" and IntroScript.former_nom("abcdefghijklmnopqrstuvwxyz").length() == 16
		print("mise en forme des noms : ", "OK" if ok_menu else "ÉCHEC")
		# chaque ligne : on vise (et on clique) ; les captures et les vérifications se font un peu après
		prises.append([t_menu + 1.55, "menu_apparition"])
		prises.append([t_menu + 1.95, "menu_toi"])
		_pas("homme", "menu_toi_homme", "corps", "homme")
		_pas("femme", "", "corps", "femme")
		_pas("homme", "", "corps", "homme")
		_pas("enfant", "", "niveau", 0)
		_pas("curieux", "", "niveau", 1)
		_pas("scientifique", "menu_toi_scientifique", "niveau", 2)
		_pas("suivant", "menu_guide", "ecran", 1)
		_pas("descriptif", "", "mode", "descriptif")
		_pas("incarne", "menu_guide_incarne", "mode", "incarne")
		for i in IntroScript.PRENOMS.size():
			_pas("nom:%d" % i, "menu_guide_prenom" if i == 2 else "", "nom", IntroScript.PRENOMS[i])
		_pas("sans", "menu_guide_sans_nom", "nom", "")
		_pas("dis", "menu_guide_ecoute", "demandes", 1)
		_pas("@entendu:lune", "menu_guide_entendu", "nom", "Lune")
		_pas("dis", "", "demandes", 2)
		_pas("@entendu:capucine", "menu_guide_entendu_libre", "nom", "Capucine")
		_pas("dis", "", "demandes", 3)
		_pas("@refuse", "menu_guide_refus", "nom", "Capucine")
		_pas("vous", "", "tutoiement", false)
		t_pas += 4.2       # le message s'efface : retour à la phrase du nom
		prises.append([t_menu + t_pas, "menu_guide_vous"])
		_pas("retour", "menu_toi_vous", "ecran", 0)
		_pas("tu", "", "tutoiement", true)
		_pas("nav:1", "", "ecran", 1)
		_pas("nav:0", "", "ecran", 0)
		_pas("suivant", "", "ecran", 1)
		_pas("alba", "", "nom", "Alba")
		script_menu.append([t_pas, "demarrer", false])
		prises.append([t_menu + t_pas + 0.2, "menu_demarrer"])
		script_menu.append([t_pas + 0.25, "demarrer", true])
		prises.append([t_menu + t_pas + 0.6, "menu_fondu"])
		t_limite = t_pas + 4.0


func _pas(id: String, capture := "", cle := "", valeur: Variant = null) -> void:
	script_menu.append([t_pas, id, false])
	script_menu.append([t_pas + 0.25, id, true])
	if cle != "":
		attendus.append([t_pas + 0.45, cle, valeur])
	if capture != "":
		prises.append([t_menu + t_pas + 0.55, capture])
	t_pas += 0.7


func _silhouette_du_modele() -> PackedVector3Array:
	var v := PackedVector3Array()
	if not FileAccess.file_exists("res://modele.json") or not FileAccess.file_exists("res://modele.bin"):
		return v
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://modele.json"))
	if not meta is Dictionary:
		return v
	var nd: Dictionary = meta.noeuds[int(meta.racine)]
	var n := mini(int(nd.n), 8000)
	var f := FileAccess.open("res://modele.bin", FileAccess.READ)
	f.seek(int(nd.pos))
	var pf := f.get_buffer(n * 12).to_float32_array()
	v.resize(n)
	var bas := 1e9
	var haut := -1e9
	for i in n:
		v[i] = Vector3(pf[3 * i], pf[3 * i + 1], pf[3 * i + 2])
		bas = minf(bas, v[i].y)
		haut = maxf(haut, v[i].y)
	print("silhouette du modèle : ", n, " points, y de ", snappedf(bas, 0.01), " à ", snappedf(haut, 0.01))
	return v


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			clic = true
		appui = ev.pressed
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		intro.passer()
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_R:
		intro.placer(camera.global_position, Vector3(0, 0, -1))


func _process(dt: float) -> void:
	if fini:
		return
	image += 1
	var pointeurs: Array = []
	if vitrine:
		_vitrine(1.0 / 45.0)
		return
	if secours:
		# passe l'intro en plein passage, recentre, bascule homme → femme, et photographie le menu
		if image == 135:
			intro.passer()
			intro.placer(camera.global_position + Vector3(0.05, 0, 0), Vector3(0.05, 0.3, -1).normalized())
		if image == 330:
			intro.choix.corps = "femme"
		if image == 300 or image == 345 or image == 500:
			get_viewport().get_texture().get_image().save_png("user://secours_%d.png" % image)
		if image == 501:
			fini = true
			get_tree().quit()
		intro.maj(1.0 / 45.0, [])
		return
	if secours:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		return
	if photo:
		# la capture montre l'image précédente, c'est-à-dire l'instant t_sim
		while not prises.is_empty() and t_sim >= prises[0][0]:
			var nom: String = prises.pop_front()[1]
			get_viewport().get_texture().get_image().save_png("user://%s.png" % nom)
			print("capture ", nom, " à ", snappedf(t_sim, 0.01), " s")
		dt = 1.0 / 45.0
		if image < 4:
			dt = 0.0        # laisse le temps aux shaders de se compiler
		t_sim += dt
		if t_menu >= 0.0 and t_sim > t_menu + 1.6 and camera.fov > 60.0:
			# une fois le menu ouvert, on le regarde en face (comme on tourne la tête dans le casque)
			camera.rotation.y = deg_to_rad(-23.0)
			camera.rotation.x = deg_to_rad(-5.0)
			camera.fov = 52.0
		clic_prevu = false
		while not script_menu.is_empty() and t_sim >= t_menu + script_menu[0][0]:
			var e: Array = script_menu.pop_front()
			var quoi: String = e[1]
			if quoi == "alba":
				quoi = "nom:1"
			if quoi.begins_with("@"):
				if e[2] and quoi.begins_with("@entendu:"):
					intro.nom_entendu(quoi.substr(9))
				elif e[2]:
					intro.nom_refuse()
				continue
			a_viser = quoi != ""
			if a_viser:
				vise = intro._menu.centre_de(quoi) + intro._menu.global_basis * Vector3(0.03, -0.012, 0)
			clic_prevu = e[2]
		while not attendus.is_empty() and t_sim >= t_menu + attendus[0][0]:
			var v: Array = attendus.pop_front()
			var vu: Variant = intro._menu.ecran if v[1] == "ecran" else (demandes if v[1] == "demandes" else intro.choix.get(v[1]))
			if vu != v[2]:
				ok_menu = false
				print("ÉCHEC à ", v[0], " s : ", v[1], " = ", vu, " (attendu : ", v[2], ")")
		if a_viser:
			var o := camera.global_position + Vector3(0.2, -0.35, -0.1)     # comme une main tenue devant soi
			pointeurs.append({"o": o, "d": (vise - o).normalized(), "clic": clic_prevu, "appui": clic_prevu, "bout": o, "doigt": false})
		if t_sim > t_menu + t_limite:
			print("ÉCHEC : l'intro ne s'est pas terminée")
			fini = true
			get_tree().quit(1)
	else:
		var souris := get_viewport().get_mouse_position()
		pointeurs.append({"o": camera.project_ray_origin(souris), "d": camera.project_ray_normal(souris), "clic": clic, "appui": appui,
			"bout": camera.global_position, "doigt": false})
		clic = false
	intro.maj(dt, pointeurs)
	bille.visible = not intro.impacts.is_empty()
	if bille.visible:
		bille.global_position = intro.impacts[0]


func _termine(choix: Dictionary) -> void:
	print("terminé : ", choix)
	if secours:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		return
	if photo:
		fini = true
		var attendu := {"corps": "homme", "niveau": 2, "mode": "incarne", "nom": "Alba", "tutoiement": true}
		var ok: bool = ok_menu and attendus.is_empty() and choix == attendu
		print("ESSAI INTRO ", "OK" if ok else "ÉCHEC (choix attendu : %s)" % [attendu])
		get_tree().quit(0 if ok else 1)


## Vérifie l'appui au doigt sur un panneau à part : par l'avant (une seule activation tant qu'on ne ressort pas),
## par l'arrière (ignoré), et le bouton à maintenir.
func _essai_doigt(police: Font) -> void:
	var p := PanneauScript.new(police)
	add_child(p)
	p.position = Vector3(0, 0, 30)      # loin derrière la caméra
	p.bouton("a", "A", Vector2(-0.1, 0), Vector2(0.17, 0.075))
	p.bouton("q", "Quitter", Vector2(0.1, 0), Vector2(0.17, 0.075), 1.0)
	var doigt := func(x: float, z: float) -> Array:
		return [{"o": Vector3(0, 0, 40), "d": Vector3(0, 1, 0), "clic": false, "appui": false, "bout": p.global_transform * Vector3(x, 0, z), "doigt": true}]
	var ok := true
	var n := 0
	for z: float in [0.06, 0.03, 0.01, 0.0, -0.01, -0.005, 0.005, 0.0, -0.01, 0.01]:    # entre par l'avant, tremble, sans ressortir
		if p.maj(doigt.call(-0.1, z), 0.02) == "a":
			n += 1
	ok = ok and n == 1
	for z: float in [0.03, 0.0]:                                                       # ressort, puis rappuie
		if p.maj(doigt.call(-0.1, z), 0.02) == "a":
			n += 1
	ok = ok and n == 2
	p.maj([], 0.02)
	for z: float in [-0.2, -0.05, -0.01, 0.0, -0.01]:                                  # arrive par l'arrière
		if p.maj(doigt.call(-0.1, z), 0.02) != "":
			ok = false
	p.maj([], 0.02)
	var t_q := -1.0
	var t := 0.0
	for i in 80:                                                                        # maintien : activé après 1 s, une seule fois
		var z := 0.05 if i == 0 else -0.003
		if p.maj(doigt.call(0.1, z), 0.02) == "q":
			ok = ok and t_q < 0.0
			t_q = t
		t += 0.02
	ok = ok and t_q > 0.95 and t_q < 1.1
	p.maj([], 0.02)
	n = 0
	for i in 30:                                                                        # maintien relâché trop tôt : rien
		if p.maj(doigt.call(0.1, 0.05 if i == 0 else -0.003), 0.02) != "":
			n += 1
	p.maj(doigt.call(0.1, 0.05), 0.02)
	# rayon : survol sans clic, puis clic
	var rayon := func(c: bool) -> Array:
		return [{"o": p.global_transform * Vector3(-0.1, 0.01, 0.8), "d": -p.global_basis.z, "clic": c, "appui": c, "bout": Vector3.ZERO, "doigt": false}]
	ok = ok and n == 0 and p.maj(rayon.call(false), 0.02) == "" and p.survol == "a" and p.impacts.size() == 1
	ok = ok and p.survol_point.distance_to(p.global_transform * Vector3(-0.1, 0.01, 0)) < 0.001
	ok = ok and p.maj(rayon.call(true), 0.02) == "a"
	# poignée : visée par un rayon, saisie par un doigt tout proche, ignorée sinon
	var vers := func(x: float, y: float, c: bool) -> Array:
		return [{"id": "droite", "o": p.global_transform * Vector3(x, y, 0.8), "d": -p.global_basis.z, "clic": c, "appui": c, "bout": Vector3.ZERO, "doigt": false}]
	var y_p := -0.0375 - 0.03 - 0.014 - 0.0075
	ok = ok and p.sur_poignee(vers.call(0.0, y_p, false)) == ""         # pas encore de poignée
	p.poignee()
	ok = ok and p.sur_poignee(vers.call(0.0, y_p, false)) == "droite" and p.sur_poignee(vers.call(0.0, 0.0, false)) == ""
	ok = ok and p.sur_poignee([{"id": "gauche", "o": Vector3(0, 0, 40), "d": Vector3(0, 1, 0), "clic": false, "appui": false,
		"bout": p.global_transform * Vector3(0.05, y_p, 0.03), "doigt": true}]) == "gauche"
	# disparition : plus interactif tout de suite ; réapparition : de nouveau
	p.maj([], 0.02)
	p.disparaitre()
	ok = ok and not p.ouvert and p.maj(vers.call(-0.1, 0.0, true), 0.02) == "" and p.survol == "" and p.impacts.is_empty()
	ok = ok and p.sur_poignee(vers.call(0.0, y_p, false)) == ""
	for i in 12:
		p.maj([], 0.02)
	p.apparaitre()
	ok = ok and p.ouvert and p.visible and p.maj(vers.call(-0.1, 0.0, true), 0.02) == "a"
	# caché puis remontré de l'extérieur après une disparition : là d'un coup, comme avant
	p.maj([], 0.02)
	p.disparaitre(0.0)
	p.visible = false
	p.visible = true
	ok = ok and p.ouvert and p.maj(vers.call(-0.1, 0.0, true), 0.02) == "a"
	print("ESSAI PANNEAU ", "OK" if ok else "ÉCHEC")
	p.queue_free()


# ───────── vitrine : les panneaux du jeu, vus de près ─────────

func _face(p: Node3D, c: Vector3) -> void:
	p.global_transform = Transform3D(Basis.IDENTITY, c).looking_at(c + (c - camera.global_position), Vector3.UP)


func _vitrine_prete(police: Font) -> void:
	v_menu = PanneauScript.new(police)
	add_child(v_menu)
	v_menu.fond(Vector2(0.47, 0.43))
	var defs := [["micro", "Micro : activé"], ["visites", "Visites guidées"], ["filtres", "Montrer : le système nerveux"], ["etiquettes", "Noms : affichés"],
		["niveau", "Public : curieux"], ["mixte", "Réalité mixte : non"], ["recentrer", "Recentrer"], ["home", "Revenir au corps"],
		["depart", "Menu de départ"], ["exit", "Quitter (maintenir)"]]
	for i in defs.size():
		v_menu.bouton(defs[i][0], "", Vector2(-0.112 + 0.224 * (i % 2), 0.164 - 0.082 * (i / 2)), Vector2(0.21, 0.07), 1.5 if defs[i][0] == "exit" else 0.0)
		v_menu.libelle(defs[i][0], defs[i][1])
	v_menu.allume("micro", true)
	v_menu.allume("etiquettes", true)
	v_menu.poignee()
	_face(v_menu, camera.global_position + Vector3(-0.17, -0.03, -0.62))
	v_menu.visible = false
	v_barre = PanneauScript.new(police)
	add_child(v_barre)
	v_barre.fond(Vector2(0.66, 0.1))
	v_barre.bouton("prec", "Étape précédente", Vector2(-0.215, 0), Vector2(0.2, 0.07))
	v_barre.bouton("suiv", "Étape suivante", Vector2(0, 0), Vector2(0.2, 0.07))
	v_barre.bouton("quitter", "Quitter la visite", Vector2(0.215, 0), Vector2(0.2, 0.07))
	v_barre.poignee()
	_face(v_barre, camera.global_position + Vector3(0.62, -0.2, -0.9))
	v_barre.visible = false


func _vers(p: PanneauScript, id: String, nom: String, clic_: bool, tenu: bool) -> Dictionary:
	var c := Vector3(0, p._y_poignee(), 0)
	if id != "poignee":
		var b = p._par_id[id]
		c = Vector3(b.centre.x + 0.06, b.centre.y - 0.012, 0)
	var o := camera.global_position + Vector3(0.2 if nom == "droite" else -0.2, -0.3, -0.1)
	return {"id": nom, "o": o, "d": (p.global_transform * c - o).normalized(), "clic": clic_, "appui": tenu, "bout": o, "doigt": false}


func _vitrine(dt: float) -> void:
	for e in [[10, "apparition"], [100, "sombre"], [122, "presse"], [150, "clair"], [165, "disparition"]]:
		if image == e[0]:
			get_viewport().get_texture().get_image().save_png("user://vitrine_%s.png" % e[1])
			print("capture vitrine_", e[1])
	if image < 4:
		dt = 0.0
	if image == 5:
		v_menu.apparaitre()
		v_barre.apparaitre()
	var pm: Array = []
	var pb: Array = []
	if image >= 30 and image < 110:
		pm.append(_vers(v_menu, "filtres", "droite", false, false))
	if image >= 60 and image < 110:
		pm.append(_vers(v_menu, "exit", "gauche", image == 60, true))           # jauge de maintien : 0,87 s sur 1,5 s à la capture
		pb.append(_vers(v_barre, "suiv", "droite", false, false))
	if image >= 110 and image < 130:
		pm.append(_vers(v_menu, "niveau", "droite", image == 118, image >= 118))
		pb.append(_vers(v_barre, "poignee", "gauche", false, false))
	if image == 125:
		v_env.background_color = Color(0.78, 0.76, 0.72)       # comme une pièce claire en réalité mixte
	if image >= 130 and image < 160:
		pm.append(_vers(v_menu, "home", "droite", false, false))
		pm.append(_vers(v_menu, "poignee", "gauche", false, false))
	if image == 160:
		v_menu.disparaitre()
		v_barre.disparaitre()
	if image >= 160:
		pm.append(_vers(v_menu, "home", "droite", image == 161, true))
	var id := v_menu.maj(pm, dt)
	v_barre.maj(pb, dt)
	if image == 118:
		v_ok = v_ok and id == "niveau"
	elif image == 100:
		v_ok = v_ok and id == "" and v_menu.survol == "filtres" and v_menu.impacts.size() == 2 and v_menu.survol_point != Vector3.ZERO
	elif image == 140:
		v_ok = v_ok and v_menu.sur_poignee(pm) == "gauche" and v_menu.survol == "home"
	elif image >= 160:
		v_ok = v_ok and id == "" and not v_menu.ouvert
	else:
		v_ok = v_ok and id == ""
	if image == 190:
		v_ok = v_ok and not v_menu._racine.visible
		print("ESSAI VITRINE ", "OK" if v_ok else "ÉCHEC")
		fini = true
		get_tree().quit(0 if v_ok else 1)
