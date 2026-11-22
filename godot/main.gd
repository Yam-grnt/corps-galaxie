extends Node3D
## Le corps galaxie v2 — application native de réalité virtuelle (Godot 4.4, OpenXR).
##
## Le modèle (modele.bin + modele.json) est un arbre de nuages de points : chaque nœud est un nuage dont certains
## points s'ouvrent sur un autre nœud (organe → tissu → cellule → … → quark).
## Ce script : charge le modèle, choisit à chaque instant quels nuages afficher et avec quel détail, lit les mains et
## les manettes (viser et cliquer pour choisir, saisir pour déplacer, deux mains pour zoomer et tourner), gère l'entrée
## dans les niveaux, le voyage guidé, les visites narrées, les filtres, les étiquettes, les panneaux et le guide.
##
## Rien ici n'est propre à un fabricant de casque : tout passe par OpenXR (voir _session et _mixte).

# Rendu : toutes les mesures « en pixels » sont des angles, comptés en pixels d'un œil de casque de référence
# (1760 px pour 96°, soit F_REF pixels par radian). points.gdshader applique les mêmes règles avec les mêmes valeurs.
const F_REF := 792.0
const OPEN := 24.0          # rayon apparent pondéré par le regard à partir duquel un grain-enfant se déploie en nuage
const FONDU_OUV := 1.6      # le nuage de l'enfant est entièrement là à OPEN × FONDU_OUV (fondu croisé avec son grain)
const DENS := 2.0           # points révélés : DENS × rayon apparent^1,5 (24 px : 240 points, assez pour une forme ; 570 px : 27 000)
const AMAS := 0.2           # grains d'amas par pixel² de rayon apparent d'un enfant pas encore déployé
const G_AMAS := [3, 6, 12, 24, 48]  # tailles d'amas disponibles (grains par enfant)
const REGARD_MIN := 0.45    # poids de ce qui est loin du centre du regard : on déploie d'abord ce qu'on regarde
const REGARD_0 := 0.24      # (radians) plein poids jusqu'à 14° du centre
const REGARD_1 := 0.79      # (radians) poids minimal au-delà de 45°
const PART_NUAGES := 0.65   # part du budget de points réservée aux nuages ; le reste va aux amas
const ETALEMENT := 0.35     # un amas encore petit s'étale sur cette fraction de l'espace entre voisins (au plus 2,5 rayons)
const DENS_MIN := 0.3       # quand le budget manque, les nuages s'allègent jusqu'à cette fraction de DENS avant de se refermer
const POIDS_MODE := [0.6, 1.0, 0.6, 0.25]      # priorité : chemin vers l'objet courant, objet courant, voisins, voisins de voisins
const DENS_VOISINS := 0.4   # hors de l'objet où l'on se trouve, les nuages se contentent de cette fraction de la densité
const PART_AMAS_VOISINS := 0.2      # part du budget que les amas du voisinage ne dépassent pas
const AMAS_VOISINS := 2     # hors de l'objet où l'on se trouve, les amas se limitent aux AMAS_VOISINS premières tailles de G_AMAS
const RETRAIT := 0.33       # lumière qui reste au voisinage d'un objet qu'on vient de présenter (voyage, étape de visite)
const RETRAIT_LIBRE := 0.55 # lumière qui reste au voisinage de l'objet où l'on se trouve, quand on explore à la main
const MAX_AMAS_GARDES := 1500000    # grains d'amas gardés en mémoire (environ 60 Mo) ; au-delà, les plus anciens sont libérés
const MAX_OBJETS := 500
const NB_BILLES := 150
const MAX_POINTS := 340000  # plafond ; le budget réel s'adapte à la fréquence d'images
const MIN_POINTS := 90000
const ENTREE := 0.15        # on entre dans un enfant dès que son rayon dépasse 15 cm autour du point manipulé
const NIVEAUX := ["simple", "standard", "approfondi"]
const NOMS_NIVEAUX := ["Enfant", "Curieux", "Scientifique"]
const TAILLE_CORPS := 0.902   # mètres par unité du modèle : le corps mesure 1,75 m, à l'échelle 1:1
const CLAIR := Color(0.925, 0.91, 0.875)
const GRIS := Color(0.6, 0.6, 0.62)
const OR := Color(1, 0.85, 0.3)
const MAIN_OR := Color(0.42, 0.35, 0.12)      # mains et rayons : discrets, pour ne pas éclipser le corps
const MAIN_BLEU := Color(0.13, 0.24, 0.3)
const FOND := Color(0.02, 0.024, 0.04, 0.88)

# Ce que dit le guide en dehors des fiches (chaque phrase a son enregistrement : voix/clips/p_<clé>.wav).
const PHRASES := {
	"accueil": "Voici ton corps galaxie, à taille réelle. Vise un élément et clique pour que je te l'amène. Saisis-le pour le tourner, écarte les deux mains pour l'agrandir.",
	"micro": "Je t'écoute. Dis par exemple : montre-moi un neurone.",
	"micro_coupe": "Micro coupé.",
	"micro_refuse": "Je n'ai pas accès au micro. Tu peux l'autoriser dans les réglages du casque, ou utiliser les boutons.",
	"micro_absent": "La reconnaissance vocale n'est pas disponible sur cet appareil. Utilise les boutons du menu.",
	"emmene": "Je t'y emmène.",
	"absent": "Ça, ce n'est pas dans le corps galaxie. Le modèle contient les organes, le squelette, les muscles, les vaisseaux et les nerfs, puis leurs tissus, leurs cellules, l'ADN, les protéines, les molécules et les atomes.",
	"libre": "Je ne sais répondre qu'à propos de ce que contient le modèle. Dis-moi ce que tu veux voir.",
	"proposer": "Veux-tu que je t'y emmène ?",
	"refus": "D'accord, on reste ici.",
	"retour": "Retour au corps entier.",
	"remonter": "On remonte d'un niveau.",
	"deja_haut": "Tu es déjà au niveau du corps entier.",
	"niveau_0": "D'accord, je t'explique plus simplement.",
	"niveau_1": "D'accord, je reviens à l'explication standard.",
	"niveau_2": "D'accord, je vais plus loin.",
	"niveau_max": "C'est déjà l'explication la plus détaillée dont je dispose.",
	"niveau_min": "C'est déjà mon explication la plus simple.",
	"visite": "C'est parti pour la visite.",
	"visite_fin": "La visite est terminée. Tu peux explorer librement.",
	"visite_choix": "Quelle visite veux-tu ? Choisis dans la liste.",
	"aide": "Tu peux me demander de te montrer une chose, par exemple un neurone, le cœur ou l'ADN. Tu peux dire : c'est quoi, plus simple, plus de détails, remonte, reviens au corps, recentre, montre le sang, ou lance la visite.",
	"recentre": "Voilà, tout est replacé devant toi.",
	"tuto_0": "Vise un organe avec ta main ou ta manette. Un anneau l'entoure. Clique : gâchette de l'index, ou pince brièvement le pouce et l'index.",
	"tuto_1": "Maintenant, saisis-le. Garde les doigts pincés, ou serre la gâchette du majeur, puis bouge la main pour le déplacer et le tourner.",
	"tuto_2": "Saisis-le à deux mains et écarte-les pour l'agrandir. Rapproche-les pour le réduire. Chaque point s'ouvre quand il grandit.",
	"tuto_3": "Perdu ? Clique sur le joystick, ou regarde ta paume ouverte et touche Recentrer : tout revient devant toi. Essaie.",
	"tuto_4": "Tu peux aussi me parler. Appuie sur A, ou touche Parler dans ta paume, puis demande : montre-moi le cœur.",
	"tuto_5": "Regarde ta paume ouverte : tes commandes y sont, à toucher de l'autre main. Tu peux saisir la carte de texte pour la poser où tu veux. Bon voyage.",
	"etiquettes_oui": "J'affiche les noms.",
	"etiquettes_non": "Je cache les noms.",
	"mixte_absent": "La réalité mixte n'est pas disponible sur ce casque.",
}

class Noeud:
	var nom: String
	var desc: String
	var cat: String
	var couleur: Color
	var taille: float            # taille réelle, en mètres
	var echelle: int             # 0 corps et organes, 1 tissus et cellules, 2 organites et protéines, 3 molécules et atomes, 4 noyaux et quarks
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
	var lod_mesh: Array = []        # maillages : d'abord les niveaux de détail, puis les amas (quartier × taille d'amas)
	var ki: PackedInt32Array        # indice du point de chaque enfant
	var prep := {}                  # tableaux de maillage préparés par le fil de calcul, en attente d'être envoyés à la carte
	var quartiers = null            # enfants par quartier : [[centre, rayon, rayon d'enfant typique, [enfants], plus gros rayon], …]
	var etal: PackedFloat32Array    # étalement de l'amas de chaque enfant (territoire de l'enfant / son rayon)
	var ech_p: PackedVector3Array   # échantillon de la forme du nœud (ses premiers points), pour dessiner ses amas
	var ech_c: PackedColorArray
	var sys := -1                   # système du corps (squelette, artères, nerfs…), −1 pour les niveaux génériques
	var ks: PackedInt32Array        # système de chaque enfant
	var sp_off := -1                # [système, phase] de chaque point, si le modèle les fournit
	var vie := 0                    # mouvement propre (voir points.gdshader)
	var fx: Array = []              # effet de la visite guidée : [mode, cycles par seconde, nombre d'onde, direction]
	var lueur := 1.0

var bin: PackedByteArray
var noeuds: Array[Noeud] = []
var rots: Array[Basis] = []
var racine := 0
var racines := {}                       # {"homme": indice, "femme": indice}
var corps := "femme"
var shader: Shader
var mats: Array[ShaderMaterial] = []    # tous les matériaux créés (un par objet affiché), pour leur passer filtre et projecteur
var cases_cle: PackedInt64Array         # ce que montre chaque objet de la réserve : nœud × 100000 + maillage (−1 : rien encore)
var cases_ouv: PackedVector3Array       # ses deux seuils d'ouverture (pour ses enfants, pour lui-même) et sa densité
var amas_vus := {}                      # maillages d'amas en mémoire : nœud × 100000 + maillage → dernier tour où il a servi
var amas_pts := 0
var tour_amas := 0
var parent_de: Array[Vector2i] = []     # pour chaque nœud : (parent, indice de l'enfant dans ce parent), ou (-1, -1)
var contenus := {}                      # textes validés par le comité scientifique (contenus.json)

# État : pile des niveaux traversés, et placement du niveau courant dans la pièce.
# Un point local x du niveau courant se trouve dans la pièce à : w_p + w_s * (w_a * x)
var chemin: Array = []              # [{n, k}] : nœud et indice d'enfant dans son parent
var w_p := Vector3(0, 1.15, -0.95)
var w_a := Basis.IDENTITY
var w_s := 0.55

# Pointeurs (un par main ou manette) : {id, o, d, clic, appui, bout, doigt}. Élément visé, filtres, étiquettes.
var pointeurs: Array = []
var viseurs := {}                   # manettes : pose de visée
var t_pince := {}                   # mains : début et point de départ du pincement en cours
var gachette := {"left": false, "right": false}
var clic_monde := ""                # main ou manette qui vient de cliquer hors des panneaux
var sur_panneau := false
var vise := -1                      # indice de l'enfant visé dans le niveau courant
var halo: MeshInstance3D
var nom_vise: Label3D
var etiquettes := false
var labels: Array[Label3D] = []
var t_labels := 0.0
var filtre := "tout"
var masque := 0
var flux := 0.0
var foyer_lum := Vector4.ZERO       # projecteur : (centre, rayon) dans la pièce
var mode := "jeu"                   # "intro" pendant l'introduction et le menu de départ
var intro: Node3D
var sous_menu := ""                 # "", "visites" ou "filtres"
var p_visites: Node3D
var p_filtres: Node3D
var p_visite: Node3D                # barre de la visite en cours : précédente, suivante, quitter
var angle_but = null                # orientation demandée à l'arrivée d'un voyage (degrés), ou null

var origine: XROrigin3D
var camera: XRCamera3D
var manettes := {}
var monde: Node3D
var reserve: Array[MeshInstance3D] = []
var x_liste := Transform3D.IDENTITY     # repère de la liste affichée → repère du niveau courant
var x_calcul := Transform3D.IDENTITY    # idem pour la liste en cours de calcul
var fil: Thread
var resultat: Array = []
var cle_calcul := ""
var en_vr := false
var actif := true                   # faux quand le casque est retiré ou que le menu système est ouvert
var place := false                  # les panneaux ont été placés à partir d'une vraie position de tête
var mains: Array = []
var prec = null
var pince := {"left": false, "right": false}
var q_lisse := {}
var mm_mains: MultiMesh
var nb_points := 0
var t_calcul := 0.0                 # plus longue durée du choix des nuages (ms), pour le banc d'essai
var t_appliquer := 0.0
var t_appliquer_somme := 0.0
var nb_appliquer := 0
var ouv_aff := OPEN                 # plus haut seuil d'ouverture et densité de la liste affichée (pour le banc d'essai)
var dens_aff := DENS
var budget := 260000.0
var ips := 72.0
var cible_ips := 72.0
var t_lent := 0.0
var t_rapide := 0.0
var essai := false
var police: Font

# Panneaux
var carte: Node3D
var carte_titre: Label3D
var carte_cat: Label3D
var carte_texte: Label3D
var carte_lieu: Label3D
var carte_note: Label3D
var carte_guide: Label3D
var menu: Node3D
var cle_carte := ""
var ancre_tete := Vector3.ZERO
var ancre_avant := Vector3(0, 0, -1)

# Guide, voix, sons
var guide: Guide
var voix: Node
var api: Node                       # mode en ligne (questions libres), inactif tant qu'aucun relais n'est configuré
var sons: Node
var niveau := 1
var proposition := -1               # nœud proposé par le guide, en attente d'un « oui »
var t_proposition := 0.0
var dire_a_l_arrivee := false
var ligne_guide := ""
var mixte := false
var reglages := {}

# Voyage guidé et visite
var voy = null                      # {route: [{n, k}], foyer: Vector3, taille: float}
var visite = null                   # {v, i, t, arrive} : visite n° v, étape i
var couche := 0.0                   # 0 debout, 1 allongé (visite du sommeil)
var couche_cible := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	essai = "--essai" in args
	_charger()
	_lire_reglages()
	_choisir_corps(str(reglages.get("corps", "femme")))
	if "--exporter-textes" in args:
		_exporter_textes()
		get_tree().quit()
		return
	_scene()
	voix = preload("res://voix.gd").new()
	add_child(voix)
	voix.entendu.connect(_entendu)
	voix.partiel.connect(func(t: String) -> void:
		_ligne("…" + t)
		t_partiel = 0.0)
	voix.etat.connect(_etat_voix)
	sons = preload("res://sons.gd").new()
	add_child(sons)
	voix.parole.connect(func(p: bool) -> void: sons.baisser(p))
	api = preload("res://guide_api.gd").new()
	add_child(api)
	api.adresse = str(reglages.get("relais", ""))
	api.temps.connect(_temps_recu)
	api.fini.connect(_parcours_fini)
	# essai sur ordinateur du guide en ligne : GALAXIE_RELAIS=adresse du relais, GALAXIE_QUESTION=phrase à lui dire
	if OS.get_environment("GALAXIE_RELAIS") != "":
		api.adresse = OS.get_environment("GALAXIE_RELAIS")
		mode_guide = "incarne"
		reglages["tuto_vu"] = true
	api.mode = mode_guide
	api.nom = nom_guide
	api.tutoiement = tutoiement
	api.echec.connect(func(_raison: String) -> void:
		attente_api = false
		parcours_file.clear()
		temps_en_cours = null
		if evenement_envoye == "":
			_dire(["p_libre"], PHRASES.libre)
		elif evenement_envoye == "arrivee":
			_decrire()
		evenement_envoye = "")
	var xr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr and xr.is_initialized():
		en_vr = true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		_session(xr)
	else:
		camera.position = Vector3(0, 1.6, 0)
	_placer_devant()
	if essai:
		_essai()
		return
	_maj_boutons()
	if not en_vr:
		place = true
		_ouvrir_intro("--sans-intro" in args or "--photo" in args or _arg_etude(args) != "")
		if "--photo" in args:
			_fin_intro({"corps": corps, "niveau": niveau})
		if _arg_etude(args) != "":
			_etude_debut(_arg_etude(args))


## Change de corps (féminin ou masculin) : les chemins et le vocabulaire du guide en dépendent.
func _choisir_corps(c: String) -> void:
	corps = c if racines.has(c) else corps
	racine = int(racines.get(corps, racine))
	_routes()
	guide = Guide.new(_noms(), _atteignables())
	guide.niveau = niveau
	chemin = [{"n": racine, "k": -1}]


# ───────── session OpenXR : identique sur tous les casques ─────────

func _session(xr: OpenXRInterface) -> void:
	xr.session_begun.connect(func() -> void:
		var f: Array = xr.get_available_display_refresh_rates()
		if 90.0 in f:
			xr.display_refresh_rate = 90.0
		cible_ips = xr.display_refresh_rate if xr.display_refresh_rate > 0.0 else 72.0
		if mixte:
			_mixte(true))
	# casque retiré ou menu système ouvert : on se tait, on ne lit plus les mains, on ne calcule plus
	xr.session_visible.connect(func() -> void: _activer(false))
	xr.session_focussed.connect(func() -> void: _activer(true))
	xr.session_stopping.connect(func() -> void: _activer(false))
	xr.pose_recentered.connect(func() -> void: _recentrer())


func _activer(oui: bool) -> void:
	if actif == oui:
		return
	actif = oui
	prec = null
	t_pince.clear()
	voix.suspendre(not oui)
	sons.suspendre(not oui)
	mm_mains.visible_instance_count = 0


## Réalité mixte : le corps apparaît dans la pièce. On passe par le mode de fusion OpenXR, pas par une API de fabricant.
func _mixte(oui: bool) -> bool:
	var xr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr == null or not en_vr:
		return false
	var modes: Array = xr.get_supported_environment_blend_modes()
	if oui and XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
		get_viewport().transparent_bg = true
		xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
		return true
	get_viewport().transparent_bg = false
	xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
	return not oui


# ───────── chargement ─────────

## Lecture du modèle : positions et couleurs restent dans le tampon binaire, on n'en fait des maillages qu'à la demande.
func _charger() -> void:
	bin = FileAccess.get_file_as_bytes("res://modele.bin")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://modele.json"))
	shader = load("res://points.gdshader")
	if FileAccess.file_exists("res://contenus.json"):
		var c = JSON.parse_string(FileAccess.get_file_as_string("res://contenus.json"))
		if c is Dictionary:
			contenus = c
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
		nd.taille = float(m.get("taille", 0.0))
		nd.echelle = 0 if nd.taille >= 1e-2 else (1 if nd.taille >= 3e-6 else (2 if nd.taille >= 3e-9 else (3 if nd.taille >= 1e-12 else 4)))
		nd.n = int(m.n)
		nd.ns = int(m.ns)
		nd.max_r = m.max_r
		nd.min_r = m.min_r
		nd.nk = int(m.nk)
		nd.pos_off = int(m.pos)
		nd.att_off = int(m.att)
		nd.sys = int(m.get("sys", -1))
		nd.sp_off = int(m.get("sp", -1))
		var kf := bin.slice(int(m.kp), int(m.kp) + nd.nk * 12).to_float32_array()
		nd.kp.resize(nd.nk)
		for k in nd.nk:
			nd.kp[k] = Vector3(kf[3 * k], kf[3 * k + 1], kf[3 * k + 2])
		nd.kr = bin.slice(int(m.kr), int(m.kr) + nd.nk * 4).to_float32_array()
		nd.kk = bin.slice(int(m.kk), int(m.kk) + nd.nk * 4).to_int32_array()
		nd.ko = bin.slice(int(m.ko), int(m.ko) + nd.nk * 4).to_int32_array()
		if m.has("ks"):
			nd.ks = bin.slice(int(m.ks), int(m.ks) + nd.nk * 4).to_int32_array()
		if m.has("ki"):
			nd.ki = bin.slice(int(m.ki), int(m.ki) + nd.nk * 4).to_int32_array()
		var c := nd.n
		while true:
			nd.lod_n.append(c)
			nd.lod_mesh.append(null)
			if c <= 96:
				break
			c = c / 2
		# ce qui vit : le cœur bat, les poumons respirent, les molécules et les atomes tremblent (agitation thermique)
		if nd.nom == "Cœur":
			nd.vie = 1
		elif nd.nom == "Poumon" or nd.nom == "Diaphragme":
			nd.vie = 2
		elif nd.echelle == 3:
			nd.vie = 3
		noeuds.append(nd)
	racine = int(meta.racine)
	if meta.get("racines") is Dictionary:
		for c: String in meta.racines:
			racines[c] = int(meta.racines[c])
	else:
		racines = {"femme": racine, "homme": racine}


## Identifiant stable d'un texte, tiré du nom de l'objet (sert de nom de fichier à l'enregistrement de la voix).
static func cle_de(nom: String) -> String:
	var s := nom.to_lower()
	var de := "àâäéèêëîïôöùûüçœæ₂"
	var vers := ["a", "a", "a", "e", "e", "e", "e", "i", "i", "o", "o", "u", "u", "u", "c", "oe", "ae", "2"]
	for i in de.length():
		s = s.replace(de[i], vers[i])
	var r := ""
	for i in s.length():
		var ch := s[i]
		r += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	while r.contains("__"):
		r = r.replace("__", "_")
	return r.trim_prefix("_").trim_suffix("_")


## Indice d'un objet d'après son nom. Deux objets peuvent porter le même nom (les deux corps) : on préfère celui qu'on peut atteindre.
func _indice(nom: String) -> int:
	var premier := -1
	for i in noeuds.size():
		if noeuds[i].nom == nom:
			if i == racine or (parent_de.size() > i and parent_de[i].x >= 0):
				return i
			if premier < 0:
				premier = i
	return premier


func _noms() -> PackedStringArray:
	var v := PackedStringArray()
	for nd in noeuds:
		v.append(nd.nom)
	return v


func _atteignables() -> PackedByteArray:
	var v := PackedByteArray()
	v.resize(noeuds.size())
	for i in noeuds.size():
		v[i] = 1 if (i == racine or parent_de[i].x >= 0) else 0
	return v


## Pour chaque nœud, le chemin le plus naturel depuis le corps. Premier passage sans les raccourcis trompeurs
## (l'ADN d'une bactérie ou d'une mitochondrie), pour que l'ADN se visite dans le noyau d'une cellule humaine.
func _routes() -> void:
	parent_de.resize(noeuds.size())
	parent_de.fill(Vector2i(-1, -1))
	var vu := PackedByteArray()
	vu.resize(noeuds.size())
	vu[racine] = 1
	var bact := _indice("Bactérie intestinale")
	var mito := _indice("Mitochondrie")
	var adn := _indice("ADN")
	var nucleole := _indice("Nucléole")
	for strict: bool in [true, false]:
		var file: Array[int] = []
		for i in noeuds.size():
			if vu[i]:
				file.append(i)
		var tete := 0
		while tete < file.size():
			var ni := file[tete]
			tete += 1
			var nd := noeuds[ni]
			for k in nd.nk:
				var c := nd.kk[k]
				if vu[c]:
					continue
				if strict and (c == bact or ni == bact or (ni == mito and c == adn) or ni == nucleole):
					continue
				vu[c] = 1
				parent_de[c] = Vector2i(ni, k)
				file.append(c)


func _route_vers(cible: int) -> Array:
	var r: Array = []
	var n := cible
	while n != racine and parent_de[n].x >= 0:
		r.push_front({"n": n, "k": parent_de[n].y})
		n = parent_de[n].x
	return r


## Maillage n° `lod` d'un nœud. Les premiers numéros sont les niveaux de détail : les `c` premiers points du nœud (ils
## sont mélangés, donc tout préfixe est représentatif). Les suivants sont les amas (voir _preparer_amas).
## Les tableaux sont le plus souvent déjà prêts : le fil de calcul les a préparés (nd.prep), il ne reste qu'à les envoyer.
func _maillage(nd: Noeud, lod: int) -> ArrayMesh:
	if nd.lod_mesh.size() <= lod:
		nd.lod_mesh.resize(lod + 1)
	if nd.lod_mesh[lod] != null:
		return nd.lod_mesh[lod]
	var p: Array = nd.prep[lod] if nd.prep.has(lod) else _preparer(nd, lod)
	nd.prep.erase(lod)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, p[0], [], {},
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RG_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT))
	m.custom_aabb = p[1]
	nd.lod_mesh[lod] = m
	return m


## Tableaux d'un maillage : [tableaux, boîte englobante, nombre de points du niveau de détail]. Appelé depuis le fil de calcul.
func _preparer(nd: Noeud, lod: int) -> Array:
	var nl := nd.lod_n.size()
	if lod >= nl:
		return _preparer_amas(nd, (lod - nl) / G_AMAS.size(), G_AMAS[(lod - nl) % G_AMAS.size()])
	var c := nd.lod_n[lod]
	var pf := bin.slice(nd.pos_off, nd.pos_off + c * 12).to_float32_array()
	var pv := PackedVector3Array()
	pv.resize(c)
	for i in c:
		pv[i] = Vector3(pf[3 * i], pf[3 * i + 1], pf[3 * i + 2])
	var sp: PackedFloat32Array
	if nd.sp_off >= 0:
		sp = bin.slice(nd.sp_off, nd.sp_off + c * 8).to_float32_array()
	else:
		sp.resize(c * 2)
		for i in c:
			sp[2 * i] = float(nd.sys)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pv
	arr[Mesh.ARRAY_CUSTOM0] = bin.slice(nd.att_off, nd.att_off + c * 16).to_float32_array()
	arr[Mesh.ARRAY_CUSTOM1] = sp
	arr[Mesh.ARRAY_CUSTOM2] = pf      # un grain-enfant est son propre centre
	return [arr, AABB(Vector3(-1.3, -1.3, -1.3), Vector3(2.6, 2.6, 2.6)), c]


## Échantillon de la forme d'un nœud : quelques dizaines de ses points, de quoi l'esquisser quand il n'est encore qu'un amas.
func _echantillon(nd: Noeud) -> void:
	if not nd.ech_p.is_empty():
		return
	var dep := nd.ns if nd.n - nd.ns >= 16 else 0
	var nb := mini(96, nd.n - dep)
	var pf := bin.slice(nd.pos_off + dep * 12, nd.pos_off + (dep + nb) * 12).to_float32_array()
	var cf := bin.slice(nd.att_off + dep * 16, nd.att_off + (dep + nb) * 16).to_float32_array()
	var ep := PackedVector3Array()
	var ec := PackedColorArray()
	ep.resize(nb)
	ec.resize(nb)
	for i in nb:
		ep[i] = Vector3(pf[3 * i], pf[3 * i + 1], pf[3 * i + 2])
		ec[i] = Color(minf(cf[4 * i], 1.0), minf(cf[4 * i + 1], 1.0), minf(cf[4 * i + 2], 1.0))
	nd.ech_c = ec
	nd.ech_p = ep


## Découpe les enfants d'un nœud en quartiers (environ 250 enfants chacun) et mesure, pour chaque enfant, la place dont
## il dispose parmi ses voisins : c'est sur ce territoire que son amas s'étale tant qu'il est petit.
func _quartiers(nd: Noeud) -> void:
	var mn := nd.kp[0]
	var mx := nd.kp[0]
	for k in nd.nk:
		mn = mn.min(nd.kp[k])
		mx = mx.max(nd.kp[k])
	var r_med := nd.kr[nd.nk / 2]
	var ext := (mx - mn).max(Vector3.ONE * r_med * 4.0)
	var vol := ext.x * ext.y * ext.z
	var hs := pow(vol * 4.0 / nd.nk, 1.0 / 3.0)
	var hq := pow(vol * 250.0 / nd.nk, 1.0 / 3.0)
	var compte := {}
	var cases := {}
	for k in nd.nk:
		var c := Vector3i(((nd.kp[k] - mn) / hs).floor())
		compte[c] = int(compte.get(c, 0)) + 1
		var q := Vector3i(((nd.kp[k] - mn) / hq).floor())
		if not cases.has(q):
			cases[q] = []
		(cases[q] as Array).append(k)
	var et := PackedFloat32Array()
	et.resize(nd.nk)
	for k in nd.nk:
		var c := Vector3i(((nd.kp[k] - mn) / hs).floor())
		et[k] = clampf(ETALEMENT * hs / pow(float(compte[c]), 1.0 / 3.0) / nd.kr[k], 1.0, 2.5)
	nd.etal = et
	var qs: Array = []
	for q: Vector3i in cases:
		var ks: Array = cases[q]
		var centre := Vector3.ZERO
		for k: int in ks:
			centre += nd.kp[k]
		centre /= float(ks.size())
		var rayon := 0.0
		for k: int in ks:
			rayon = maxf(rayon, centre.distance_to(nd.kp[k]) + nd.kr[k] * et[k])
		qs.append([centre, rayon, nd.kr[ks[ks.size() / 2]], ks, nd.kr[ks[0]]])      # les enfants sont triés par taille : celui du milieu est typique, le premier est le plus gros
	nd.quartiers = qs


## Amas d'un quartier : autour de chaque grain-enfant, `g` grains tirés de la forme même de l'enfant, à sa place et dans
## son orientation. Le shader les étale d'abord sur le territoire de l'enfant, puis les resserre sur sa forme : quand
## le nuage de l'enfant se déploie enfin, ses premiers points sont déjà là.
func _preparer_amas(nd: Noeud, q: int, g: int) -> Array:
	var qd: Array = nd.quartiers[q]
	var ks: Array = qd[3]
	var nb := ks.size() * g
	var pv := PackedVector3Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var c2 := PackedFloat32Array()
	var uv := PackedVector2Array()
	pv.resize(nb)
	c0.resize(nb * 4)
	c1.resize(nb * 2)
	c2.resize(nb * 3)
	uv.resize(nb)
	var o := 0
	for k: int in ks:
		var ch := noeuds[nd.kk[k]]
		_echantillon(ch)
		var m := ch.ech_p.size()
		var i := nd.ki[k]
		var cr := bin.decode_float(nd.att_off + i * 16)
		var cg := bin.decode_float(nd.att_off + i * 16 + 4)
		var cb := bin.decode_float(nd.att_off + i * 16 + 8)
		var sy := bin.decode_float(nd.sp_off + i * 8) if nd.sp_off >= 0 else float(nd.sys)
		var ph := bin.decode_float(nd.sp_off + i * 8 + 4) if nd.sp_off >= 0 else 0.0
		var r := nd.kr[k]
		var b := rots[nd.ko[k]] * r
		var c := nd.kp[k]
		var e := nd.etal[k]
		var dep := (k * 7) % m
		for j in g:
			var ei := (dep + j) % m
			var cc := ch.ech_c[ei]
			pv[o] = c + b * ch.ech_p[ei]
			c0[4 * o] = lerpf(cr, cc.r, 0.3)
			c0[4 * o + 1] = lerpf(cg, cc.g, 0.3)
			c0[4 * o + 2] = lerpf(cb, cc.b, 0.3)
			c0[4 * o + 3] = r
			c1[2 * o] = sy
			c1[2 * o + 1] = ph
			c2[3 * o] = c.x
			c2[3 * o + 1] = c.y
			c2[3 * o + 2] = c.z
			uv[o] = Vector2(j + 1, e)
			o += 1
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pv
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_CUSTOM0] = c0
	arr[Mesh.ARRAY_CUSTOM1] = c1
	arr[Mesh.ARRAY_CUSTOM2] = c2
	var ray: float = qd[1] * 1.1 + 0.05
	return [arr, AABB((qd[0] as Vector3) - Vector3.ONE * ray, Vector3.ONE * ray * 2.0), nd.n]


func _regler_materiau(nd: Noeud, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("vie", nd.vie)
	mat.set_shader_parameter("lueur", nd.lueur)
	if nd.fx.is_empty():
		mat.set_shader_parameter("fx", 0)
	else:
		mat.set_shader_parameter("fx", nd.fx[0])
		mat.set_shader_parameter("fx_w", nd.fx[1])
		mat.set_shader_parameter("fx_q", nd.fx[2])
		mat.set_shader_parameter("fx_dir", nd.fx[3])


func _maj_materiaux(nd: Noeud) -> void:
	var ni := noeuds.find(nd)
	for i in cases_cle.size():
		if cases_cle[i] >= 0 and cases_cle[i] / 100000 == ni:
			_regler_materiau(nd, reserve[i].material_override)


# ───────── scène et panneaux ─────────

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
		c.button_pressed.connect(_bouton_manette.bind(cote))
		var v := XRController3D.new()      # pose de visée : c'est d'elle que part le rayon du pointeur
		v.tracker = cote + "_hand"
		v.pose = "aim"
		origine.add_child(v)
		viseurs[cote] = v
	monde = Node3D.new()
	add_child(monde)
	for i in MAX_OBJETS:
		var mi := MeshInstance3D.new()
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		monde.add_child(mi)
		reserve.append(mi)
	# mains et rayons : de petites billes (articulations, trait doré entre les mains pendant le zoom, pointillé du pointeur)
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
	mm_mains.instance_count = NB_BILLES
	mm_mains.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm_mains
	mmi.custom_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	add_child(mmi)
	# halo : un anneau doux autour de l'élément visé
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled;\nuniform vec3 teinte : source_color = vec3(1.0, 0.85, 0.3);\nvoid fragment() {\n\tfloat r = length(UV * 2.0 - 1.0);\n\tfloat a = 0.8 * smoothstep(0.86, 0.92, r) * (1.0 - smoothstep(0.94, 1.0, r));\n\tALBEDO = teinte * a;\n}\n"
	var hm := ShaderMaterial.new()
	hm.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = hm
	halo = MeshInstance3D.new()
	halo.mesh = q
	halo.visible = false
	add_child(halo)
	_panneaux()
	presence = load("res://presence.gd").new()
	add_child(presence)
	presence.preparer()
	nom_vise = _etiquette(OR)
	for i in 10:
		labels.append(_etiquette(CLAIR))
	for i in 8:
		aides.append(_etiquette(Color(0.7, 0.92, 1)))


## Nom flottant, toujours tourné vers soi, lisible à travers le nuage.
func _etiquette(couleur: Color) -> Label3D:
	var l := Label3D.new()
	l.font = police
	l.font_size = 64
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.modulate = couleur
	l.shaded = false
	l.no_depth_test = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.render_priority = 3
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.visible = false
	add_child(l)
	return l


func _fond(taille: Vector2) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = taille
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = FOND
	m.render_priority = -1      # le fond se dessine avant le texte
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	return mi


## Texte net en VR : police en champ de distance (reste nette à toute taille), hauteur donnée en millimètres.
func _texte(parent: Node3D, pos: Vector3, mm: float, couleur: Color, largeur := 0.0) -> Label3D:
	var l := Label3D.new()
	l.font = police
	l.font_size = 64
	l.pixel_size = mm * 0.001 / 64.0
	l.outline_size = 0
	l.modulate = couleur
	l.shaded = false
	l.render_priority = 2
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if largeur > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = largeur / l.pixel_size
	l.position = pos
	parent.add_child(l)
	return l


## La carte d'explication à droite (lue de loin), le menu à gauche (au doigt ou au pointeur), et, pendant une visite,
## une barre « précédente / suivante / quitter » sous la carte.
func _panneaux() -> void:
	var base := ThemeDB.fallback_font
	if base is FontFile:
		var f := (base as FontFile).duplicate() as FontFile
		f.multichannel_signed_distance_field = true
		f.msdf_pixel_range = 12
		police = f
	else:
		police = base
	carte = Node3D.new()
	add_child(carte)
	carte.add_child(_fond(Vector2(0.66, 0.5)))
	var g := -0.305
	carte_lieu = _texte(carte, Vector3(g, 0.235, 0.002), 15, GRIS, 0.61)
	carte_titre = _texte(carte, Vector3(g, 0.208, 0.002), 38, CLAIR)
	carte_cat = _texte(carte, Vector3(g, 0.158, 0.002), 15, Color.WHITE)
	carte_texte = _texte(carte, Vector3(g, 0.128, 0.002), 22, CLAIR, 0.61)
	carte_note = _texte(carte, Vector3(g, -0.118, 0.002), 14, GRIS, 0.61)
	carte_guide = _texte(carte, Vector3(g, -0.172, 0.002), 17, OR, 0.61)
	var classe = load("res://panneau.gd")
	var t := Vector2(0.21, 0.07)
	menu = load("res://menu.gd").new()      # le menu à onglets (Explorer, Montrer, Visites, Réglages)
	add_child(menu)
	menu.preparer(police, contenus.get("visites", []), contenus.get("filtres", []))
	# listes : visites et filtres
	p_visites = classe.new(police)
	add_child(p_visites)
	var vs: Array = contenus.get("visites", [])
	p_visites.fond(Vector2(0.47, 0.11 + 0.082 * (vs.size() + 1)))
	p_visites.titre("Visites guidées", Vector2(0, 0.041 * (vs.size() + 1)), 20.0)
	for i in vs.size():
		p_visites.bouton("v:" + str(vs[i].id), str(vs[i].titre), Vector2(0, 0.041 * (vs.size() + 1) - 0.082 * (i + 1)), Vector2(0.43, 0.07))
	p_visites.bouton("retour", "Retour", Vector2(0, -0.041 * (vs.size() + 1)), Vector2(0.43, 0.07))
	p_filtres = classe.new(police)
	add_child(p_filtres)
	var fs: Array = contenus.get("filtres", [])
	var nl := ceili(fs.size() / 2.0)
	p_filtres.fond(Vector2(0.47, 0.11 + 0.082 * (nl + 1)))
	p_filtres.titre("Montrer…", Vector2(0, 0.041 * (nl + 1)), 20.0)
	for i in fs.size():
		p_filtres.bouton("f:" + str(fs[i].id), str(fs[i].nom), Vector2(-0.112 + 0.224 * (i % 2), 0.041 * (nl + 1) - 0.082 * (i / 2 + 1)), t)
	p_filtres.bouton("retour", "Retour", Vector2(0, -0.041 * (nl + 1)), Vector2(0.43, 0.07))
	p_visite = classe.new(police)
	add_child(p_visite)
	p_visite.fond(Vector2(0.66, 0.1))
	p_visite.bouton("prec", "Précédente", Vector2(-0.215, 0), Vector2(0.2, 0.07))
	p_visite.bouton("suiv", "Suivante", Vector2(0, 0), Vector2(0.2, 0.07))
	p_visite.bouton("quitter", "Quitter", Vector2(0.215, 0), Vector2(0.2, 0.07))
	p_paume = classe.new(police)
	add_child(p_paume)
	var pastilles := [["menu_bascule", "Menu"], ["home", "Corps entier"], ["recentrer", "Recentrer"], ["micro", "Parler"]]
	for i in pastilles.size():
		p_paume.bouton(pastilles[i][0], pastilles[i][1], Vector2(-0.05 + 0.1 * (i % 2), 0.028 - 0.056 * (i / 2)), Vector2(0.094, 0.05))
	p_paume.visible = false
	bandeau = Node3D.new()
	add_child(bandeau)
	bandeau.add_child(_fond(Vector2(0.74, 0.11)))
	bandeau_texte = _texte(bandeau, Vector3(0, 0, 0.002), 20, OR, 0.7)
	bandeau_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bandeau_texte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p_mini = classe.new(police)
	add_child(p_mini)
	p_mini.bouton("menu", "Menu", Vector2(0, 0), Vector2(0.18, 0.07))
	p_tuto = classe.new(police)
	add_child(p_tuto)
	p_tuto.fond(Vector2(0.66, 0.1))
	p_tuto.bouton("tuto_suiv", "Suivante", Vector2(-0.11, 0), Vector2(0.2, 0.07))
	p_tuto.bouton("tuto_fin", "Quitter", Vector2(0.11, 0), Vector2(0.2, 0.07))
	for p in [menu, p_visites, p_filtres, p_visite, p_mini, p_tuto, p_paume]:
		p.touche.connect(func(_id: String) -> void: sons.jouer("clic"))


func _maj_boutons() -> void:
	menu.etat({"micro": voix.micro, "visite": str(contenus.visites[visite.v].id) if visite != null else "", "filtre": filtre,
		"etiquettes": etiquettes, "niveau": niveau, "mixte": mixte, "tuto": tuto != null})
	for f: Dictionary in contenus.get("filtres", []):
		p_filtres.allume("f:" + str(f.id), str(f.id) == filtre)
	if visite != null:
		var n: int = (contenus.visites[visite.v].etapes as Array).size()
		p_visite.libelle("suiv", "Suivante" if visite.i < n - 1 else "Terminer")
		p_visite.montre("prec", visite.i > 0)


func _nom_filtre() -> String:
	for f: Dictionary in contenus.get("filtres", []):
		if str(f.id) == filtre:
			return str(f.nom)
	return "tout"


func _tete() -> Vector3:
	return camera.global_position


func _avant() -> Vector3:
	var f := -camera.global_basis.z
	f.y = 0
	return f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)


## Replace le corps entier devant soi, debout, à taille réelle, face à soi. C'est le « point zéro » : on y revient à tout moment.
func _placer_devant() -> void:
	var h := _tete()
	var f := _avant()
	chemin = [{"n": racine, "k": -1}]
	w_s = TAILLE_CORPS
	w_a = Basis(Vector3.UP, atan2(-f.x, -f.z))
	w_p = Vector3(h.x + f.x * 1.25, _sol() + 0.98 * w_s + 0.01, h.z + f.z * 1.25)
	prec = null
	voy = null
	vise = -1
	couche = 0.0
	couche_cible = 0.0
	x_liste = Transform3D.IDENTITY
	x_calcul = Transform3D.IDENTITY
	cle_calcul = ""
	_replacer_panneaux(true)


## Hauteur du sol. Si le casque ne la connaît pas (tête trop basse pour être debout ou assis), on la déduit de la tête.
func _sol() -> float:
	var y := _tete().y
	return 0.0 if y > 0.9 else y - 1.6


## Disposition : l'objet au centre, la carte à 30° à droite, le menu à 30° à gauche et à portée de doigt, les
## sous-titres du guide sous l'objet. Les panneaux suivent paresseusement : ils ne se replacent que si l'on s'est
## nettement tourné (35°) ou déplacé (45 cm), et seulement une fois la tête posée. Un panneau qu'on a déplacé à la
## main reste épinglé là où on l'a mis, jusqu'au prochain recentrage (`tout_de_suite`).
func _replacer_panneaux(tout_de_suite: bool) -> void:
	var h := _tete()
	var f := _avant()
	var dt := dt_image
	# vitesse de rotation de la tête, pour ne pas ré-ancrer en plein mouvement
	var vit := rad_to_deg(f.angle_to(avant_prec)) / maxf(dt, 0.001)
	avant_prec = f
	t_stable = t_stable + dt if vit < 20.0 else 0.0
	if tout_de_suite:
		epingles.clear()
		tenu = null
	if tout_de_suite or ((f.dot(ancre_avant) < 0.82 or h.distance_to(ancre_tete) > 0.45) and t_stable > 0.4 and not sur_panneau):
		ancre_avant = f
		ancre_tete = h
	var k := 1.0 - exp(-dt * 5.0)
	# [panneau, azimut (rad, positif à droite), hauteur par rapport aux yeux, distance]
	for def in [[carte, 0.524, -0.1, 1.15], [menu, -0.524, -0.2, 0.5], [bandeau, 0.0, -0.49, 1.1]]:
		var p := def[0] as Node3D
		if epingles.has(p) or (tenu != null and tenu.p == p):
			continue
		var dir := ancre_avant.rotated(Vector3.UP, -def[1])
		var c := Vector3(ancre_tete.x + dir.x * def[3], ancre_tete.y + def[2], ancre_tete.z + dir.z * def[3])
		var cible := Transform3D(Basis.IDENTITY, c).looking_at(c + (c - ancre_tete), Vector3.UP)   # la face avant (+z) regarde la tête
		p.global_transform = cible if tout_de_suite else p.global_transform.interpolate_with(cible, k)
	# les listes et le bouton « Menu » prennent la place du menu ; les barres de visite et de tutoriel se rangent sous la carte
	for p in [p_visites, p_filtres, p_mini]:
		p.global_transform = menu.global_transform
	for p in [p_visite, p_tuto]:
		p.global_transform = carte.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, -0.32, 0.01))


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
	if not essai:
		sons.jouer("entree")


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
	if not essai:
		sons.jouer("sortie")


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
		# à taille réelle, saisir le corps ne fait entrer nulle part ; dès qu'on l'agrandit, les organes s'ouvrent
		var seuil := ENTREE if (chemin.size() > 1 or w_s > TAILLE_CORPS * 1.2) else 1e9
		for k in nd.nk:
			var r := nd.kr[k]
			if r * w_s < seuil:
				break
			var d := nd.kp[k].distance_to(f)
			if d < r * 0.9:
				mieux = k      # triés par taille : le dernier qui contient le foyer est le plus petit, donc le plus précis
			elif mieux < 0 and d - r < ecart:
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
	_borner(foyer)


func _borner(foyer: Vector3) -> void:
	var cur := _courant()
	var lim := clampf(w_s, 0.05 if chemin.size() == 1 else 0.01, (0.5 / cur.min_r) if cur.nk > 0 else 5.0)
	if lim != w_s:
		w_p = foyer + (w_p - foyer) * (lim / w_s)
		w_s = lim
	w_a = w_a.orthonormalized()


func _zoom(foyer: Vector3, k: float) -> void:
	w_s *= k
	w_p = foyer + (w_p - foyer) * k


# ───────── voyage guidé : le monde vient à soi, niveau après niveau, sans se presser ─────────

## `angle` (degrés) : orientation à l'arrivée. Pour le corps entier : 0 de face, 90 de profil, 180 de dos ; pour un
## autre objet : de combien il tourne sur lui-même en arrivant.
func aller(cible: int, taille := 0.42, angle = null) -> void:
	_partir(_route_vers(cible), taille, angle)


## Voyage vers un enfant du niveau où l'on se trouve (celui qu'on vient de viser), sans repasser par le chemin habituel.
func aller_enfant(k: int, taille := 0.42) -> void:
	var route: Array = []
	for i in range(1, chemin.size()):
		route.append({"n": chemin[i].n, "k": chemin[i].k})
	route.append({"n": _courant().kk[k], "k": k})
	_partir(route, taille, null)


func _partir(route: Array, taille: float, angle) -> void:
	var h := _tete()
	var f := _avant()
	voy = {"route": route, "foyer": Vector3(h.x + f.x * 0.85, maxf(0.95, h.y - 0.22), h.z + f.z * 0.85), "taille": taille,
		"face": atan2(-f.x, -f.z), "angle": angle, "reste": deg_to_rad(float(angle)) if angle != null else 0.0}
	prec = null
	vise = -1
	print("voyage vers ", noeuds[route[-1].n].nom if not route.is_empty() else "le corps")


func _voyage(dt: float) -> void:
	var route: Array = voy.route
	var commun := 0
	while commun < route.size() and commun + 1 < chemin.size() and chemin[commun + 1].k == route[commun].k and chemin[commun + 1].n == route[commun].n:
		commun += 1
	var a := 1.0 - exp(-dt * 3.0)
	var zr := 1.4 * dt
	var pas_max := 1.0 * dt      # jamais plus d'un mètre par seconde
	var foyer: Vector3 = voy.foyer
	if chemin.size() - 1 > commun:
		# on est dans une autre branche : on ressort
		w_p += ((foyer - w_p) * a * 0.5).limit_length(pas_max)
		_zoom(foyer, exp(-zr * 1.4))
		if w_s < 0.07:
			_sortir()
	elif commun < route.size():
		# on amène l'enfant visé devant soi, on l'agrandit, puis on y entre
		var nd := _courant()
		var k: int = route[commun].k
		var c := w_p + (w_a * nd.kp[k]) * w_s
		w_p += ((foyer - c) * a).limit_length(pas_max)
		c = w_p + (w_a * nd.kp[k]) * w_s
		var r := nd.kr[k] * w_s
		var d := c.distance_to(foyer)
		if d < 0.25:
			if r >= 0.2 and d < 0.4 * r:
				_entrer(k)
			else:
				_zoom(foyer, exp(zr))
		elif d > 0.9:
			_zoom(foyer, exp(-zr))
	else:
		# arrivé au bon niveau : on le centre, on lui donne sa taille de présentation et son orientation
		var centre := foyer
		var ecart := 0.0
		if chemin.size() == 1:
			centre = Vector3(foyer.x, _sol() + 0.98 * voy.taille + 0.01 if couche_cible < 0.5 else 1.0, foyer.z) + _avant() * 0.4
			var but := Basis(Vector3.UP, voy.face + deg_to_rad(float(voy.angle) if voy.angle != null else 0.0))
			w_a = w_a.orthonormalized().slerp(but, a)
			ecart = w_a.z.angle_to(but.z) + w_a.y.angle_to(but.y)
		elif absf(voy.reste) > 0.001:
			var pas := clampf(voy.reste, -0.6 * dt, 0.6 * dt)
			w_a = Basis(Vector3.UP, pas) * w_a
			voy.reste -= pas
			ecart = absf(voy.reste)
		w_p += ((centre - w_p) * a).limit_length(pas_max)
		var g := log(voy.taille / w_s)
		if absf(g) < 0.03 and w_p.distance_to(centre) < 0.03 and ecart < 0.04:
			voy = null
			_arrive()
		else:
			_zoom(centre, exp(clampf(g, -zr, zr)))
	w_a = w_a.orthonormalized()


func _arrive() -> void:
	if temps_en_cours != null:
		geste_fait = true
	if not (_courant().nom in vus_seance):
		vus_seance.append(_courant().nom)
		if vus_seance.size() > 30:
			vus_seance.pop_front()
	if arrivee_du_visiteur and mode_guide == "incarne" and api.disponible() and visite == null and tuto == null and temps_en_cours == null:
		arrivee_du_visiteur = false
		dire_a_l_arrivee = false
		_evenement("arrivee")
		return
	arrivee_du_visiteur = false
	print("arrivée : ", _courant().nom, " (visite)" if visite != null else "")
	if visite != null:
		visite.arrive = true
		visite.t = 0.0
		var son_impro := str(contenus.visites[visite.v].etapes[visite.i].get("audio", ""))
		if son_impro != "":
			voix.dire_wav(son_impro, true)
		if str(contenus.visites[visite.v].id) != "impro":
			voix.dire(["v_%s_%d" % [contenus.visites[visite.v].id, visite.i]], true)      # le guide raconte l'étape une fois l'objet sous les yeux
		return
	if dire_a_l_arrivee:
		dire_a_l_arrivee = false
		_decrire()


# ───────── choix de ce qu'on affiche (calculé dans un fil à part, dans le repère du niveau courant) ─────────
#
# Principe du rendu (étude de granularité) — points.gdshader applique les mêmes règles, grain par grain :
#  · le grain est petit et régulier (2,4 à 4 pixels de référence, 5 pour les quelques gros enfants d'un nœud) : une forme
#    se lit par la densité et la couleur de ses grains, jamais par leur taille ;
#  · un enfant reste un grain tant que son rayon apparent, pondéré par le regard, est sous OPEN. En grandissant, il
#    s'entoure d'un amas (AMAS × rayon² grains, 48 au plus) tiré de sa propre forme : d'abord étalé sur son territoire,
#    puis resserré sur sa forme. À OPEN, son nuage apparaît en fondu (jusqu'à OPEN × FONDU_OUV) pendant que grain et
#    amas s'effacent, et ses points se révèlent un à un (DENS × rayon^1,5) : jamais de saut ;
#  · on déploie d'abord ce qu'on regarde et ce que contient l'objet où l'on se trouve ; le voisinage passe après, plus
#    léger. Si le budget manque, les nuages s'allègent, puis les moins présents redeviennent des grains : chaque objet
#    affiché reçoit le seuil qui vaut pour ses enfants (ouv_enf) et celui que son parent lui applique (ouv_soi), si
#    bien que le shader et cette liste sont toujours d'accord.

## Poids d'un objet selon son écart au centre du regard (même formule que `regard` dans points.gdshader).
func _regard(dv: Vector3, d: float, r: float, avant: Vector3) -> float:
	var th := acos(clampf(dv.dot(avant) / d, -1.0, 1.0)) - asin(clampf(r / d, 0.0, 1.0))
	return lerpf(1.0, REGARD_MIN, smoothstep(REGARD_0, REGARD_1, th))


## Pose un nuage dans la liste, puis propose ses enfants (st.tas) et ses amas (st.amas). Un enfant n'est proposé que
## si son rayon apparent, pondéré par le regard, atteint OPEN : en dessous il reste un grain et son amas.
## st.mode dit où l'on est : 0 sur le chemin qui mène à l'objet courant (st.niveau : indice dans le chemin),
## 1 dans l'objet courant, 2 chez un voisin, 3 chez un voisin de voisin (qui ne déploie plus rien).
## Une entrée de la liste : [nœud, maillage, repère, rayon pondéré, parent, mode, seuil pour ses enfants, toujours plein,
## allègement].
func _collecter(ni: int, t: Vector3, a: Basis, s: float, prof: int, sortie: Array, st: Dictionary) -> void:
	var nd := noeuds[ni]
	var mode: int = st.mode
	var dv0: Vector3 = t - st.tete
	var d := maxf(st.dmin, dv0.length())
	var pe: float = s / d * st.f * _regard(dv0, d, s, st.avant)
	var allege: float = 1.0 if mode <= 1 else DENS_VOISINS      # le voisinage se contente d'une esquisse
	var veut: float = nd.ns + pow(pe, 1.5) * st.dens * allege
	var lod := 0
	while lod < nd.lod_n.size() - 1 and nd.lod_n[lod + 1] >= veut:
		lod += 1
	var x := Transform3D(a * s, t)
	var rang := sortie.size()
	var ferme := nd.nk == 0 or prof >= 7 or mode == 3
	sortie.append([ni, lod, x, pe, st.parent, mode, 1e9 if ferme else OPEN, st.plein, allege])
	st.total += nd.lod_n[lod]
	if nd.nk == 0:
		return
	if lod == 0:
		# les amas, quartier par quartier : seulement là où les enfants ont assez de pixels pour en montrer
		if nd.quartiers == null:
			_quartiers(nd)
		for q in (nd.quartiers as Array).size():
			var qd: Array = nd.quartiers[q]
			var cq: Vector3 = t + a * ((qd[0] as Vector3) * s)
			var rq: float = qd[1] * s
			var dq: Vector3 = cq - st.tete
			var ddq := maxf(st.dmin, dq.length())
			if ddq > rq and dq.dot(st.avant) < 0.25 * ddq - rq:
				continue
			var pq: float = qd[2] * s / maxf(st.dmin * 8.0, ddq - rq * 0.7) * st.f * _regard(dq, ddq, rq, st.avant)
			if AMAS * pq * pq >= 1.5:
				(st.amas as Array).append([pq * POIDS_MODE[mode], ni, q, x, rang, mode, pq])
	if ferme:
		return
	var chainon := -1      # l'enfant par lequel passe le chemin vers l'objet courant : toujours affiché
	var chemin_c: Array = st.chemin
	if mode == 0 and st.niveau + 1 < chemin_c.size():
		chainon = chemin_c[st.niveau + 1].k
	var mode_enf := 1 if mode == 1 else (2 if mode == 0 else 3)
	var poids: float = POIDS_MODE[mode_enf]
	var dpres := maxf(st.dmin * 1.7, d - s)
	var cand: Array = []
	if chainon >= 0:
		var dernier: bool = st.niveau + 2 >= chemin_c.size()
		cand.append([1e12, nd.kk[chainon], t + a * (nd.kp[chainon] * s), a * rots[nd.ko[chainon]], nd.kr[chainon] * s, prof + 1,
			1 if dernier else 0, rang, 0.0, st.niveau + 1])
	# quels enfants examiner : tous s'ils sont peu nombreux (ils sont triés par taille, on s'arrête au premier trop
	# petit) ; sinon, seulement ceux des quartiers qui sont dans le champ et assez proches
	var a_voir: Array = []
	var tries := nd.nk <= 600
	if tries:
		a_voir = range(nd.nk)
	else:
		if nd.quartiers == null:
			_quartiers(nd)
		for qd: Array in nd.quartiers:
			var cq: Vector3 = t + a * ((qd[0] as Vector3) * s)
			var rq: float = qd[1] * s
			var dq: Vector3 = cq - st.tete
			var ddq := dq.length()
			if ddq > rq and dq.dot(st.avant) < 0.25 * ddq - rq:
				continue
			if qd[4] * s / maxf(st.dmin * 1.7, ddq - rq) * st.f < OPEN:
				continue
			a_voir.append_array(qd[3])
	for k: int in a_voir:
		var r := nd.kr[k] * s
		if k == chainon:
			continue
		if r / dpres * st.f < OPEN:
			if tries:
				break
			continue
		if st.masque != 0 and nd.ks.size() > k and nd.ks[k] >= 0 and (st.masque & (1 << nd.ks[k])) == 0:
			continue      # filtre actif : ce qui est estompé ne s'ouvre pas
		var c := t + a * (nd.kp[k] * s)
		var dv: Vector3 = c - st.tete
		var dd := maxf(st.dmin, dv.length())
		var pr: float = r / dd * st.f
		if pr < OPEN:
			continue
		if dd > r and dv.dot(st.avant) < 0.25 * dd - r:
			continue      # hors du champ de vision
		pr *= _regard(dv, dd, r, st.avant)
		if pr < OPEN:
			continue
		cand.append([pr * poids, nd.kk[k], c, a * rots[nd.ko[k]], r, prof + 1, mode_enf, rang, pr, 0])
	cand.sort_custom(func(u: Array, v: Array) -> bool: return u[0] > v[0])
	var tas: Array = st.tas
	for i in cand.size():
		if i < MAX_OBJETS:
			tas.insert(tas.bsearch_custom(cand[i], func(u: Array, v: Array) -> bool: return u[0] < v[0]), cand[i])
		else:
			sortie[rang][6] = maxf(sortie[rang][6], cand[i][8])


func _calculer(inst: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
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
	var dens: float = DENS
	var dernier: bool = haut == inst.chemin.size() - 1
	var st := {"tete": inst.tete, "avant": inst.avant, "f": inst.f, "dmin": 0.03 / inst.w_s, "total": 0,
		"budget": inst.budget, "masque": inst.masque, "dens": dens, "tas": [], "amas": [],
		"chemin": inst.chemin, "mode": 1 if dernier else 0, "niveau": haut, "parent": -1, "plein": true}
	# 1. Les nuages, du plus présent au moins présent (rayon apparent pondéré par le regard ; le voisinage passe après
	#    ce que contient l'objet courant), tant qu'il reste des objets.
	_collecter(inst.chemin[haut].n, t, a, s, 0, sortie, st)
	var tas: Array = st.tas
	var nb_max := MAX_OBJETS - 110
	while not tas.is_empty() and sortie.size() < nb_max:
		var c: Array = tas.pop_back()
		st.mode = c[6]
		st.parent = c[7]
		st.niveau = c[9]
		st.plein = c[0] > 1e11
		_collecter(c[1], c[2], c[3], c[4], c[5], sortie, st)
	for c: Array in tas:      # ceux qui n'ont pas eu de place restent des grains : leur parent le saura
		sortie[c[7]][6] = maxf(sortie[c[7]][6], c[8])
	# 2. Trop de points ? On referme d'abord les voisins de voisins, puis on allège chaque nuage (moins de points pour
	#    tous) ; si cela ne suffit pas, on referme les moins présents. Mieux vaut cent formes esquissées que dix formes
	#    complètes au milieu de grains.
	var plafond: float = inst.budget * PART_NUAGES
	for passe in 5:
		if st.total <= plafond:
			break
		if passe == 0 or passe == 4:
			for i in range(sortie.size() - 1, 0, -1):
				var it: Array = sortie[i]
				if st.total <= plafond:
					break
				if it[1] < 0 or it[7] or (passe == 0 and it[5] != 3):
					continue
				st.total -= noeuds[it[0]].lod_n[it[1]]
				it[1] = -1
				sortie[it[4]][6] = maxf(sortie[it[4]][6], it[3])
		else:
			dens = maxf(DENS * DENS_MIN, dens * plafond / float(st.total) * 0.9)
			st.total = 0
			for it: Array in sortie:
				if it[1] < 0:
					continue
				var nd := noeuds[it[0]]
				var veut: float = nd.ns + pow(it[3], 1.5) * dens * it[8]
				var lod := 0
				while lod < nd.lod_n.size() - 1 and nd.lod_n[lod + 1] >= veut:
					lod += 1
				it[1] = lod
				st.total += nd.lod_n[lod]
	# 3. La liste à afficher : [nœud, maillage, repère, seuil pour ses enfants, seuil que son parent lui applique, densité].
	var liste: Array = []
	var seuil_max := OPEN
	for it: Array in sortie:
		if it[1] < 0:
			continue
		var soi: float = 0.0 if it[7] else sortie[it[4]][6]
		if it[6] < 1e8:
			seuil_max = maxf(seuil_max, it[6])
		liste.append([it[0], it[1], it[2], it[6], soi, dens * it[8]])
	# 4. Les amas, eux aussi du plus présent au moins présent, avec ce qui reste du budget. Hors de l'objet où l'on
	#    se trouve, ils restent légers : le voisinage ne doit pas noyer ce qu'on regarde.
	var amas: Array = st.amas
	amas.sort_custom(func(u: Array, v: Array) -> bool: return u[0] > v[0])
	var reste: float = inst.budget - st.total
	var reste_voisins: float = inst.budget * PART_AMAS_VOISINS
	var ng := G_AMAS.size()
	for c: Array in amas:
		if liste.size() >= MAX_OBJETS:
			break
		var it: Array = sortie[c[4]]
		if it[1] != 0:
			continue      # le nuage a été refermé ou allégé : pas d'amas
		var nd := noeuds[c[1]]
		var nbk: int = (nd.quartiers[c[2]][3] as Array).size()
		var nw: float = minf(AMAS * c[6] * c[6], G_AMAS[ng - 1])
		var dedans: bool = c[5] == 1
		var place: float = reste if dedans else minf(reste, reste_voisins)
		var gi := -1
		for i in (ng if dedans else mini(ng, AMAS_VOISINS)):
			if nbk * G_AMAS[i] <= place:
				gi = i
				if G_AMAS[i] >= nw:
					break
		if gi < 0:
			continue
		var soi: float = 0.0 if it[7] else sortie[it[4]][6]
		liste.append([c[1], nd.lod_n.size() + c[2] * ng + gi, c[3], it[6], soi, dens * it[8]])
		reste -= nbk * G_AMAS[gi]
		if not dedans:
			reste_voisins -= nbk * G_AMAS[gi]
		st.total += nbk * G_AMAS[gi]
	# les maillages qui manquent sont préparés ici, hors du fil d'affichage
	for it: Array in liste:
		var nd := noeuds[it[0]]
		var i: int = it[1]
		if (i >= nd.lod_mesh.size() or nd.lod_mesh[i] == null) and not nd.prep.has(i):
			nd.prep[i] = _preparer(nd, i)
	resultat = [liste, st.total, seuil_max, dens]
	t_calcul = maxf(t_calcul, (Time.get_ticks_usec() - t0) / 1000.0)


## Le calcul n'est relancé que si quelque chose a bougé (tête, monde ou budget) : immobile, le casque se repose.
func _lancer_calcul() -> void:
	var inv := (w_a * _pose_couchee()).transposed()
	var h := _tete()
	var av := -camera.global_basis.z
	var cle := "%s|%s|%.4f|%s|%s|%d|%d|%d" % [w_p.snapped(Vector3.ONE * 0.002), (w_a * _pose_couchee()).get_euler().snapped(Vector3.ONE * 0.004), w_s,
		h.snapped(Vector3.ONE * 0.01), av.snapped(Vector3.ONE * 0.02), chemin.size(), int(budget / 5000.0), masque]
	if cle == cle_calcul and not essai:
		return
	cle_calcul = cle
	var inst := {"chemin": chemin.duplicate(true), "w_s": w_s, "tete": (inv * (h - w_p)) / w_s, "avant": (inv * av).normalized(),
		"f": F_REF, "budget": budget, "masque": masque}
	x_calcul = Transform3D.IDENTITY
	if essai:
		_calculer(inst)
		_appliquer()
		return
	fil = Thread.new()
	fil.start(_calculer.bind(inst))


func _appliquer() -> void:
	var t0 := Time.get_ticks_usec()
	var liste: Array = resultat[0]
	nb_points = resultat[1]
	x_liste = x_calcul
	ouv_aff = resultat[2]
	dens_aff = resultat[3]
	# Chaque objet de la réserve a son propre matériau (ses seuils d'ouverture lui sont propres). Un nuage déjà affiché
	# garde son objet d'une liste à l'autre : on ne retouche que ce qui change.
	var nb := reserve.size()
	if cases_cle.size() != nb:
		cases_cle.resize(nb)
		cases_cle.fill(-1)
		cases_ouv.resize(nb)
	var anciens := {}
	for i in nb:
		if cases_cle[i] >= 0:
			if not anciens.has(cases_cle[i]):
				anciens[cases_cle[i]] = []
			(anciens[cases_cle[i]] as Array).append(i)
	var pris := PackedByteArray()
	pris.resize(nb)
	var place := PackedInt32Array()
	place.resize(liste.size())
	for j in liste.size():
		var cle: int = liste[j][0] * 100000 + liste[j][1]
		place[j] = -1
		if anciens.has(cle) and not (anciens[cle] as Array).is_empty():
			place[j] = (anciens[cle] as Array).pop_back()
			pris[place[j]] = 1
	var libre := 0
	for j in liste.size():
		var it: Array = liste[j]
		var i := place[j]
		if i < 0:
			while libre < nb and pris[libre] == 1:
				libre += 1
			if libre >= nb:
				break
			i = libre
			pris[i] = 1
		var mi := reserve[i]
		var mat := mi.material_override as ShaderMaterial
		if mat == null:
			mat = ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("masque", masque)
			mat.set_shader_parameter("flux", flux)
			mat.set_shader_parameter("foyer", foyer_lum)
			mat.set_shader_parameter("retrait", retrait_lum)
			mi.material_override = mat
			mats.append(mat)
		var cle: int = it[0] * 100000 + it[1]
		if cases_cle[i] != cle:
			var nd := noeuds[it[0]]
			mi.mesh = _maillage(nd, it[1])
			mat.set_shader_parameter("cnt", float(nd.lod_n[it[1]] if it[1] < nd.lod_n.size() else nd.n))
			mat.set_shader_parameter("n_tot", float(nd.n))
			mat.set_shader_parameter("n_fixe", float(nd.ns))
			_regler_materiau(nd, mat)
			cases_cle[i] = cle
			cases_ouv[i] = Vector3(-1, -1, -1)
		mi.transform = it[2]
		var seuils := Vector3(it[3], it[4], it[5])
		if cases_ouv[i] != seuils:
			cases_ouv[i] = seuils
			mat.set_shader_parameter("ouv_enf", seuils.x)
			mat.set_shader_parameter("ouv_soi", seuils.y)
			mat.set_shader_parameter("dens", seuils.z)
		mi.visible = true
	for i in nb:
		if pris[i] == 0:
			reserve[i].visible = false
	# Les amas sont nombreux (chaque quartier existe en plusieurs tailles) : on note quand chacun a servi, et l'on
	# libère les plus anciens quand il y en a trop.
	tour_amas += 1
	for it: Array in liste:
		var nd := noeuds[it[0]]
		if it[1] >= nd.lod_n.size():
			var cle: int = it[0] * 100000 + it[1]
			if not amas_vus.has(cle):
				amas_pts += (nd.lod_mesh[it[1]] as ArrayMesh).surface_get_array_len(0)
			amas_vus[cle] = tour_amas
	if amas_pts > MAX_AMAS_GARDES:
		var cles := amas_vus.keys()
		cles.sort_custom(func(u: int, v: int) -> bool: return amas_vus[u] < amas_vus[v])
		for cle: int in cles:
			if amas_pts <= MAX_AMAS_GARDES * 0.7 or amas_vus[cle] == tour_amas:
				break
			var nd := noeuds[cle / 100000]
			var idx := cle % 100000
			amas_pts -= (nd.lod_mesh[idx] as ArrayMesh).surface_get_array_len(0)
			nd.lod_mesh[idx] = null
			amas_vus.erase(cle)
			for i in nb:
				if cases_cle[i] == cle:
					cases_cle[i] = -1
					reserve[i].mesh = null
	t_appliquer = maxf(t_appliquer, (Time.get_ticks_usec() - t0) / 1000.0)
	t_appliquer_somme += (Time.get_ticks_usec() - t0) / 1000.0
	nb_appliquer += 1


## Tient la fréquence d'images : moins de points si le casque peine, davantage s'il a de la marge.
func _adapter_budget(dt: float) -> void:
	ips = lerpf(ips, 1.0 / maxf(dt, 0.001), 0.05)
	if ips < cible_ips * 0.9:
		t_lent += dt
		t_rapide = 0.0
		if t_lent > 0.8:
			budget = maxf(MIN_POINTS, budget * 0.85)
			t_lent = 0.0
	elif ips > cible_ips * 0.97:
		t_rapide += dt
		t_lent = 0.0
		if t_rapide > 4.0:
			budget = minf(MAX_POINTS, budget * 1.06)
			t_rapide = 0.0


## Pendant la visite du sommeil, le corps s'allonge (uniquement quand on le voit en entier).
func _pose_couchee() -> Basis:
	if couche < 0.001 or chemin.size() > 1:
		return Basis.IDENTITY
	return Basis(Vector3(0, 0, 1), couche * PI * 0.5)


# ───────── mains et manettes ─────────

## Lit les mains (ou, à défaut, les manettes) et en tire deux choses : de quoi saisir (`mains`) et de quoi viser (`pointeurs`).
## Mains : pincement bref = clic, pincement tenu = saisie, paume regardée = menu de paume. Manettes : gâchette de
## l'index = clic, gâchette du majeur = saisie.
func _lire_mains(dt: float) -> void:
	mains.clear()
	pointeurs.clear()
	clic_monde = ""
	var nb := 0
	var o := origine.global_transform
	var h := _tete()
	var regard := -camera.global_basis.z
	var maintenant := Time.get_ticks_msec() * 0.001
	for cote: String in ["left", "right"]:
		var m := {}
		var p := {}
		var tr := XRServer.get_tracker("/user/hand_tracker/" + cote) as XRHandTracker
		if tr and tr.has_tracking_data:
			var pouce := o * tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP).origin
			var index := o * tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP).origin
			var poignet := o * tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST).origin
			var paume := o * tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM).origin
			var base_i := o * tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL).origin
			var base_a := o * tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL).origin
			var d := pouce.distance_to(index)
			# paume regardée : la paume fait face au visage, le regard est posé dessus, la main est ouverte
			var normale := (base_i - poignet).cross(base_a - poignet).normalized() * (1.0 if cote == "right" else -1.0)
			var vers_tete := h - paume
			var dist_p := vers_tete.length()
			vers_tete /= maxf(dist_p, 0.01)
			var face := normale.dot(vers_tete)
			var vu := regard.dot(-vers_tete)
			var tp_: float = t_paume.get(cote, 0.0)
			if paume_vue.get(cote, false):
				tp_ = tp_ + dt if (face < 0.5 or vu < 0.78 or dist_p > 0.7) else 0.0
				if tp_ > 0.4:
					paume_vue[cote] = false
					tp_ = 0.0
			else:
				tp_ = tp_ + dt if (face > 0.75 and vu > 0.9 and dist_p > 0.2 and dist_p < 0.6 and d > 0.05) else 0.0
				if tp_ > 0.3:
					paume_vue[cote] = true
					tp_ = 0.0
			t_paume[cote] = tp_
			var en_paume: bool = paume_vue.get(cote, false)
			var avant_p: bool = pince[cote]
			pince[cote] = (d < 0.042 if pince[cote] else d < 0.024) and not en_paume
			var q := (o.basis * tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST).basis).orthonormalized().get_rotation_quaternion()
			# le poignet tremble : on lisse sa rotation pour que l'objet tenu ne tremble pas avec lui
			q_lisse[cote] = (q_lisse[cote] as Quaternion).slerp(q, 0.35) if q_lisse.has(cote) else q
			var pos := (pouce + index) * 0.5
			# le rayon part de la base de l'index, dans l'axe épaule-main ; il se fige quand les doigts se referment
			# pour que la cible ne saute pas au moment du clic
			var lat := camera.global_basis.x * (0.17 if cote == "right" else -0.17)
			var epaule := h + Vector3(lat.x, -0.22, lat.z)
			var dir := (base_i - epaule).normalized()
			if rayon.has(cote):
				if d < 0.045:
					dir = rayon[cote].d
					base_i = rayon[cote].o
				else:
					dir = (rayon[cote].d as Vector3).lerp(dir, 0.35).normalized()
			rayon[cote] = {"o": base_i, "d": dir}
			if pince[cote] and not avant_p:
				t_pince[cote] = {"t": maintenant, "p": pos, "saisie": false}
			var saisie := false
			if pince[cote] and t_pince.has(cote):
				var tp: Dictionary = t_pince[cote]
				if not tp.saisie and (maintenant - tp.t > 0.25 or pos.distance_to(tp.p) > 0.03):
					tp.saisie = true
				saisie = tp.saisie
			elif not pince[cote] and t_pince.has(cote):
				if not t_pince[cote].saisie:
					clic_monde = cote      # pincement bref et sans mouvement : c'est un clic
				t_pince.erase(cote)
			m = {"id": cote, "pos": pos, "bout": index, "pouce": pouce, "poignet": poignet, "paume": paume, "normale": normale,
				"doigts": ((base_i + base_a) * 0.5 - poignet).normalized(), "ouverte": d > 0.06, "en_paume": en_paume,
				"manette": false, "pince": saisie, "q": q_lisse[cote]}
			# on ne vise que la main levée, devant soi, et hors du menu de paume
			var devant := Vector2(base_i.x - h.x, base_i.z - h.z).length()
			if base_i.y > h.y - 0.55 and devant > 0.2 and not en_paume:
				p = {"id": cote, "o": base_i, "d": dir, "clic": pince[cote] and not avant_p, "appui": pince[cote], "bout": index, "doigt": true}
			var coul := MAIN_OR if pince[cote] else MAIN_BLEU
			for j in XRHandTracker.HAND_JOINT_MAX:
				if nb < NB_BILLES:
					mm_mains.set_instance_transform(nb, Transform3D(Basis.IDENTITY * 0.006, o * tr.get_hand_joint_transform(j).origin))
					mm_mains.set_instance_color(nb, coul)
					nb += 1
		else:
			pince[cote] = false
			q_lisse.erase(cote)
			t_pince.erase(cote)
			rayon.erase(cote)
			paume_vue[cote] = false
			var c: XRController3D = manettes[cote]
			if en_vr and c.get_has_tracking_data():
				var pc := c.global_position
				var v: XRController3D = viseurs[cote]
				var vise_ok := v.get_has_tracking_data()
				var vo := v.global_position if vise_ok else pc
				var vd := -(v.global_basis.z if vise_ok else c.global_basis.z).normalized()
				var tire := c.is_button_pressed("trigger_click") or c.get_float("trigger") > 0.55
				var serre := c.get_float("grip") > 0.5
				if tire and not gachette[cote]:
					clic_monde = cote
				m = {"id": cote, "pos": pc, "bout": pc, "manette": true, "tr": c.global_transform, "en_paume": false, "ouverte": false,
					"pince": serre, "q": c.global_basis.orthonormalized().get_rotation_quaternion()}
				p = {"id": cote, "o": vo, "d": vd, "clic": tire and not gachette[cote], "appui": tire, "bout": vo, "doigt": false}
				gachette[cote] = tire
				var joy := c.get_vector2("primary").y      # joystick : pousser agrandit, tirer réduit
				if absf(joy) > 0.2 and mode == "jeu" and voy == null:
					_zoom(pc, exp(joy * dt * 1.6))
					_relier(pc, dt)
				if nb < NB_BILLES:
					mm_mains.set_instance_transform(nb, Transform3D(Basis.IDENTITY * 0.016, pc))
					mm_mains.set_instance_color(nb, MAIN_OR if serre else MAIN_BLEU)
					nb += 1
		if not m.is_empty():
			mains.append(m)
		if not p.is_empty():
			pointeurs.append(p)
	if not en_vr:
		var mp := get_viewport().get_mouse_position()
		pointeurs.append({"id": "souris", "o": camera.project_ray_origin(mp), "d": camera.project_ray_normal(mp), "clic": souris_clic,
			"appui": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "bout": Vector3(0, -99, 0), "doigt": false})
		if souris_clic:
			clic_monde = "souris"
		souris_clic = false
	var g := mains.filter(func(x: Dictionary) -> bool: return x.pince)
	if g.size() == 2:
		for i in range(1, 24):
			if nb < NB_BILLES:
				mm_mains.set_instance_transform(nb, Transform3D(Basis.IDENTITY * 0.004, (g[0].pos as Vector3).lerp(g[1].pos, i / 24.0)))
				mm_mains.set_instance_color(nb, MAIN_OR)
				nb += 1
	# le rayon de chaque pointeur : un pointillé qui s'amenuise
	for p in pointeurs:
		if p.id == "souris":
			continue
		for i in range(1, 15):
			if nb < NB_BILLES:
				mm_mains.set_instance_transform(nb, Transform3D(Basis.IDENTITY * (0.0036 - 0.00016 * i), (p.o as Vector3) + (p.d as Vector3) * (0.06 + 0.07 * i)))
				mm_mains.set_instance_color(nb, MAIN_OR if p.appui else MAIN_BLEU)
				nb += 1
	mm_mains.visible_instance_count = nb


## Menu de paume : regarder sa paume ouverte fait apparaître quatre commandes, qu'on touche de l'autre main.
func _menu_paume(dt: float) -> void:
	var porteuse = null
	for m in mains:
		if m.en_paume:
			porteuse = m
			break
	p_paume.visible = porteuse != null and mode == "jeu"
	if not p_paume.visible:
		return
	var c: Vector3 = (porteuse.paume as Vector3) + (porteuse.doigts as Vector3) * 0.13 + (porteuse.normale as Vector3) * 0.03
	p_paume.global_transform = Transform3D(Basis.IDENTITY, c).looking_at(c + (c - _tete()), Vector3.UP)
	var autres := pointeurs.filter(func(q: Dictionary) -> bool: return q.id != porteuse.id)
	var id: String = p_paume.maj(autres, dt)
	if p_paume.survol != "":
		sur_panneau = true
	if id == "menu_bascule":
		menu_reduit = not menu_reduit
		sous_menu = ""
		epingles.erase(menu)
	elif id != "":
		_action(id)


## Balayage de la main ouverte pendant une visite : vers la gauche, étape suivante ; vers la droite, étape précédente.
func _balayage(dt: float) -> void:
	t_balayage = maxf(0.0, t_balayage - dt)
	var maintenant := Time.get_ticks_msec() * 0.001
	var droite := camera.global_basis.x
	for m in mains:
		var hist: Array = traces.get(m.id, [])
		if m.manette or not m.ouverte or m.en_paume or visite == null or tenu != null or visite.t < 3.0 or not visite.arrive or (m.paume as Vector3).y < _tete().y - 0.5:
			hist.clear()
			traces[m.id] = hist
			continue
		hist.append([maintenant, m.paume])
		while hist.size() > 1 and maintenant - float(hist[0][0]) > 0.35:
			hist.pop_front()
		traces[m.id] = hist
		if t_balayage > 0.0 or hist.size() < 4:
			continue
		var dv: Vector3 = (m.paume as Vector3) - (hist[0][1] as Vector3)
		var lateral := dv.dot(droite)
		var reste := (dv - droite * lateral).length()
		if absf(lateral) >= 0.28 and reste < 0.4 * absf(lateral):
			t_balayage = 2.0
			hist.clear()
			sons.jouer("clic")
			print("balayage de la main")
			_pas_visite(1 if lateral < 0.0 else -1)


## Manettes : A ou X parle au guide (ou passe l'introduction), B ou Y revient au corps, un clic sur le joystick recentre.
## Aucun bouton ne quitte l'application par accident.
func _bouton_manette(nom: String, _cote: String) -> void:
	if not actif or not place:
		return
	if mode == "intro":
		if nom == "ax_button" or nom == "by_button":
			intro.passer()
		elif nom == "primary_click":
			_recentrer()
		return
	if nom == "ax_button":
		_action("micro")
	elif nom == "by_button":
		_action("home")
	elif nom == "primary_click":
		_action("recentrer")
	elif nom == "menu_button":
		menu_reduit = not menu_reduit
		sous_menu = ""
		sons.jouer("clic")


func _vibrer(cote: String, force := 0.3) -> void:
	var c: XRController3D = manettes.get(cote)
	if c and en_vr and c.get_has_tracking_data():
		c.trigger_haptic_pulse("haptic", 0.0, force, 0.05, 0.0)


## Une saisie n'est prise en compte que si la main est près de l'objet, ou si son rayon le traverse.
func _a_portee(m: Dictionary) -> bool:
	if (m.pos as Vector3).distance_to(w_p) < maxf(w_s * 1.15, 0.25):
		return true
	for q in pointeurs:
		if q.id == m.id:
			var v: Vector3 = w_p - (q.o as Vector3)
			var t := v.dot(q.d)
			return t > 0.0 and (v - (q.d as Vector3) * t).length() < w_s
	return false


## Chaque image applique le petit mouvement des mains depuis l'image précédente, directement sur le monde.
func _gestes(dt: float) -> void:
	var g := mains.filter(func(x: Dictionary) -> bool: return x.pince and (tenu == null or x.id != tenu.id))
	if sur_panneau and prec == null:
		g = []      # on vise un bouton ou l'on tient un panneau : ce n'est pas une saisie du corps
	var cle := ""
	for m in g:
		cle += m.id
	if g.size() > 0 and (prec == null or prec.cle != cle):
		_interrompre()
		t_silence = 0.0
		sons.jouer("saisie")
		t_saisie = 0.0
		zoom_cumule = 0.0
		for m in g:
			_vibrer(m.id)
	if prec != null and prec.cle == cle and g.size() == 1:
		# une main : l'objet suit la main et tourne avec le poignet
		var dq := Basis((g[0].q as Quaternion) * (prec.q as Quaternion).inverse())
		if chemin.size() == 1:
			dq = Basis(Vector3.UP, dq.get_euler().y)      # un corps de 1,75 m ne bascule pas avec le poignet
		w_a = dq * w_a
		w_p = g[0].pos + dq * (w_p - prec.a)
		_relier(g[0].pos, dt)
		t_saisie += dt
		if t_saisie > 1.0:
			_evt("saisie")
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
		zoom_cumule += absf(log(k))
		if zoom_cumule > 0.3:
			_evt("zoom")
	if g.size() > 0:
		prec = {"cle": cle, "a": g[0].pos, "q": g[0].q, "b": g[1].pos if g.size() > 1 else Vector3.ZERO}
	else:
		prec = null


# ───────── viser, choisir, mettre en lumière ─────────

## Les panneaux visibles reçoivent les pointeurs ; un bouton activé déclenche son action. Une saisie qui commence sur
## la carte ou sur le bord du menu déplace ce panneau au lieu du corps.
func _interface(dt: float) -> void:
	sur_panneau = false
	var visibles: Array = []
	if menu.ouvert:
		var idm: String = menu.maj(pointeurs, dt)
		if menu.survol:
			sur_panneau = true
		if idm != "":
			_action(idm)
	if visite != null:
		visibles.append(p_visite)
	if tuto != null:
		visibles.append(p_tuto)
	for p in visibles:
		var id: String = p.maj(pointeurs, dt)
		if p.survol != "":
			sur_panneau = true
		if id != "":
			_action(id)
	# déplacement d'un panneau
	if tenu != null:
		var m = null
		for x in mains:
			if x.id == tenu.id and x.pince:
				m = x
		if m == null:
			epingles[tenu.p] = true
			tenu = null
		else:
			var dq := Basis((m.q as Quaternion) * (tenu.q as Quaternion).inverse())
			var c: Vector3 = (m.pos as Vector3) + dq * (tenu.ecart as Vector3)
			tenu.ecart = dq * (tenu.ecart as Vector3)
			tenu.q = m.q
			(tenu.p as Node3D).global_transform = Transform3D(Basis.IDENTITY, c).looking_at(c + (c - _tete()), Vector3.UP)
			sur_panneau = true
	elif prec == null:
		for m in mains:
			if not m.pince:
				continue
			var ptr = null
			for q in pointeurs:
				if q.id == m.id:
					ptr = q
			if ptr == null:
				continue
			for def in [[carte, Vector2(0.33, 0.25), true], [menu, Vector2(0.23, 0.25), menu.ouvert and menu.sur_poignee(pointeurs) == str(m.id)]]:
				if not def[2]:
					continue
				var touche = _vise_plan(def[0], def[1], ptr) if def[0] == carte else (def[0] as Node3D).global_position
				if touche != null:
					tenu = {"p": def[0], "id": m.id, "q": m.q, "ecart": (touche as Vector3) - (m.pos as Vector3)}
					sons.jouer("saisie")
					_vibrer(m.id)
					sur_panneau = true
					break
			if tenu != null:
				break


## Point (dans la pièce) où le pointeur touche un panneau rectangulaire, ou null. Une main posée tout près compte aussi.
func _vise_plan(p: Node3D, demi: Vector2, ptr: Dictionary):
	if not p.visible:
		return null
	var inv := p.global_transform.affine_inverse()
	var b: Vector3 = inv * (ptr.o as Vector3)
	if absf(b.z) < 0.1 and absf(b.x) < demi.x + 0.04 and absf(b.y) < demi.y + 0.04:
		return p.global_transform * Vector3(b.x, b.y, 0)
	var d: Vector3 = inv.basis * (ptr.d as Vector3)
	if absf(d.z) < 1e-4:
		return null
	var t := -b.z / d.z
	if t < 0.0 or t > 4.0:
		return null
	var hp := b + d * t
	if absf(hp.x) < demi.x and absf(hp.y) < demi.y:
		return p.global_transform * hp
	return null


func _visibilite() -> void:
	var jeu := mode == "jeu" and place
	monde.visible = jeu
	carte.visible = jeu
	var veut := jeu and not menu_reduit
	if veut != menu.ouvert:
		if veut:
			menu.ouvrir()
		else:
			menu.fermer()
	p_mini.visible = false
	p_visites.visible = false
	p_filtres.visible = false
	p_visite.visible = jeu and visite != null
	p_tuto.visible = jeu and tuto != null and visite == null
	bandeau.visible = jeu and ligne_guide != ""
	if not jeu:
		p_paume.visible = false
	if not jeu:
		halo.visible = false
		nom_vise.visible = false
		for l in aides:
			l.visible = false


# ───────── aide sur la main et tutoriel ─────────

const AIDE_MAIN := [["bout", "Pincer bref : choisir"], ["pouce", "Pincer et tenir : saisir"], ["poignet", "Deux mains : agrandir"]]
const AIDE_MANETTE := [[Vector3(0, 0.0, -0.06), "Index : viser, choisir"], [Vector3(0, -0.05, 0.03), "Majeur : saisir"],
	[Vector3(0, 0.05, -0.01), "Joystick : zoom · clic : recentrer"], [Vector3(0, 0.035, 0.04), "A/X : guide · B/Y : corps"]]

## Quand on regarde sa main (ou sa manette) un instant, les commandes s'y inscrivent.
func _aide_mains(dt: float) -> void:
	var h := _tete()
	var av := -camera.global_basis.z
	var n := 0
	for m in mains:
		var dv: Vector3 = (m.pos as Vector3) - h
		var dist := dv.length()
		var cosinus := dv.dot(av) / maxf(dist, 0.01)
		var t: float = t_regard.get(m.id, 0.0)
		# apparaît après une demi-seconde de regard, disparaît dès qu'on regarde nettement ailleurs ou qu'on agit
		if (m.en_paume if not m.manette else (dist < 0.65 and cosinus > (0.85 if t > 0.5 else 0.93))) and not m.pince and tenu == null:
			t += dt
		else:
			t = 0.0
		t_regard[m.id] = t
		if t <= (0.0 if not m.manette else 0.5) or t > 10.0:
			continue
		var lignes: Array = AIDE_MANETTE if m.manette else AIDE_MAIN
		for i in lignes.size():
			if n >= aides.size():
				break
			var l := aides[n]
			var p: Vector3 = (m.tr as Transform3D) * (lignes[i][0] as Vector3) if m.manette else (m[lignes[i][0]] as Vector3)
			l.text = lignes[i][1]
			l.pixel_size = maxf(dist, 0.2) * 0.026 / 64.0
			l.global_position = p + Vector3.UP * (0.022 + 0.004 * i) + camera.global_basis.x * (0.05 if m.id == "left" else -0.05)
			l.visible = true
			n += 1
	for i in range(n, aides.size()):
		aides[i].visible = false


const TUTO := [
	["Viser et choisir", "clic"], ["Saisir et tourner", "saisie"], ["Agrandir", "zoom"],
	["Se recentrer", "recentrer"], ["Parler au guide", "guide"], ["À toi de jouer", ""]]

func _lancer_tuto() -> void:
	_arreter_visite(false)
	sous_menu = ""
	tuto = {"i": -1, "t": 0.0, "fait": false}
	_etape_tuto(0)


func _etape_tuto(i: int) -> void:
	if i >= TUTO.size():
		_fin_tuto()
		return
	tuto.i = i
	tuto.t = 0.0
	tuto.fait = false
	cle_carte = ""
	p_tuto.libelle("tuto_suiv", "Suivante" if i < TUTO.size() - 1 else "Terminer")
	_dire(["p_tuto_%d" % i], "")


func _fin_tuto() -> void:
	tuto = null
	cle_carte = ""
	reglages["tuto_vu"] = true
	_enregistrer_reglages()
	_ligne("")


## Signale qu'une commande vient d'être réussie ; si c'est celle que le tutoriel attend, il passe à la suite.
func _evt(nom: String) -> void:
	if tuto != null and not tuto.fait and TUTO[tuto.i][1] == nom:
		tuto.fait = true
		tuto.t = 0.0
		sons.jouer("compris")
		cle_carte = ""


func _tuto(dt: float) -> void:
	tuto.t += dt
	if not tuto.fait and tuto.t > 30.0 and TUTO[tuto.i][1] != "":
		tuto.fait = true      # on ne reste jamais bloqué sur une étape
		tuto.t = 0.0
	if tuto.fait and tuto.t > 1.6 and not voix.parle():
		_etape_tuto(tuto.i + 1)
	elif TUTO[tuto.i][1] == "" and tuto.t > 4.0 and not voix.parle():
		_fin_tuto()


## Cherche l'enfant du niveau courant que le pointeur désigne. Le parcours est étalé sur quelques images pour rester
## léger. La cible tenue ne cède que devant une rivale nettement mieux visée, pour que l'anneau ne clignote pas.
func _viser() -> void:
	var nd := _courant()
	t_vise += dt_image
	if pointeurs.is_empty() or sur_panneau or prec != null or voy != null or visite != null or scan_n != chemin[-1].n:
		vise = -1
		scan_n = chemin[-1].n
		scan_k = 0
		scan_mieux = -1
		scan_score = 0.05
		return
	var av := -camera.global_basis.z
	var p: Dictionary = pointeurs[0]
	for q in pointeurs:
		if (q.d as Vector3).dot(av) > (p.d as Vector3).dot(av):
			p = q
	var inv := (w_a * _pose_couchee()).transposed()
	var o: Vector3 = (inv * ((p.o as Vector3) - w_p)) / w_s
	var d: Vector3 = inv * (p.d as Vector3)
	var fin := mini(nd.nk, scan_k + 450)
	var bout := nd.nk <= scan_k
	var k := scan_k
	while k < fin:
		var r := nd.kr[k]
		if r * w_s < 0.0024:      # triés par taille : le reste est trop petit pour être désigné
			bout = true
			break
		if masque != 0 and nd.ks.size() > k and nd.ks[k] >= 0 and (masque & (1 << nd.ks[k])) == 0:
			k += 1
			continue
		var sc := _ecart_vise(nd, k, o, d)
		if sc < scan_score:
			scan_score = sc
			scan_mieux = k
		k += 1
	scan_k = k
	if bout or k >= mini(nd.nk, 2200):
		var garde := false
		if vise >= 0 and vise < nd.nk and scan_mieux != vise:
			var tenue := _ecart_vise(nd, vise, o, d)
			garde = tenue < 0.07 and (scan_mieux < 0 or scan_score > 0.7 * tenue)
		if not garde and scan_mieux != vise:
			vise = scan_mieux
			t_vise = 0.0
		scan_k = 0
		scan_mieux = -1
		scan_score = 0.05


## Écart angulaire entre un rayon et un enfant (nul si le rayon le traverse) ; à écart égal, le plus proche gagne.
func _ecart_vise(nd: Noeud, k: int, o: Vector3, d: Vector3) -> float:
	var v := nd.kp[k] - o
	var t := v.dot(d)
	if t <= 0.0:
		return 9.0
	return maxf(0.0, (v - d * t).length() - nd.kr[k]) / t + t * w_s * 0.003


func _centre_enfant(k: int) -> Vector3:
	return w_p + (w_a * _pose_couchee() * _courant().kp[k]) * w_s


## Anneau et nom autour de l'élément visé.
func _maj_vise() -> void:
	var nd := _courant()
	if vise < 0 or vise >= nd.nk:
		halo.visible = false
		nom_vise.visible = false
		return
	var c := _centre_enfant(vise)
	var dist := maxf(0.05, c.distance_to(_tete()))
	var t := maxf(2.25 * nd.kr[vise] * w_s, 0.016 * dist)
	halo.global_transform = Transform3D(Basis.looking_at(c - _tete(), Vector3.UP).scaled(Vector3.ONE * t), c)
	halo.visible = true
	nom_vise.text = noeuds[nd.kk[vise]].nom
	nom_vise.pixel_size = dist * 0.014 / 64.0
	nom_vise.global_position = c + Vector3.UP * (t * 0.5 + 0.008 * dist)
	nom_vise.visible = true


## Un clic sur l'élément visé : le guide l'amène devant soi et le présente.
func _clic() -> void:
	if vise < 0 or vise >= _courant().nk or visite != null or t_vise < 0.12:
		return
	sons.jouer("compris")
	_vibrer(clic_monde, 0.5)
	proposition = -1
	_interrompre()
	dire_a_l_arrivee = tuto == null
	arrivee_du_visiteur = true
	_evt("clic")
	aller_enfant(vise)


## Projecteur : ce qu'on vise, ce vers quoi on voyage ou ce qu'on regarde reste lumineux, le voisinage s'estompe.
func _maj_projecteur() -> void:
	var nd := _courant()
	var f := Vector4.ZERO
	var k := -1      # viser ne change rien à la lumière : seul un voyage détache sa destination
	# Un objet qu'on vient de nous présenter (voyage, étape de visite) se détache nettement de son voisinage ; dès
	# qu'on le prend en main pour explorer, le voisinage revient : le monde d'où l'on vient ne doit pas disparaître.
	if voy != null or visite != null:
		presente = true
	elif prec != null:
		presente = false
	if voy != null:
		var route: Array = voy.route
		var prof := chemin.size() - 1
		if prof < route.size() and (prof == 0 or (chemin[prof].n == route[prof - 1].n and chemin[prof].k == route[prof - 1].k)) and int(route[prof].k) < nd.nk:
			k = route[prof].k
	if k >= 0:
		var c := _centre_enfant(k)
		f = Vector4(c.x, c.y, c.z, maxf(nd.kr[k] * w_s * 1.2, 0.02))
	elif chemin.size() > 1:
		f = Vector4(w_p.x, w_p.y, w_p.z, w_s * 1.08)
	var ret := move_toward(retrait_lum, RETRAIT if presente else RETRAIT_LIBRE, dt_image * 0.5)
	if f.is_equal_approx(foyer_lum) and is_equal_approx(ret, retrait_lum):
		return
	foyer_lum = f
	retrait_lum = ret
	for m in mats:
		m.set_shader_parameter("foyer", f)
		m.set_shader_parameter("retrait", ret)


## Étiquettes : le nom des plus gros éléments visibles du niveau courant, un seul par sorte.
func _maj_labels(dt: float) -> void:
	if not etiquettes:
		for l in labels:
			l.visible = false
		return
	var nd := _courant()
	var h := _tete()
	t_labels -= dt
	if t_labels <= 0.0 or labels_n != chemin[-1].n:
		t_labels = 0.3
		labels_n = chemin[-1].n
		labels_k.clear()
		var av := -camera.global_basis.z
		var vus := {}
		for k in mini(nd.nk, 400):
			var kn := nd.kk[k]
			if vus.has(kn):
				continue
			if masque != 0 and nd.ks.size() > k and nd.ks[k] >= 0 and (masque & (1 << nd.ks[k])) == 0:
				continue
			var dv := _centre_enfant(k) - h
			var dist := dv.length()
			if dv.dot(av) < 0.55 * dist or nd.kr[k] * w_s < 0.006 * dist:
				continue
			vus[kn] = true
			labels_k.append(k)
			if labels_k.size() >= labels.size():
				break
	for i in labels.size():
		var l := labels[i]
		if i >= labels_k.size() or labels_k[i] >= nd.nk or labels_k[i] == vise:
			l.visible = false
			continue
		var k: int = labels_k[i]
		var c := _centre_enfant(k)
		var dist := maxf(0.05, c.distance_to(h))
		l.text = noeuds[nd.kk[k]].nom
		l.pixel_size = dist * 0.015 / 64.0
		l.global_position = c + Vector3.UP * (nd.kr[k] * w_s + 0.006 * dist)
		l.visible = true


## Filtre d'affichage : seuls certains systèmes du corps restent lumineux.
func _regler_filtre(id: String, parler := true) -> void:
	var def = null
	for f: Dictionary in contenus.get("filtres", []):
		if str(f.id) == id:
			def = f
	filtre = id if def != null else "tout"
	_maj_masque()
	if parler and def != null:
		var t = def.get("texte", "")
		_dire(["f_%s_%d" % [id, niveau]], str(t.get(NIVEAUX[niveau], "")) if t is Dictionary else str(t))
	_maj_boutons()


func _bits(liste) -> int:
	var m := 0
	if liste is Array:
		for s in liste:
			m |= 1 << int(s)
	return m


## Pendant une visite, c'est l'étape qui décide de ce qui est mis en lumière ; sinon, le filtre choisi.
func _maj_masque() -> void:
	var m := 0
	var fl := 0.0
	if visite != null and visite.i >= 0:
		var e: Dictionary = contenus.visites[visite.v].etapes[visite.i]
		m = _bits(e.get("systemes", []))
		fl = float(e.get("flux", 0))
	else:
		for f: Dictionary in contenus.get("filtres", []):
			if str(f.id) == filtre:
				m = _bits(f.get("systemes", []))
				fl = float(f.get("flux", 0))
	masque = m
	flux = fl
	for mat in mats:
		mat.set_shader_parameter("masque", m)
		mat.set_shader_parameter("flux", fl)
	cle_calcul = ""


## Ramène ce qu'on regarde devant soi, où que l'on soit et quoi qu'on ait fait.
func _recentrer() -> void:
	_evt("recentrer")
	if mode == "intro":
		intro.placer(_tete(), _avant())
		return
	if chemin.size() == 1:
		var c := couche_cible
		_placer_devant()
		couche_cible = c
		couche = c
	else:
		var h := _tete()
		var f := _avant()
		voy = null
		prec = null
		w_p = Vector3(h.x + f.x * 0.85, maxf(0.95, h.y - 0.22), h.z + f.z * 0.85)
		if w_s > 0.6 or w_s < 0.25:
			w_s = 0.42
		_borner(w_p)
		_replacer_panneaux(true)


func _action(id: String) -> void:
	if id.begins_with("v:"):
		_lancer_visite(id.substr(2))
	elif id.begins_with("f:"):
		_regler_filtre(id.substr(2))
	elif id.begins_with("niveau:"):
		_regler_niveau(int(id.substr(7)))
		_decrire(["p_niveau_%d" % niveau])
	match id:
		"micro":
			if voix.micro:
				voix.couper_micro()
				_dire(["p_micro_coupe"], PHRASES.micro_coupe)
			else:
				voix.activer_micro(guide.vocabulaire())
		"visites":
			if visite != null:
				_arreter_visite(true)
			else:
				_lancer_visite("")
		"filtres":
			_arreter_visite(false)
			menu_reduit = false
			menu.aller_page(1)
		"retour":
			sous_menu = ""
		"etiquettes":
			etiquettes = not etiquettes
			_enregistrer_reglages()
		"niveau":
			_regler_niveau((niveau + 1) % NIVEAUX.size())
			_decrire(["p_niveau_%d" % niveau])
		"mixte":
			if _mixte(not mixte):
				mixte = not mixte
				_enregistrer_reglages()
			else:
				_dire(["p_mixte_absent"], PHRASES.mixte_absent)
		"recentrer":
			_recentrer()
		"home":
			_arreter_visite(false)
			voix.taire()
			_placer_devant()
			_evt("recentrer")
		"tuto":
			if tuto != null:
				_fin_tuto()
			else:
				_lancer_tuto()
		"tuto_suiv":
			voix.taire()
			_etape_tuto(tuto.i + 1)
		"tuto_fin":
			voix.taire()
			_fin_tuto()
		"reduire":
			menu_reduit = true
			sous_menu = ""
		"menu":
			menu_reduit = false
		"depart":
			_enregistrer_reglages()
			_ouvrir_intro(true)
		"exit":
			_enregistrer_reglages()
			get_tree().quit()
		"suiv":
			_pas_visite(1)
		"prec":
			_pas_visite(-1)
		"quitter":
			_arreter_visite(true)
	_maj_boutons()


# ───────── la carte ─────────

func _format_taille(m: float) -> String:
	if m <= 0.0:
		return ""
	var unites := [[1.0, "m"], [1e-2, "cm"], [1e-3, "mm"], [1e-6, "µm"], [1e-9, "nm"], [1e-12, "pm"], [1e-15, "fm"]]
	for u in unites:
		if m >= u[0] * 0.999:
			var v: float = m / u[0]
			return ("%d" % roundi(v) if v >= 10.0 else ("%.1f" % v).replace(".", ",").trim_suffix(",0")) + " " + u[1]
	return "moins de 1 fm"


## Texte d'un nœud au niveau d'explication demandé (textes du comité ; à défaut, la description d'origine).
func texte_de(ni: int, niv: int) -> String:
	var e = contenus.get("noeuds", {}).get(noeuds[ni].nom)
	if e is Dictionary and str(e.get(NIVEAUX[niv], "")) != "":
		return e[NIVEAUX[niv]]
	return noeuds[ni].desc


func note_de(ni: int) -> String:
	var e = contenus.get("noeuds", {}).get(noeuds[ni].nom)
	return str(e.get("note", "")) if e is Dictionary else ""


func _maj_carte() -> void:
	var nd := _courant()
	var cle := "%d|%d|%d|%s|%s|%s" % [chemin[-1].n, chemin.size(), niveau, str(visite.v) + str(visite.i) + str(visite.arrive) if visite != null else "",
		ligne_guide, str(tuto.i) + str(tuto.fait) if tuto != null else ""]
	if cle == cle_carte:
		return
	cle_carte = cle
	var lieu := ""
	var debut := maxi(0, chemin.size() - 4)      # les quatre derniers niveaux, sans couper un nom
	for i in range(debut, chemin.size()):
		lieu += ("  ›  " if lieu != "" else ("…  ›  " if debut > 0 else "")) + noeuds[chemin[i].n].nom
	carte_lieu.text = lieu
	carte_guide.text = ""
	bandeau_texte.text = ligne_guide
	if tuto != null and visite == null:
		carte_titre.text = TUTO[tuto.i][0]
		carte_cat.text = "TUTORIEL  ·  %d / %d" % [tuto.i + 1, TUTO.size()]
		carte_cat.modulate = OR
		carte_texte.text = PHRASES["tuto_%d" % tuto.i]
		carte_note.text = ""
		carte_guide.text = "Bravo !" if tuto.fait else ""
		return
	if visite != null and visite.arrive:
		var v: Dictionary = contenus.visites[visite.v]
		var etape: Dictionary = v.etapes[visite.i]
		carte_titre.text = etape.titre
		carte_cat.text = "%s  ·  %d / %d" % [str(v.titre).to_upper(), visite.i + 1, (v.etapes as Array).size()]
		carte_cat.modulate = OR
		carte_texte.text = etape.texte
		carte_note.text = ""
		return
	carte_titre.text = nd.nom
	var taille := _format_taille(nd.taille)
	carte_cat.text = nd.cat.to_upper() + ("  ·  " + taille if taille != "" else "")
	carte_cat.modulate = nd.couleur.lightened(0.25)
	carte_texte.text = texte_de(chemin[-1].n, niveau)
	carte_note.text = note_de(chemin[-1].n)


func _ligne(t: String) -> void:
	ligne_guide = t
	tenue_bandeau = 3.0


# ───────── le guide : écouter, comprendre, répondre ─────────

func _dire(cles: Array, sous_titre: String) -> void:
	_ligne(sous_titre)
	voix.dire(cles)


## Dit où l'on est, au niveau d'explication courant (précédé éventuellement d'une phrase d'annonce).
func _decrire(avant: Array = []) -> void:
	var ni: int = chemin[-1].n
	var cles := avant.duplicate()
	cles.append("n_%s_%d" % [cle_de(noeuds[ni].nom), niveau])
	_ligne("")
	voix.dire(cles)


func _regler_niveau(n: int) -> void:
	niveau = clampi(n, 0, NIVEAUX.size() - 1)
	guide.niveau = niveau
	_enregistrer_reglages()
	if menu != null:
		_maj_boutons()


func _etat_voix(e: String) -> void:
	if attente_nom and e in ["refuse", "absent"]:
		attente_nom = false
		intro.nom_refuse()
		return
	if mode == "intro":
		return      # pendant le menu de départ, le micro ne sert qu'à entendre le nom
	match e:
		"ecoute":
			_evt("guide")
			if tuto == null:
				_dire(["p_micro"], PHRASES.micro)
		"refuse":
			_dire(["p_micro_refuse"], PHRASES.micro_refuse)
		"absent":
			_dire(["p_micro_absent"], PHRASES.micro_absent)
	_maj_boutons()


## Une phrase a été entendue (ou tapée, dans l'aperçu sur ordinateur).
func _entendu(phrase: String) -> void:
	if attente_nom and mode == "intro":
		attente_nom = false
		intro.nom_entendu(phrase)
		return
	if not actif or mode != "jeu" or phrase.strip_edges() == "":
		return
	var avant := niveau
	var d: Dictionary = guide.comprendre(phrase, proposition >= 0)
	t_silence = 0.0
	# le guide en ligne attend une réponse à sa question, ou converse (mode incarné) : la phrase lui revient,
	# sauf si c'est une commande que le casque sait exécuter seul
	var pour_elle: bool = api.adresse != "" and (api.attend_reponse() or mode_guide == "incarne") and str(d.action) in ["rien", "libre", "oui", "non", "aide", "absent", "proposer"] and proposition < 0
	if pour_elle and phrase.strip_edges().split(" ", false).size() >= 2 or (pour_elle and api.attend_reponse()):
		d = {"action": "libre", "cible": -1, "cle": "question", "texte": ""}
	if d.action == "rien":
		return
	_interrompre()
	# guide en ligne branché : une vraie question lui revient, même si elle nomme un objet que le guide local connaît
	if api.disponible() and _est_question(phrase) and str(d.action) in ["aller", "decrire", "proposer", "absent", "aide", "libre"]:
		d = {"action": "libre", "cible": -1, "cle": "question", "texte": ""}
	var cle := str(d.get("cle", ""))
	print("guide : « ", phrase, " » → ", d.action, " ", noeuds[d.cible].nom if int(d.get("cible", -1)) >= 0 else cle)
	if d.action == "libre" and cle == "" and not (api.disponible() and (mode_guide == "incarne" or phrase.to_lower().contains("guide"))):
		return      # une conversation voisine, pas une demande : le guide ne s'en mêle pas
	sons.jouer("compris")
	_ligne("« " + phrase + " »")
	match d.action:
		"silence":
			voix.taire()
			_arreter_visite(false)
		"aller":
			proposition = -1
			_arreter_visite(false)
			if d.cible == chemin[-1].n:
				_decrire()
			else:
				dire_a_l_arrivee = true
				voix.dire(["p_emmene"])
				aller(d.cible, TAILLE_CORPS if d.cible == racine else 0.42)
		"proposer":
			proposition = d.cible
			t_proposition = 0.0
			_dire([d.cle, "p_proposer"], str(d.texte) + " " + PHRASES.proposer)
		"oui":
			var c := proposition
			proposition = -1
			dire_a_l_arrivee = true
			voix.dire(["p_emmene"])
			aller(c)
		"non":
			proposition = -1
			_dire(["p_refus"], PHRASES.refus)
		"decrire":
			_decrire()
		"niveau":
			if guide.niveau == avant:
				var bout := "max" if avant == NIVEAUX.size() - 1 else "min"
				_dire(["p_niveau_" + bout], PHRASES["niveau_" + bout])
			else:
				_regler_niveau(guide.niveau)
				_decrire(["p_niveau_%d" % niveau])
		"visite":
			_lancer_visite(cle)
		"suivant":
			_pas_visite(1)
		"precedent":
			_pas_visite(-1)
		"quitter_visite":
			_arreter_visite(true)
		"recentrer":
			_recentrer()
			_dire(["p_recentre"], PHRASES.recentre)
		"etiquettes":
			etiquettes = cle != "non"
			_dire(["p_etiquettes_oui" if etiquettes else "p_etiquettes_non"], PHRASES.etiquettes_oui if etiquettes else PHRASES.etiquettes_non)
		"filtre":
			_arreter_visite(false)
			_regler_filtre(cle if cle != "" else "tout")
		"retour":
			_arreter_visite(false)
			_placer_devant()
			_dire(["p_retour"], PHRASES.retour)
		"remonter":
			if chemin.size() > 1:
				_arreter_visite(false)
				dire_a_l_arrivee = true
				voix.dire(["p_remonter"])
				aller(chemin[-2].n, TAILLE_CORPS if chemin.size() == 2 else 0.42)
			else:
				_dire(["p_deja_haut"], PHRASES.deja_haut)
		"aide":
			_dire(["p_aide"], PHRASES.aide)
		"absent":
			_dire(["p_absent"], PHRASES.absent)
		"libre":
			# le mode en ligne (guide_api.gd) répondra ici aux questions libres ; en local, le guide dit ses limites
			if api.disponible():
				var lieu := PackedStringArray()
				for e in chemin:
					lieu.append(noeuds[e.n].nom)
				evenement_envoye = ""
				api.demander(_contexte({"question": phrase}))
				attente_api = true
				_ligne("Je réfléchis…")
				tenue_bandeau = 35.0
			else:
				_dire(["p_libre"], PHRASES.libre)
	# quelqu'un qui emploie de lui-même le vocabulaire savant reçoit des explications plus poussées, et inversement
	var s: int = guide.niveau_suggere()
	if s != niveau and d.action == "aller":
		_regler_niveau(s)
	_maj_boutons()


## Une question, et non une commande : elle interroge (pourquoi, comment, à quoi sert…) ou demande un récit.
func _est_question(phrase: String) -> bool:
	var p := " " + phrase.to_lower().replace("’", "'").replace("-", " ") + " "
	if p.split(" ", false).size() < 4:
		return false
	for mot in [" pourquoi ", " comment ", " combien ", " a quoi ", " à quoi ", " est ce que ", " qu'est ce ", " quel ", " quelle ", " quels ", " quelles ",
			" raconte ", " explique ", " parle moi ", " dis moi ", " surprends ", "?"]:
		if p.contains(mot):
			return true
	return false


## Réponse du mode en ligne (prototype) : une phrase du guide, puis des actions choisies par le modèle parmi une
## liste fermée (aller, filtre, noms, effet, visite écrite), ou une visite improvisée sur des objets existants.
## Le relais a déjà vérifié chaque cible ; on revérifie ici qu'elle existe dans ce corps.
func _reponse_api(r: Dictionary) -> void:
	attente_api = false
	_ligne(str(r.reponse))
	tenue_bandeau = 4.0 + 0.35 * str(r.reponse).split(" ").size()      # le temps de lire, même sans voix
	if str(r.get("audio", "")) != "":
		voix.dire_wav(str(r.audio))
	print("guide en ligne : ", (r.actions as Array).size(), " action(s)", ", visite improvisée" if r.visite != null else "")
	if int(r.niveau) != niveau:
		_regler_niveau(int(r.niveau))
	if r.visite != null:
		_jouer_impro(r.visite)
		return
	var fx: Array = []
	for a: Dictionary in r.actions:
		match str(a.type):
			"aller":
				var i := _indice(str(a.cible))
				if i >= 0 and i != chemin[-1].n and (i == racine or parent_de[i].x >= 0):
					_arreter_visite(false)
					proposition = -1
					aller(i, TAILLE_CORPS if i == racine else 0.42)
			"filtre":
				_arreter_visite(false)
				_regler_filtre(str(a.id), false)
			"etiquettes":
				etiquettes = bool(a.oui)
				_enregistrer_reglages()
			"effet":
				fx.append([str(a.cible), str(a.mode), float(a.cycles)])
			"visite":
				_lancer_visite(str(a.id))
	if visite == null:
		_effets(fx)
	_maj_boutons()


## Visite improvisée par le guide en ligne : jouée par le même moteur que les visites écrites, jamais enregistrée.
## Elle n'a pas de voix : son texte s'affiche sur la carte, marqué comme improvisé.
func _jouer_impro(v: Dictionary) -> void:
	_arreter_visite(false)
	var vs: Array = contenus.visites
	if not vs.is_empty() and str(vs[-1].id) == "impro":
		vs.pop_back()
	v["titre"] = "Improvisé par le guide · " + str(v.get("titre", ""))
	vs.append(v)
	sous_menu = ""
	menu_reduit = true
	proposition = -1
	visite = {"v": vs.size() - 1, "i": -1, "t": 0.0, "arrive": false, "calme": 0.0}
	_etape_visite(0)


func _accueil() -> void:
	_dire(["p_accueil"], PHRASES.accueil)


# ───────── visite guidée : une nuit de sommeil ─────────

## Lance la visite demandée ; sans précision, ouvre la liste des visites.
func _lancer_visite(id := "") -> void:
	var vs: Array = contenus.get("visites", [])
	var v := -1
	for i in vs.size():
		if str(vs[i].id) == id:
			v = i
	if v < 0 and vs.size() == 1:
		v = 0
	if v < 0:
		if not vs.is_empty():
			menu_reduit = false
			menu.aller_page(2)
			_dire(["p_visite_choix"], PHRASES.visite_choix)
		return
	if visite != null and visite.v == v and visite.i == 0 and visite.t < 6.0:
		return
	sous_menu = ""
	menu_reduit = true
	proposition = -1
	print("visite : ", vs[v].id)
	visite = {"v": v, "i": -1, "t": 0.0, "arrive": false, "calme": 0.0}
	voix.dire(["p_visite"])
	_etape_visite(0)


## Étape suivante (+1) ou précédente (−1), à la demande. Après la dernière étape, la visite se termine.
func _pas_visite(sens: int) -> void:
	if visite == null:
		return
	print("visite : étape ", visite.i, " ", "+1" if sens > 0 else "-1")
	var n: int = (contenus.visites[visite.v].etapes as Array).size()
	if visite.i + sens < 0:
		return
	if visite.i + sens >= n:
		_arreter_visite(true)
		return
	voix.taire()
	_etape_visite(maxi(0, visite.i + sens))


func _effets(liste: Array) -> void:
	for nd in noeuds:
		if not nd.fx.is_empty():
			nd.fx = []
			_maj_materiaux(nd)
	for e: Array in liste:
		var i := _indice(e[0])
		if i < 0:
			continue
		var mode: int = {"pulse": 1, "wave": 2, "noise": 3}.get(e[1], 0)
		var dir := Vector3(0, 0, 1)
		if e.size() > 3 and e[3] is Array:
			dir = Vector3(e[3][0], e[3][1], e[3][2])
		noeuds[i].fx = [mode, float(e[2]), float(e[4]) if e.size() > 4 else 3.0, dir]
		_maj_materiaux(noeuds[i])


func _etape_visite(i: int) -> void:
	var etape: Dictionary = contenus.visites[visite.v].etapes[i]
	visite.i = i
	visite.t = 0.0
	visite.calme = 0.0
	visite.arrive = false
	_effets(etape.get("effets", []))
	couche_cible = 1.0 if etape.get("couche", false) else 0.0
	_maj_masque()
	var cible := _indice(str(etape.cible))
	if cible < 0 or (cible != racine and parent_de[cible].x < 0):
		cible = racine      # objet absent de ce corps (organe de l'autre sexe) : on reste sur le corps entier
	aller(cible, float(etape.get("taille", TAILLE_CORPS if cible == racine else 0.42)), etape.get("angle", null))
	_maj_boutons()


func _arreter_visite(annoncer: bool) -> void:
	if visite == null:
		return
	visite = null
	_effets([])
	couche_cible = 0.0
	_maj_masque()
	if annoncer:
		voix.taire()
		_dire(["p_visite_fin"], PHRASES.visite_fin)
		aller(racine, TAILLE_CORPS)
	_maj_boutons()


## L'étape suivante arrive d'elle-même deux secondes après la fin du récit, sauf si l'on tient l'objet en main.
func _visite(dt: float) -> void:
	visite.t += dt
	if not visite.arrive:
		if visite.t > 30.0:      # le voyage n'a pas abouti : le récit commence quand même
			voy = null
			_arrive()
		return
	var fini: bool = (not voix.parle() and visite.t > 2.5) if voix.a_des_clips else visite.t > 14.0
	if str(contenus.visites[visite.v].id) == "impro" and str(contenus.visites[visite.v].etapes[visite.i].get("audio", "")) == "":      # pas de voix : on laisse le temps de lire
		fini = visite.t > 4.0 + 0.4 * str(contenus.visites[visite.v].etapes[visite.i].texte).split(" ").size()
	if fini and prec == null:
		visite.calme += dt
		if visite.calme > 2.0:
			_pas_visite(1)


# ───────── réglages conservés d'une séance à l'autre ─────────

func _lire_reglages() -> void:
	if FileAccess.file_exists("user://reglages.json"):
		var r = JSON.parse_string(FileAccess.get_file_as_string("user://reglages.json"))
		if r is Dictionary:
			reglages = r
	niveau = clampi(int(reglages.get("niveau", 1)), 0, NIVEAUX.size() - 1)
	mixte = bool(reglages.get("mixte", false))
	etiquettes = bool(reglages.get("etiquettes", false))
	mode_guide = str(reglages.get("mode", "descriptif"))
	nom_guide = str(reglages.get("nom", ""))
	tutoiement = bool(reglages.get("tutoiement", true))


func _enregistrer_reglages() -> void:
	reglages["niveau"] = niveau
	reglages["mixte"] = mixte
	reglages["etiquettes"] = etiquettes
	reglages["corps"] = corps
	reglages["mode"] = mode_guide
	reglages["nom"] = nom_guide
	reglages["tutoiement"] = tutoiement
	var f := FileAccess.open("user://reglages.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(reglages))


# ───────── introduction et menu de départ ─────────

## Quelques milliers de points d'un corps, pour que l'introduction puisse le dessiner.
func _silhouette(ni: int) -> PackedVector3Array:
	var nd := noeuds[ni]
	var pf := bin.slice(nd.pos_off, nd.pos_off + nd.n * 12).to_float32_array()
	var pas := maxi(1, nd.n / 7000)
	var v := PackedVector3Array()
	for i in range(0, nd.n, pas):
		v.append(Vector3(pf[3 * i], pf[3 * i + 1], pf[3 * i + 2]))
	return v


# ───────── le guide en ligne met en scène : des « temps » (une parole, un geste) joués l'un après l'autre ─────────

## Ce que le casque sait de la situation, transmis au guide pour qu'il parle de ce qui est réellement sous les yeux.
func _contexte(plus: Dictionary) -> Dictionary:
	var lieu: Array = []
	for e in chemin:
		lieu.append(noeuds[e.n].nom)
	var nd := _courant()
	var vis: Array = []
	for k in mini(nd.nk, 400):
		var nom := noeuds[nd.kk[k]].nom
		if not (nom in vis):
			vis.append(nom)
			if vis.size() >= 12:
				break
	plus.merge({"chemin": lieu, "niveau": niveau, "filtre": filtre, "visibles": vis, "vus": vus_seance.duplicate()})
	return plus


## Le guide prend la parole de lui-même (première rencontre, arrivée quelque part, long silence) — mode incarné seulement.
func _evenement(nom: String) -> void:
	if api.adresse == "" or not api.disponible() or mode_guide != "incarne":
		if nom == "arrivee":
			_decrire()
		elif nom == "debut":
			_accueil()
		return
	evenement_envoye = nom
	attente_api = true
	api.demander(_contexte({"evenement": nom}))


## Le visiteur reprend la parole ou la main : le guide s'interrompt.
func _interrompre() -> void:
	if temps_en_cours != null or not parcours_file.is_empty() or attente_api:
		api.annuler()
	parcours_file.clear()
	temps_en_cours = null
	attente_api = false
	halo_force = -1


func _temps_recu(t: Dictionary) -> void:
	print("guide : temps ", t.get("n", "?"), " « ", str(t.get("dit", "")).left(90), " » son ", str(t.get("audio", "")).length() / 1365, " Ko")
	attente_api = false
	parcours_file.append(t)
	if temps_en_cours == null:
		_temps_suivant()


func _temps_suivant() -> void:
	halo_force = -1
	if parcours_file.is_empty():
		temps_en_cours = null
		return
	var t: Dictionary = parcours_file.pop_front()
	temps_en_cours = t
	t_attente_temps = 0.0
	geste_fait = true
	t_silence = 0.0
	var dit := str(t.get("dit", ""))
	if dit != "":
		_ligne(dit)
		tenue_bandeau = 60.0 if bool(t.get("urgence", false)) else 4.0 + 0.35 * dit.split(" ").size()
	if str(t.get("audio", "")) != "":
		voix.dire_wav(str(t.audio))
	var g = t.get("geste", null)
	if not (g is Dictionary):
		return
	print("guide : geste ", g.get("type", "?"), " ", g.get("cible", g.get("filtre", g.get("enfant", ""))))
	match str(g.get("type", "")):
		"amener":
			var i := _indice(str(g.get("cible", "")))
			if i >= 0 and (i == racine or parent_de[i].x >= 0) and i != chemin[-1].n:
				_arreter_visite(false)
				geste_fait = false
				aller(i, float(g.taille) if g.get("taille") != null else (TAILLE_CORPS if i == racine else 0.42), g.get("angle", null))
		"corps":
			_arreter_visite(false)
			geste_fait = false
			aller(racine, TAILLE_CORPS, g.get("angle", null))
		"eclairer":
			_arreter_visite(false)
			_regler_filtre(str(g.get("filtre", "tout")), false)
			if int(g.get("flux", 0)) == 0:
				flux = 0.0
				for m in mats:
					m.set_shader_parameter("flux", 0.0)
		"animer":
			_effets([[str(g.get("cible", "")), str(g.get("mode", "pulse")), float(g.get("cycles", 1.0))]])
		"designer":
			var nd := _courant()
			for k in nd.nk:
				if noeuds[nd.kk[k]].nom == str(g.get("enfant", "")):
					halo_force = k
					break
		"noms":
			etiquettes = bool(g.get("oui", true))
			_enregistrer_reglages()
		"posture":
			couche_cible = 1.0 if bool(g.get("allonge", false)) else 0.0
		"visite":
			parcours_file.clear()
			temps_en_cours = null
			_lancer_visite(str(g.get("id", "")))
		"silence":
			t_attente_temps = -float(g.get("secondes", 2.0))
		"arreter":
			_arreter_visite(false)
			_effets([])
			parcours_file.clear()
	_maj_boutons()


## Passe au temps suivant quand la voix a fini et que le geste est accompli ; après un long silence, le guide incarné
## peut prendre l'initiative d'une parole.
func _parcours(dt: float) -> void:
	if temps_en_cours != null:
		if not geste_fait and voy == null:
			geste_fait = true      # le voyage a été interrompu ou n'a pas eu lieu : on ne reste pas bloqué
		if geste_fait and not voix.parle():
			t_attente_temps += dt
			var seuil := 0.4 + (float(temps_en_cours.get("secondes", 0.0)) if str(temps_en_cours.get("enchainer", "voix")) == "delai" else 0.0)
			if t_attente_temps > seuil:
				if not parcours_file.is_empty():
					_temps_suivant()
				elif str(temps_en_cours.get("enchainer", "voix")) != "visiteur" or t_attente_temps > 25.0:
					temps_en_cours = null
					halo_force = -1
		return
	t_silence += dt
	if t_silence > 40.0 and mode_guide == "incarne" and api.disponible() and visite == null and tuto == null and voy == null and not voix.parle() and voix.micro:
		t_silence = 0.0
		_evenement("silence")


func _parcours_fini(r: Dictionary) -> void:
	attente_api = false
	if r.has("niveau") and int(r.niveau) != niveau:
		_regler_niveau(int(r.niveau))
	if r.has("tutoiement") and bool(r.tutoiement) != tutoiement:
		tutoiement = bool(r.tutoiement)
		api.tutoiement = tutoiement
		_enregistrer_reglages()
	# le guide a choisi de se taire après une arrivée : le casque présente l'objet lui-même
	if evenement_envoye == "arrivee" and temps_en_cours == null and parcours_file.is_empty() and not voix.parle():
		_decrire()
	evenement_envoye = ""


## La présence du guide : elle se tient près de l'objet, écoute, réfléchit, parle, et accompagne l'objet qui arrive.
func _maj_presence(dt: float) -> void:
	var e := {"tete": _tete(), "avant": _avant(), "mode": mode_guide, "clair": 1.0 if mixte else 0.0}
	if mode == "jeu":
		e["objet"] = w_p
		e["rayon"] = minf(w_s, 0.6)
		if voix.parle():
			e["etat"] = "parle"
		elif attente_api:
			e["etat"] = "reflechit"
		elif voix.micro and t_partiel < 1.5:
			e["etat"] = "ecoute"
		else:
			e["etat"] = "repos"
		if voy != null:
			e["cible"] = voy.foyer
		elif halo_force >= 0 and halo_force < _courant().nk:
			e["etat"] = "montre"
			e["cible"] = _centre_enfant(halo_force)
	presence.maj(dt, e)


## Le visiteur veut dire le nom du guide à voix haute : on ouvre le micro, et la première phrase entendue sera ce nom.
func _ecouter_nom() -> void:
	attente_nom = true
	t_attente_nom = 0.0
	if not voix.micro:
		voix.activer_micro(guide.vocabulaire())


## `menu_seul` : on saute l'animation pour arriver directement aux choix (corps, public, démarrer).
func _ouvrir_intro(menu_seul: bool) -> void:
	if not ResourceLoader.exists("res://intro.gd"):
		_fin_intro({"corps": corps, "niveau": niveau})
		return
	_arreter_visite(false)
	voix.taire()
	sous_menu = ""
	mode = "intro"
	if intro == null:
		intro = load("res://intro.gd").new()
		add_child(intro)
		intro.termine.connect(_fin_intro)
		intro.touche.connect(func(_id: String) -> void: sons.jouer("clic"))
		intro.demande_nom.connect(_ecouter_nom)
	intro.visible = true
	intro.preparer(contenus.get("intro", []), voix, police,
		{"femme": _silhouette(int(racines.get("femme", racine))), "homme": _silhouette(int(racines.get("homme", racine)))},
		{"corps": corps, "niveau": niveau, "mode": mode_guide, "nom": nom_guide, "tutoiement": tutoiement, "en_ligne": api.adresse != ""})
	presence.disparaitre()
	intro.placer(_tete(), _avant())
	if menu_seul:
		intro.passer()


func _fin_intro(choix: Dictionary) -> void:
	mode = "jeu"
	if intro != null:
		intro.visible = false
	voix.taire()
	niveau = clampi(int(choix.get("niveau", niveau)), 0, NIVEAUX.size() - 1)
	mode_guide = str(choix.get("mode", mode_guide))
	nom_guide = str(choix.get("nom", nom_guide))
	tutoiement = bool(choix.get("tutoiement", tutoiement))
	attente_nom = false
	presence.apparaitre()
	api.mode = mode_guide
	api.nom = nom_guide
	api.tutoiement = tutoiement
	api.oublier()
	vus_seance.clear()
	_interrompre()
	_choisir_corps(str(choix.get("corps", corps)))
	_enregistrer_reglages()
	_placer_devant()
	_maj_masque()
	_maj_boutons()
	cle_carte = ""
	if bool(reglages.get("tuto_vu", false)):
		if mode_guide == "incarne" and api.disponible():
			_evenement("debut")
		else:
			_accueil()
	else:
		_lancer_tuto()


# ───────── boucle ─────────

var images := 0
var dt_image := 0.011
var avant_prec := Vector3(0, 0, -1)
var t_stable := 0.0
var t_vise := 0.0
var rayon := {}                     # mains : dernier rayon de visée (origine, direction lissée)
var paume_vue := {}
var t_paume := {}
var p_paume: Node3D
var traces := {}
var t_balayage := 0.0
var refus := {}                     # saisies commencées trop loin de l'objet : ignorées jusqu'au relâchement
var bandeau: Node3D                 # sous-titres du guide, sous l'objet
var bandeau_texte: Label3D
var t_bandeau := 0.0
var mode_guide := "descriptif"      # "descriptif" ou "incarne" : choisi au menu de départ
var nom_guide := ""                 # nom donné au guide par le visiteur
var tutoiement := true
var attente_nom := false            # le menu de départ attend qu'on dise le nom du guide
var t_attente_nom := 0.0
var presence: Node3D                # la présence lumineuse du guide
var parcours_file: Array = []        # temps (parole + geste) reçus du guide en ligne, en attente d'être joués
var temps_en_cours = null
var t_attente_temps := 0.0
var geste_fait := true
var halo_force := -1                # enfant que le guide désigne par l'anneau
var vus_seance: Array = []          # objets visités pendant la séance (mémoire transmise au guide)
var t_silence := 0.0
var evenement_envoye := ""
var arrivee_du_visiteur := false    # le voyage en cours vient d'un clic du visiteur
var t_essai_ligne := 0.0
var essai_ligne_dit := false
var attente_api := false            # une réponse du guide en ligne se prépare
var t_partiel := 9.0                # temps écoulé depuis la dernière parole entendue du visiteur
var tenue_bandeau := 3.0
var epingles := {}
var tenu = null                     # panneau tenu en main : {p, id, q, ecart}
var menu_reduit := true           # réduit par défaut : un bouton « Menu », ou la paume, le rappelle
var p_mini: Node3D
var p_tuto: Node3D
var tuto = null                     # tutoriel en cours : {i, t, fait}
var aides: Array[Label3D] = []
var t_regard := {}
var t_saisie := 0.0
var zoom_cumule := 0.0
var t_place := 0.0
var souris_clic := false
var scan_n := -1
var scan_k := 0
var scan_mieux := -1
var scan_score := 0.04
var labels_k: Array[int] = []
var labels_n := -1
var retrait_lum := RETRAIT_LIBRE
var presente := false               # l'objet courant vient d'être présenté (voyage, visite) et n'a pas encore été pris en main

func _process(dt: float) -> void:
	if essai or camera == null:
		return
	images += 1
	if OS.get_environment("GALAXIE_QUESTION") != "" and not en_vr:
		t_essai_ligne += dt
		if t_essai_ligne > 2.0 and mode == "intro":
			_fin_intro({"corps": corps, "niveau": niveau, "mode": "incarne", "nom": "Lune"})
		if t_essai_ligne > 4.0 and not essai_ligne_dit and mode == "jeu":
			essai_ligne_dit = true
			_entendu(OS.get_environment("GALAXIE_QUESTION"))
		if t_essai_ligne > 45.0:
			get_tree().quit()
	if "--photo" in OS.get_cmdline_user_args():      # captures d'écran automatiques, pour vérifier le rendu sans casque
		_photo()
	if not actif:
		return
	if en_vr and not place:
		_visibilite()
		var av0 := -camera.global_basis.z
		var calme := rad_to_deg(av0.angle_to(avant_prec)) / maxf(dt, 0.001) < 15.0 and av0.y > -0.34 and av0.y < 0.26
		avant_prec = av0
		t_place = t_place + dt if (_tete().y > 0.4 and calme) else 0.0
		if t_place > 1.0:
			# la tête est suivie depuis un instant : c'est seulement maintenant qu'on sait où est « devant »
			place = true
			_placer_devant()
			_ouvrir_intro(false)
		return
	dt_image = dt
	_adapter_budget(dt)
	_lire_mains(dt)
	_visibilite()
	t_partiel += dt
	_maj_presence(dt)
	if mode == "intro":
		if attente_nom:
			t_attente_nom += dt
			if t_attente_nom > 9.0:      # rien entendu : le menu reprend la main
				attente_nom = false
				intro.nom_entendu("")
		intro.maj(dt, pointeurs)
		return
	_interface(dt)
	_menu_paume(dt)
	_balayage(dt)
	# le sous-titre s'efface un moment après la fin de la phrase
	t_bandeau = 0.0 if (voix.parle() or ligne_guide == "") else t_bandeau + dt
	if t_bandeau > tenue_bandeau:
		_ligne("")
	if voy == null:
		_gestes(dt)
	else:
		prec = null      # pendant un voyage guidé, les mains ne déplacent rien : une saisie involontaire ne l'annule plus
	if clic_monde != "" and not sur_panneau:
		_clic()
	if voy != null:
		_voyage(dt)
	couche = lerpf(couche, couche_cible if chemin.size() == 1 else couche, 1.0 - exp(-dt * 2.2))
	if visite != null:
		_visite(dt)
	elif tuto != null:
		_tuto(dt)
	_parcours(dt)
	if proposition >= 0:
		t_proposition += dt
		if t_proposition > 25.0:
			proposition = -1
	_replacer_panneaux(false)
	_maj_carte()
	_viser()
	var memo_vise := vise
	if halo_force >= 0 and halo_force < _courant().nk:
		vise = halo_force
	_maj_vise()
	vise = memo_vise
	_maj_projecteur()
	_maj_labels(dt)
	_aide_mains(dt)
	sons.echelle(_courant().echelle)
	if fil != null and not fil.is_alive():
		fil.wait_to_finish()
		fil = null
		_appliquer()
	if fil == null:
		_lancer_calcul()
	if etu != null:
		_etude(dt)
	monde.transform = Transform3D(w_a * _pose_couchee() * w_s, w_p) * x_liste


func _exit_tree() -> void:
	if fil != null:
		fil.wait_to_finish()


# ───────── aperçu sur ordinateur (sans casque) : glisser pour tourner, molette pour zoomer, touches pour le guide ─────────

const FOYER := Vector3(0, 1.15, -0.95)

func _unhandled_input(ev: InputEvent) -> void:
	if en_vr or etu != null:      # pendant l'étude d'image, la souris ne doit rien déranger
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		souris_clic = true
	if mode != "jeu":
		if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
			intro.passer()
		return
	if ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		voy = null
		_zoom_foyer(1.25 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8, 0.05)
	elif ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		var dq := Basis(Vector3.UP, ev.relative.x * 0.006) * Basis(Vector3.RIGHT, ev.relative.y * 0.006)
		w_a = dq * w_a
		w_p = FOYER + dq * (w_p - FOYER)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_V: _action("visites")
			KEY_F: _action("filtres")
			KEY_E: _action("etiquettes")
			KEY_R: _action("recentrer")
			KEY_N: _action("niveau")
			KEY_H: _action("home")
			KEY_I: _action("depart")
			KEY_RIGHT: _pas_visite(1)
			KEY_LEFT: _pas_visite(-1)
			KEY_1: _entendu("montre-moi un neurone")
			KEY_2: _entendu("je veux voir l'ADN")
			KEY_3: _entendu("c'est quoi")
			KEY_4: _entendu("plus simple")
			KEY_5: _entendu("montre le sang")
			KEY_6: _entendu("oui")


func _zoom_foyer(k: float, dt: float) -> void:
	_zoom(FOYER, k)
	_relier(FOYER, dt)


func _photo() -> void:
	var dossier := "user://"
	if images == 2:
		camera.position = Vector3(0, 1.0, 1.1)      # recul, pour voir le corps en entier
		menu_reduit = false
	if images == 90:
		_regler_filtre("sang", false)
	if images == 180:
		_regler_filtre("nerfs", false)
	if images == 270:
		_regler_filtre("tout", false)
		etiquettes = true
		aller(_indice("Cœur"))
	if images == 900:
		etiquettes = false
		_lancer_visite("sang")
	if images in [85, 175, 265, 890, 1500]:
		get_viewport().get_texture().get_image().save_png(dossier + "photo%d.png" % images)
	if images == 1501:
		get_tree().quit()


# ───────── banc d'essai image (sans casque) : godot --xr-mode off --resolution 1500x1600 -- --etude[=nom] ─────────
# Une caméra aux paramètres optiques du Quest 3 (champ vertical 96°) parcourt une série de paliers et enregistre
# user://etude_<nom>_<nn>_<palier>.png, plus user://etude_<nom>.txt (points et objets affichés à chaque palier).

var etu = null      # {nom, pas: [...], i, t, reste, fait, foyer, journal}

func _arg_etude(args: PackedStringArray) -> String:
	for a in args:
		if a == "--etude":
			return "etude"
		if a.begins_with("--etude="):
			return "etude_" + a.substr(8)
	return ""


func _etude_debut(nom: String) -> void:
	_fin_intro({"corps": corps, "niveau": niveau})
	tuto = null
	AudioServer.set_bus_mute(0, true)
	camera.fov = 96.0
	camera.position = Vector3(0, 1.6, 0)
	_placer_devant()
	# l'image d'un œil du casque (1680 × 1760, champ vertical 96°), rendue hors écran : la fenêtre du PC est trop basse
	var vp := SubViewport.new()
	vp.size = Vector2i(1680, 1760)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	get_window().size = Vector2i(300, 314)      # la fenêtre ne sert plus qu'à faire tourner la boucle
	get_window().position = Vector2i(20, 40)
	var cam := Camera3D.new()
	cam.fov = 96.0
	cam.near = camera.near
	cam.far = camera.far
	vp.add_child(cam)
	cam.global_transform = camera.global_transform
	cam.current = true
	var pas: Array = []
	# corps entier, puis agrandissement autour du cœur (le corps reste à 1,25 m)
	pas.append({"nom": "corps_1m25", "faire": func() -> void: _placer_devant()})
	pas.append({"nom": "thorax_x1_2", "faire": func() -> void: _placer_devant(), "zoom": 1.2})
	for k: float in [1.5, 2.0, 3.0, 5.0, 8.0]:
		pas.append({"nom": "thorax_x%s" % str(k).replace(".", "_"), "zoom": k})
	# le geste réel : on a tiré le corps à soi (le cœur à 60 cm des yeux), puis on écarte les mains
	var proche := func() -> void:
		_placer_devant()
		w_p.z += 0.65
		w_p.y += 0.2
	pas.append({"nom": "proche_x1_5", "faire": proche, "zoom": 1.5})
	for k: float in [2.5, 4.0]:
		pas.append({"nom": "proche_x%s" % str(k).replace(".", "_"), "zoom": k})
	pas.append({"nom": "retour_corps", "faire": func() -> void: _placer_devant()})
	for nom_objet: String in ["Cœur", "Poumon", "Foie", "Cerveau", "Tissu cardiaque", "Cardiomyocyte", "Mitochondrie", "ATP synthase", "ATP", "Atome de carbone"]:
		pas.append({"nom": "voyage_" + cle_de(nom_objet), "faire": func() -> void: aller(_indice(nom_objet))})
	for e: Array in [["sang", 1], ["sang", 2], ["sang", 4], ["oxygene", 6], ["sang", 5], ["sang", 0]]:
		pas.append({"nom": "visite_%s_%d" % e, "visite": e})
	pas.append({"nom": "fin_corps", "faire": func() -> void:
		_arreter_visite(false)
		_placer_devant()})
	etu = {"nom": nom, "pas": pas, "i": -1, "t": 0.0, "reste": 0.0, "fait": 1.0, "foyer": Vector3.ZERO, "journal": "", "vp": vp}


func _etude(dt: float) -> void:
	budget = 260000.0      # budget fixe, pour des captures comparables
	carte.visible = false
	bandeau.visible = false
	p_visite.visible = false
	p_tuto.visible = false
	halo.visible = false
	nom_vise.visible = false
	etu.t += dt
	# on attend que l'action soit terminée, puis que le choix des nuages soit à jour
	if voy != null:
		for i in 5:      # temps accéléré : les voyages vers les atomes durent sinon une minute
			if voy != null:
				_voyage(dt)
		etu.t = 0.0
		return
	if absf(etu.reste) > 0.0005:
		var pas_z := clampf(etu.reste, -0.015, 0.015)
		etu.reste -= pas_z
		_zoom(etu.foyer, exp(pas_z))
		_relier(etu.foyer, 0.011)
		etu.t = 0.0
		return
	if etu.i >= 0 and (etu.pas[etu.i] as Dictionary).has("visite") and visite != null and not visite.arrive:
		return
	if etu.i >= 0 and etu.t < 1.2:
		return
	if etu.i >= 0:
		var p: Dictionary = etu.pas[etu.i]
		var img: Image = (etu.vp as SubViewport).get_texture().get_image()
		img.save_png("user://%s_%02d_%s.png" % [etu.nom, etu.i, p.nom])
		# le centre du regard, pixel pour pixel : c'est là qu'on juge le grain
		DirAccess.make_dir_absolute("user://centres")
		img.get_region(Rect2i(440, 480, 800, 800)).save_png("user://centres/%s_%02d_%s.png" % [etu.nom, etu.i, p.nom])
		var lieu := ""
		for e in chemin:
			lieu += " > " + noeuds[e.n].nom
		var objets := 0
		for mi in reserve:
			if mi.visible:
				objets += 1
		var ligne := "%02d %s |%s | échelle %.3f | objets %d | points %d | seuil %.0f px | densité %.2f | calcul %.0f ms | envoi %.1f ms | %d i/s" % [etu.i, p.nom, lieu, w_s, objets, nb_points, ouv_aff, dens_aff, t_calcul, t_appliquer, int(ips)]
		ligne += " | envoi moyen %.2f ms sur %d" % [t_appliquer_somme / maxi(1, nb_appliquer), nb_appliquer]
		t_calcul = 0.0
		t_appliquer = 0.0
		t_appliquer_somme = 0.0
		nb_appliquer = 0
		print(ligne)
		etu.journal += ligne + "\n"
		# détail du coût : les sortes d'objets qui pèsent le plus (nuages, puis amas)
		var parts := {}
		for it: Array in resultat[0]:
			var ndp := noeuds[it[0]]
			var est_amas: bool = it[1] >= ndp.lod_n.size()
			var cle_p := ("amas " if est_amas else "") + ndp.nom
			var nbp: int = (ndp.quartiers[(it[1] - ndp.lod_n.size()) / G_AMAS.size()][3] as Array).size() * G_AMAS[(it[1] - ndp.lod_n.size()) % G_AMAS.size()] if est_amas else ndp.lod_n[it[1]]
			var e2: Array = parts.get(cle_p, [0, 0])
			parts[cle_p] = [e2[0] + 1, e2[1] + nbp]
		var noms_p := parts.keys()
		noms_p.sort_custom(func(u: String, v: String) -> bool: return parts[u][1] > parts[v][1])
		var detail := "   "
		for i in mini(7, noms_p.size()):
			detail += " %s ×%d = %d ;" % [noms_p[i], parts[noms_p[i]][0], parts[noms_p[i]][1]]
		print(detail)
		etu.journal += detail + "\n"
	etu.i += 1
	if etu.i >= (etu.pas as Array).size():
		var f := FileAccess.open("user://%s.txt" % etu.nom, FileAccess.WRITE)
		f.store_string(etu.journal)
		f.close()
		get_tree().quit()
		etu = null
		return
	var q: Dictionary = etu.pas[etu.i]
	etu.t = 0.0
	if q.has("faire"):
		(q.faire as Callable).call()
	if q.has("visite"):
		var vs: Array = contenus.get("visites", [])
		for v in vs.size():
			if str(vs[v].id) == str(q.visite[0]):
				visite = {"v": v, "i": -1, "t": 0.0, "arrive": false, "calme": 0.0}
				_etape_visite(int(q.visite[1]))
	if q.has("zoom"):
		if q.has("faire"):      # début d'une série : le foyer est le cœur, là où le corps vient d'être placé
			var nd := _courant()
			etu.foyer = w_p + (w_a * nd.kp[_etude_enfant(nd, "Cœur")]) * w_s
			etu.fait = 1.0
		etu.reste = log(float(q.zoom) / float(etu.fait))
		etu.fait = float(q.zoom)


func _etude_enfant(nd: Noeud, nom: String) -> int:
	for k in nd.nk:
		if noeuds[nd.kk[k]].nom == nom:
			return k
	return 0


## Essai automatique (godot --headless -- --essai) : zoome sans s'arrêter, vérifie qu'on descend bien dans les niveaux,
## puis vérifie que le voyage guidé atteint chaque objet du modèle et que le guide comprend les demandes types.
func _essai() -> void:
	w_s = 0.5
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
	var ok := plus_profond >= 6 and chemin.size() == 1
	# voyage guidé vers chaque objet atteignable
	var rates := PackedStringArray()
	var plus_long := 0.0
	for cible in noeuds.size():
		if cible != racine and parent_de[cible].x < 0:
			continue
		aller(cible)
		var pas := 0
		while voy != null and pas < 6000:
			_voyage(0.016)
			pas += 1
		plus_long = maxf(plus_long, pas * 0.016)
		if voy != null or chemin[-1].n != cible:
			rates.append(noeuds[cible].nom)
			voy = null
	print("voyages : ", noeuds.size() - rates.size(), " réussis, plus long ", snappedf(plus_long, 0.1), " s", "" if rates.is_empty() else " | ratés : " + ", ".join(rates))
	ok = ok and rates.is_empty()
	# compréhension des demandes
	var cas := [["montre-moi un neurone", "aller", "Neurone"], ["je veux voir les mitochondries", "aller", "Mitochondrie"],
		["emmène-moi au cœur", "aller", "Cœur"], ["c'est quoi", "decrire", ""], ["plus simple", "niveau", ""],
		["montre-moi un os", "proposer", "Ostéon"], ["reviens au corps", "retour", ""], ["lance la visite", "visite", ""],
		["remonte", "remonter", ""], ["la tour Eiffel", "libre", ""], ["montre l'ADN", "aller", "ADN"], ["silence", "silence", ""]]
	for c: Array in cas:
		var d := guide.comprendre(c[0])
		var bon: bool = d.action == c[1] and (c[2] == "" or (d.cible >= 0 and noeuds[d.cible].nom == c[2]))
		if not bon:
			print("guide : « ", c[0], " » → ", d.action, " ", noeuds[d.cible].nom if d.cible >= 0 else "", " (attendu ", c[1], " ", c[2], ")")
			ok = false
	print("ESSAI ", "OK" if ok else "ÉCHEC", " — profondeur atteinte : ", plus_profond)
	get_tree().quit(0 if ok else 1)


## Écrit la liste de tout ce que le guide peut dire (identifiant du clip → texte), pour fabriquer les enregistrements.
func _exporter_textes() -> void:
	var t := {}
	for cle: String in PHRASES:
		t["p_" + cle] = PHRASES[cle]
	for ni in noeuds.size():
		for niv in NIVEAUX.size():
			t["n_%s_%d" % [cle_de(noeuds[ni].nom), niv]] = texte_de(ni, niv)
	for p: Array in guide.proche:
		t[p[3]] = "Le modèle ne contient pas %s. Ce qui s'en rapproche le plus : %s." % [p[2], noeuds[p[1]].nom]
	for v: Dictionary in contenus.get("visites", []):
		for i in (v.etapes as Array).size():
			var titre: String = v.etapes[i].titre
			t["v_%s_%d" % [v.id, i]] = titre + ("" if titre.ends_with("?") or titre.ends_with("!") else ".") + " " + str(v.etapes[i].texte)
	for f: Dictionary in contenus.get("filtres", []):
		var tx = f.get("texte", "")
		for niv in NIVEAUX.size():
			t["f_%s_%d" % [f.id, niv]] = str(tx.get(NIVEAUX[niv], "")) if tx is Dictionary else str(tx)
	var seq: Array = contenus.get("intro", [])
	for i in seq.size():
		t["intro_%d" % i] = str(seq[i].texte)
	var chemin_sortie := "res://voix/textes.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://voix"))
	var f := FileAccess.open(chemin_sortie, FileAccess.WRITE)
	f.store_string(JSON.stringify(t, "\t"))
	print("textes : ", t.size(), " → ", chemin_sortie)

