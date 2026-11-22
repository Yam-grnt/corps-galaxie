extends Node3D
## Essai du menu (menu.gd) sur ordinateur, sans casque :
##   Godot --xr-mode off --path godot res://essai_menu.tscn             → à la souris (clic gauche = gâchette ; F : fond clair ;
##                                                                         O : ouvrir/fermer ; les actions s'affichent dans la console)
##   Godot --xr-mode off --path godot res://essai_menu.tscn -- --photo  → déroule tout seul : vérifie chaque action (rayon, doigt,
##                                                                         maintien de « Quitter »), enregistre des captures menu2_*.png
##                                                                         dans user://, affiche ESSAI MENU OK et quitte
## En mode photo le temps est simulé (pas fixe de 1/60 s).

const MenuScript := preload("res://menu.gd")

const NUIT := Color(0.008, 0.011, 0.026)
const PIECE := Color(0.8, 0.78, 0.74)

var camera: Camera3D
var env: Environment
var menu: MenuScript
var photo := false
var etat := {"micro": false, "visite": "", "filtre": "tout", "etiquettes": false, "niveau": 1, "mixte": false, "tuto": false}
var visites: Array = []
var filtres: Array = []
# pointeur simulé (mode photo)
var cible = null                # Vector3 visé, ou null
var clic := false
var appui := false
var doigt = null                # Vector3 du bout du doigt, ou null
var recus: Array[String] = []
var touches := 0
var ok := true
var souris_avant := false


func _ready() -> void:
	photo = "--photo" in OS.get_cmdline_user_args()
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = NUIT
	we.environment = env
	add_child(we)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 0)
	camera.fov = 50.0 if photo else 60.0
	camera.near = 0.02
	add_child(camera)
	camera.make_current()
	var f := FileAccess.open("res://contenus.json", FileAccess.READ)
	var contenus: Dictionary = JSON.parse_string(f.get_as_text())
	visites = contenus.get("visites", [])
	filtres = contenus.get("filtres", [])
	var police: Font = null
	var base := ThemeDB.fallback_font
	if base is FontFile:
		var p := (base as FontFile).duplicate() as FontFile
		p.multichannel_signed_distance_field = true
		p.msdf_pixel_range = 12
		police = p
	menu = MenuScript.new()
	add_child(menu)
	menu.position = Vector3(0, 1.6, -0.6)
	menu.preparer(police, visites, filtres)
	menu.etat(etat)
	menu.touche.connect(func(_id: String) -> void: touches += 1)
	if photo:
		get_window().size = Vector2i(1100, 1100)
		_photos()
	else:
		menu.ouvrir()


func _pointeurs() -> Array:
	var liste: Array = []
	if photo:
		if cible != null:
			var o := camera.global_position + Vector3(0.12, -0.25, 0)
			liste.append({"id": "right", "o": o, "d": ((cible as Vector3) - o).normalized(), "clic": clic, "appui": appui or clic,
				"bout": o, "doigt": false})
		if doigt != null:
			liste.append({"id": "left", "o": doigt, "d": Vector3(0, -1, 0), "clic": false, "appui": false, "bout": doigt, "doigt": true})
	else:
		var m := get_viewport().get_mouse_position()
		var o := camera.project_ray_origin(m)
		var presse := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		liste.append({"id": "right", "o": o, "d": camera.project_ray_normal(m), "clic": presse and not souris_avant, "appui": presse,
			"bout": o, "doigt": false})
		souris_avant = presse
	return liste


func _process(dt: float) -> void:
	var id := menu.maj(_pointeurs(), 1.0 / 60.0 if photo else dt)
	clic = false
	if id != "":
		recus.append(id)
		if not photo:
			print("action : ", id)
			_simuler(id)


## Ce que main.gd ferait de l'action (assez pour voir les états changer).
func _simuler(id: String) -> void:
	if id.begins_with("f:"):
		etat.filtre = id.substr(2)
	elif id.begins_with("v:"):
		etat.visite = id.substr(2)
	elif id.begins_with("niveau:"):
		etat.niveau = int(id.substr(7))
	match id:
		"micro":
			etat.micro = not etat.micro
		"quitter":
			etat.visite = ""
		"etiquettes":
			etat.etiquettes = not etat.etiquettes
		"niveau":
			etat.niveau = (int(etat.niveau) + 1) % 3
		"mixte":
			etat.mixte = not etat.mixte
			env.background_color = PIECE if etat.mixte else NUIT
		"tuto":
			etat.tuto = not etat.tuto
		"home":
			etat.filtre = "tout"
			etat.visite = ""
		"reduire":
			menu.fermer()
		"exit":
			get_tree().quit()
	menu.etat(etat)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_F:
			env.background_color = PIECE if env.background_color == NUIT else NUIT
		elif ev.keycode == KEY_O:
			if menu.ouvert:
				menu.fermer()
			else:
				menu.ouvrir()
		elif ev.keycode == KEY_ESCAPE:
			get_tree().quit()


# ───────── mode photo ─────────

func _images(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _prendre(nom: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://menu2_%s.png" % nom)


func _verifier(condition: bool, quoi: String) -> void:
	if not condition:
		ok = false
		print("ÉCHEC : ", quoi)


## Vise un élément puis clique ; renvoie l'action reçue ("" si navigation interne).
func _cliquer(id: String, attente := 14) -> String:
	var c := menu.centre_de(id)
	_verifier(c != Vector3.ZERO, "élément introuvable sur la page : " + id)
	cible = c
	await _images(12)
	recus.clear()
	clic = true
	await _images(2)
	appui = false
	await _images(attente)
	return recus[0] if recus.size() > 0 else ""


func _attendu(id: String, attendu: String) -> void:
	var r: String = await _cliquer(id)
	_verifier(r == attendu, "« %s » a renvoyé « %s » au lieu de « %s »" % [id, r, attendu])
	menu.etat(etat)


func _photos() -> void:
	await _images(3)
	# fermé : rien ne se passe
	cible = menu.global_position
	await _images(3)
	_verifier(not menu.survol and not menu.ouvert, "fermé, le menu ne doit pas être survolé")
	cible = null
	# apparition
	menu.ouvrir()
	await _images(7)
	await _prendre("00_apparition")
	await _images(50)
	await _prendre("01_accueil")
	# survol (rayon) : Recentrer
	cible = menu.centre_de("recentrer")
	await _images(14)
	_verifier(menu.survol and menu.survol_id == "recentrer", "survol de Recentrer")
	await _prendre("02_accueil_survol")
	# pressé
	appui = true
	clic = true
	await _images(3)
	await _prendre("03_accueil_presse")
	appui = false
	await _images(10)
	_verifier(recus.has("recentrer"), "Recentrer au rayon")
	# toutes les actions de l'accueil
	await _attendu("home", "home")
	await _attendu("micro", "micro")
	await _attendu("etiquettes", "etiquettes")
	# actif : micro ouvert, noms affichés, un filtre, une visite en cours
	etat.micro = true
	etat.etiquettes = true
	etat.filtre = "squelette"
	etat.visite = "sang"
	menu.etat(etat)
	cible = null
	await _images(30)
	await _prendre("04_accueil_actif")
	await _attendu("vis", "quitter")
	etat.visite = ""
	etat.micro = false
	menu.etat(etat)
	# transition vers « Montrer »
	cible = menu.centre_de("nav:1")
	await _images(12)
	clic = true
	await _images(5)
	await _prendre("05_transition")
	cible = null
	await _images(40)
	_verifier(menu.page == 1, "onglet Montrer")
	await _prendre("06_montrer")
	await _attendu("f:nerfs", "f:nerfs")
	etat.filtre = "nerfs"
	menu.etat(etat)
	cible = menu.centre_de("f:arteres")
	await _images(20)
	await _prendre("07_montrer_survol")
	for f: Dictionary in filtres:
		await _attendu("f:" + str(f.id), "f:" + str(f.id))
	await _tremblements()
	# visites
	await _attendu("nav:2", "")
	cible = null
	await _images(40)
	await _prendre("08_visites")
	await _attendu("v:sommeil", "v:sommeil")
	etat.visite = "sommeil"
	menu.etat(etat)
	cible = menu.centre_de("v:nerfs")
	await _images(25)
	await _prendre("09_visites_en_cours")
	await _attendu("quitter", "quitter")
	await _attendu("pg", "")
	cible = null
	await _images(30)
	await _prendre("10_visites_suite")
	await _attendu("v:echelles", "v:echelles")
	# anti double-déclenchement : 0,3 s après le lancement d'une visite, un clic est ignoré ; après 0,6 s il repasse
	_verifier((await _cliquer("v:defenses", 2)) == "", "un clic 0,3 s après le lancement d'une visite doit être ignoré")
	await _images(30)
	_verifier((await _cliquer("v:defenses")) == "v:defenses", "clic après le délai de 0,6 s")
	await _images(40)
	etat.visite = ""
	menu.etat(etat)
	# réglages
	await _attendu("nav:3", "")
	cible = null
	await _images(40)
	await _prendre("11_reglages")
	await _attendu("niveau:2", "niveau:2")
	etat.niveau = 2
	await _attendu("mixte", "mixte")
	etat.mixte = true
	await _attendu("tuto", "tuto")
	etat.tuto = true
	await _attendu("depart", "depart")
	menu.etat(etat)
	# quitter : relâché trop tôt, rien ; tenu 1,5 s, l'action part
	cible = menu.centre_de("exit")
	await _images(30)
	recus.clear()
	clic = true
	appui = true
	await _images(48)
	await _prendre("12_reglages_jauge")
	appui = false
	await _images(20)
	_verifier(recus.is_empty(), "Quitter relâché à 0,8 s ne doit rien déclencher")
	clic = true
	appui = true
	await _images(80)
	_verifier(recus.is_empty(), "Quitter ne doit pas partir avant 1,5 s")
	await _images(14)
	_verifier(recus == ["exit"], "Quitter tenu 1,5 s : reçu %s" % str(recus))
	appui = false
	# fond clair (réalité mixte)
	env.background_color = PIECE
	cible = null
	await _images(20)
	await _prendre("13_reglages_fond_clair")
	await _attendu("nav:1", "")
	cible = null
	await _images(40)
	await _prendre("14_montrer_fond_clair")
	await _attendu("nav:0", "")
	etat.micro = true
	menu.etat(etat)
	cible = null
	await _images(40)
	await _prendre("15_accueil_fond_clair")
	env.background_color = NUIT
	etat.micro = false
	etat.mixte = false
	etat.tuto = false
	etat.niveau = 1
	etat.filtre = "tout"
	menu.etat(etat)
	# au doigt : par l'avant on appuie (une seule fois), par l'arrière rien
	var c := menu.centre_de("recentrer")
	recus.clear()
	for i in 20:
		doigt = c + Vector3(0, 0, 0.06 - 0.004 * i)
		await _images(1)
		if i == 12:
			await _prendre("16_doigt")
	await _images(4)
	_verifier(recus == ["recentrer"], "appui au doigt : reçu %s" % str(recus))
	for i in 20:
		doigt = c + Vector3(0, 0, -0.02 + 0.004 * i)
		await _images(1)
	recus.clear()
	doigt = c + Vector3(0, 0, -0.2)
	await _images(3)
	for i in 30:
		doigt = c + Vector3(0, 0, -0.2 + 0.008 * i)
		await _images(1)
	_verifier(recus.is_empty(), "un doigt venu de l'arrière ne doit rien déclencher")
	doigt = null
	# poignée
	cible = menu.global_transform * Vector3(0, MenuScript.Y_POIGNEE, 0)
	await _images(12)
	_verifier(menu.sur_poignee(_pointeurs()) == "right", "poignée visée au rayon")
	await _prendre("17_poignee")
	cible = null
	# vu comme dans le casque : 30° à gauche, 22° sous les yeux, à 0,5 m ; puis au rayon à 1 m
	get_window().size = Vector2i(1280, 800)
	camera.fov = 75.0
	var dir := Vector3(0, 0, -1).rotated(Vector3.UP, 0.524)
	var pos := Vector3(dir.x * 0.5, 1.6 - 0.2, dir.z * 0.5)
	menu.global_transform = Transform3D(Basis.IDENTITY, pos).looking_at(pos + (pos - camera.position), Vector3.UP)
	camera.rotation = Vector3(deg_to_rad(-12.0), deg_to_rad(14.0), 0)
	await _images(10)
	await _prendre("18_en_situation")
	camera.rotation = Vector3.ZERO
	menu.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.6, -1.0))
	await _attendu("nav:1", "")
	cible = menu.centre_de("f:squelette")
	await _images(30)
	await _prendre("19_a_un_metre")
	_verifier((await _cliquer("f:squelette")) == "f:squelette", "clic au rayon à 1 m")
	# fermeture : « Fermer » renvoie reduire ; une fois fermé, plus rien
	_verifier((await _cliquer("reduire")) == "reduire", "Fermer")
	menu.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.6, -0.6))
	camera.fov = 50.0
	get_window().size = Vector2i(1100, 1100)
	await _attendu("nav:2", "")
	# zone agrandie : viser le titre, ou le coin haut droit, allume « Fermer » ; cliquer ferme
	for pt: Vector2 in [Vector2(-0.15, 0.2), Vector2(0.224, 0.25), Vector2(0.1, 0.188)]:
		cible = menu.global_transform * Vector3(pt.x, pt.y, 0)
		await _images(14)
		_verifier(menu.survol_id == "reduire", "l'en-tête entier doit viser Fermer (%s)" % str(pt))
		if pt.x < 0.0:
			await _prendre("21_fermer_par_le_titre")
		recus.clear()
		clic = true
		await _images(6)
		_verifier(recus == ["reduire"], "clic dans l'en-tête : reçu %s" % str(recus))
	# et la première carte de visite est à plus de 2 cm de cette zone
	var haut_carte: float = (menu.global_transform.affine_inverse() * menu.centre_de("v:sommeil")).y + 0.029
	_verifier(0.185 - haut_carte >= 0.02, "une visite à moins de 2 cm de la zone Fermer")
	# main qui tremble en voulant fermer : le rayon glisse de 3 cm vers une visite pendant le pincement → on ferme
	cible = menu.global_transform * Vector3(0.166, 0.2, 0)
	await _images(20)
	for i in 6:
		cible = menu.global_transform * Vector3(0.166, 0.2 - 0.005 * (i + 1), 0)
		await _images(1)
	recus.clear()
	clic = true
	await _images(6)
	_verifier(recus == ["reduire"], "Fermer puis dérive de 3 cm vers une visite : reçu %s" % str(recus))
	# la poignée, elle, ne ferme pas
	cible = menu.global_transform * Vector3(0, MenuScript.Y_POIGNEE, 0)
	await _images(14)
	recus.clear()
	clic = true
	await _images(6)
	_verifier(recus.is_empty(), "un clic sur la poignée ne doit rien déclencher")
	menu.fermer()
	await _images(4)
	await _prendre("20_disparition")
	await _images(30)
	recus.clear()
	clic = true
	await _images(4)
	_verifier(recus.is_empty() and not menu.survol and not menu.ouvert, "fermé, le menu ne répond plus")
	_verifier(touches > 10, "le signal touche doit avoir été émis")
	print("ESSAI MENU ", "OK" if ok else "ÉCHEC")
	get_tree().quit()


## Clic fiable au rayon (page Montrer) : dérive pendant le pincement, tremblement à la frontière de deux tuiles.
func _tremblements() -> void:
	var a := menu.centre_de("f:sang")
	var b := menu.centre_de("f:nerfs")
	var bord := (a + b) * 0.5
	var x := (b - a).normalized()
	# 1. le rayon dérive de 3 cm (jusque dans la tuile voisine) juste avant le clic : la tuile de départ gagne
	cible = bord - x * 0.013
	await _images(20)
	for i in 6:
		cible = bord - x * 0.013 + x * 0.005 * (i + 1)
		await _images(1)
	_verifier(menu.survol_id == "f:nerfs", "après 3 cm de dérive le rayon doit être sur la tuile voisine (%s)" % menu.survol_id)
	recus.clear()
	clic = true
	await _images(8)
	_verifier(recus == ["f:sang"], "dérive de 3 cm pendant le pincement : reçu %s" % str(recus))
	# 2. pincement tenu : la cible est figée au début du pincement, même si le rayon part chez la voisine 0,3 s
	cible = menu.centre_de("f:squelette")
	await _images(20)
	appui = true
	for i in 20:
		cible = menu.centre_de("f:squelette").lerp(menu.centre_de("f:muscles"), (i + 1) / 20.0)
		await _images(1)
	recus.clear()
	clic = true
	await _images(2)
	appui = false
	await _images(8)
	_verifier(recus == ["f:squelette"], "cible figée au début du pincement : reçu %s" % str(recus))
	# 3. tremblement de ±6 mm à cheval sur la frontière : la cible ne change pas
	cible = a
	await _images(20)
	var stable := true
	for i in 40:
		cible = bord + x * (0.006 if i % 2 == 0 else -0.006)
		await _images(1)
		stable = stable and menu.survol_id == "f:sang"
		if i == 20:
			await _prendre("22_tremblement_frontiere")
	_verifier(stable, "un tremblement à la frontière ne doit pas changer de cible")
	recus.clear()
	clic = true
	await _images(8)
	_verifier(recus == ["f:sang"], "clic pendant le tremblement : reçu %s" % str(recus))
	# 4. clic à la volée : un élément survolé depuis moins de 0,15 s, sans autre candidat, n'est pas activé
	cible = null
	await _images(40)
	cible = menu.centre_de("f:peau")
	await _images(3)
	recus.clear()
	clic = true
	await _images(8)
	_verifier(recus.is_empty(), "clic à la volée (0,05 s de survol) : reçu %s" % str(recus))
	cible = null
	await _images(10)
