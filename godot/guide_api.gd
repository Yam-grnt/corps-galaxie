extends Node
## Guide en ligne — client du relais v2 (serveur/relais.mjs). PROTOTYPE DE TEST, inactif tant qu'aucune adresse n'est réglée.
##
## Le casque n'envoie que du TEXTE (la phrase entendue ou un événement, le lieu, ce qu'on a sous les yeux, le mode, le
## nom donné à la guide) ; aucun son ne quitte le casque. La réponse est un PARCOURS : une suite de « temps » que le
## relais rend au fil de l'eau, pendant que le modèle écrit la suite. Chaque temps arrive par le signal `temps` :
##   n          int     rang (1, 2, 3…)
##   dit        String  ce que dit la guide (peut être vide)
##   audio      String  le même texte en WAV base 64 (voix.dire_wav) ; vide si la voix est coupée ou si `langue` est là
##   geste      Dictionary ou null — au plus un geste à exécuter EN MÊME TEMPS que la voix :
##                {"type":"amener","cible","taille","angle"}      amener un objet (aller)
##                {"type":"corps","angle"}                        revenir au corps entier
##                {"type":"eclairer","filtre","systemes","flux"}  n'éclairer qu'un système (flux 0 = lumière fixe)
##                {"type":"animer","cible","mode","cycles"}       pulse / wave / noise
##                {"type":"designer","enfant"}                    anneau sur un enfant de l'objet courant
##                {"type":"noms","oui"}  {"type":"posture","allonge"}  {"type":"visite","id"}
##                {"type":"silence","secondes"}  {"type":"arreter"}
##   enchainer  String  "voix" (temps suivant quand la voix a fini ET le geste est accompli), "delai" (+ `secondes`),
##                      "visiteur" (dernier temps : la guide a posé une question, la parole est au visiteur)
##   urgence    bool    (rare) orientation vers les secours : à afficher en grand, proposer d'ôter le casque
##   langue     String  (rare) la guide a répondu dans une autre langue : pas de son, afficher le texte
## Puis `fini(resume)` : niveau, sources, attend_visiteur, urgence, tutoiement, ignore (la phrase n'était pas pour la
## guide), dit (tout le texte du parcours), verif, mesure — ou {"annule":true}, {"tu":motif} (elle a choisi de se taire),
## {"erreur":…} (relais perdu en cours de route : ce qui a été dit reste dit).
## `echec(raison)` : rien n'a pu être joué ("inactif", "reseau", "quota", "serveur") → retomber sur le guide local.
##
## Pour l'essayer : lancer le relais sur le PC (serveur/LISEZ-MOI.md), « adb reverse tcp:8787 tcp:8787 », écrire
## {"relais": "http://127.0.0.1:8787/guide"} dans user://reglages.json, permission INTERNET à l'export.

signal temps(t: Dictionary)
signal fini(resume: Dictionary)
signal echec(raison: String)
signal reponse(resultat: Dictionary)      # ancien format d'un bloc, pour un main.gd pas encore rebranché (voir _ancien)

const GESTES := ["amener", "corps", "eclairer", "animer", "designer", "noms", "posture", "visite", "silence", "arreter"]
const MEMOIRE := 6      # échanges gardés en mémoire vive (jamais écrits sur le casque)

var adresse := ""            # http://…/guide
var mode := "incarne"        # choix du menu : "descriptif" ou "incarne"
var nom := ""                # nom donné à la guide par le visiteur (vide : aucun)
var tutoiement := true       # réglage persistant ; le relais le passe à false s'il entend le visiteur vouvoyer

var _http: HTTPRequest
var _http_annuler: HTTPRequest
var _occupe := false
var _tour := 0               # numéro de la demande en cours : une réponse d'un tour abandonné est ignorée
var _id := ""
var _recus := 0
var _question := ""
var _dits: PackedStringArray = []
var _lot: Array = []         # temps du parcours en cours (pour l'ancien format)
var _historique: Array = []
var _seance: Dictionary = {} # état de séance tenu par le relais et renvoyé tel quel : mémoire, proposition, signaux


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 30.0      # une attente longue sur /suite dure 15 s au plus
	add_child(_http)
	_http.request_completed.connect(_recu)
	_http_annuler = HTTPRequest.new()
	_http_annuler.timeout = 5.0
	add_child(_http_annuler)


func disponible() -> bool:
	return adresse != ""


## Un parcours est-il en cours de réception ?
func occupe() -> bool:
	return _occupe


## La guide vient de poser une question et attend la réponse : la prochaine phrase entendue lui revient, quelle qu'elle soit.
func attend_reponse() -> bool:
	return str(_seance.get("proposition", "")) != ""


## Demande un parcours. `contexte` : question (String) OU evenement ("debut", "arrivee", "retour_corps", "silence",
## "fin"), chemin (noms, du corps à l'endroit courant), niveau (0-2), filtre (id), visibles (noms des principaux
## enfants de l'objet courant), vus (objets visités pendant la séance), temps_restant_s (facultatif). `mode`, `nom`
## et `tutoiement` sont pris dans les variables ci-dessus s'ils ne sont pas donnés.
## (Ancienne forme encore acceptée : demander(question, chemin, niveau, filtre).)
func demander(contexte, chemin = null, niveau := 1, filtre := "tout") -> void:
	if contexte is String:
		contexte = {"question": contexte, "chemin": chemin if chemin != null else [], "niveau": niveau, "filtre": filtre}
	if adresse == "" or not (contexte is Dictionary):
		echec.emit("inactif")
		return
	if _occupe:
		annuler()
	_tour += 1
	_occupe = true
	_id = ""
	_recus = 0
	_dits = PackedStringArray()
	_lot = []
	_question = str(contexte.get("question", ""))
	var corps: Dictionary = {"mode": mode, "nom": nom, "tutoiement": tutoiement}
	corps.merge(contexte, true)
	corps.merge({"protocole": 2, "appareil": OS.get_unique_id(), "historique": _historique, "seance": _seance}, true)
	if _http.request(adresse, ["content-type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(corps)) != OK:
		_abandon("reseau")


## Le visiteur reprend la parole ou la main : on abandonne la suite du parcours (aucun signal n'est émis ensuite).
## Ce qui a déjà été dit reste dans la mémoire de la conversation.
func annuler() -> void:
	if not _occupe:
		return
	_tour += 1
	_occupe = false
	_http.cancel_request()
	if _id != "" and _http_annuler.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_http_annuler.request(adresse.trim_suffix("/guide") + "/annuler", ["content-type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"id": _id}))
	_noter()


## Efface la mémoire de la conversation (changement d'utilisateur, retour au menu).
func oublier() -> void:
	annuler()
	_historique.clear()
	_seance = {}


func _noter() -> void:
	var r := " ".join(_dits)
	if _question == "" and r == "":
		return
	_historique.append({"q": _question, "r": r})
	while _historique.size() > MEMOIRE:
		_historique.pop_front()


func _abandon(raison: String) -> void:
	_occupe = false
	if _recus > 0:      # le relais s'est tu en cours de route : ce qui a été dit reste dit
		_noter()
		fini.emit({"erreur": raison, "attend_visiteur": false, "dit": " ".join(_dits)})
	else:
		echec.emit(raison)


func _recu(resultat: int, code: int, _entetes: PackedStringArray, corps: PackedByteArray) -> void:
	var tour := _tour
	if not _occupe:
		return
	if resultat != HTTPRequest.RESULT_SUCCESS:
		_abandon("reseau")
		return
	if code == 429:
		_abandon("quota")
		return
	var r = JSON.parse_string(corps.get_string_from_utf8())
	if code != 200 or not (r is Dictionary) or not (r.get("temps", null) is Array):
		_abandon("serveur")
		return
	if r.has("id"):
		_id = str(r.id)
	for brut in r.temps:
		var t := _nettoyer(brut)
		if t.is_empty():
			continue
		_recus += 1
		if t.dit != "":
			_dits.append(t.dit)
		_lot.append(t)
		temps.emit(t)
		if tour != _tour:      # celui qui écoute a annulé ou relancé pendant le signal
			return
	if bool(r.get("fini", false)):
		_occupe = false
		var resume: Dictionary = r.get("resume", {}) if r.get("resume", null) is Dictionary else {}
		if resume.get("seance", null) is Dictionary:
			_seance = resume.seance
		if resume.has("tutoiement"):
			tutoiement = bool(resume.tutoiement)
		resume["dit"] = " ".join(_dits)
		_noter()
		fini.emit(resume)
		_ancien(resume)
	elif _http.request("%s/suite?id=%s&apres=%d" % [adresse.trim_suffix("/guide"), _id.uri_encode(), _recus]) != OK:
		_abandon("reseau")


## Le relais a déjà tout validé ; on ne garde ici que ce que le contrat prévoit, avec les bons types
## (JSON rend tous les nombres en flottants).
func _nettoyer(b) -> Dictionary:
	if not (b is Dictionary):
		return {}
	var geste = b.get("geste", null)
	if not (geste is Dictionary and str(geste.get("type", "")) in GESTES):
		geste = null
	var enchainer := str(b.get("enchainer", "voix"))
	var t := {"n": int(b.get("n", _recus + 1)), "dit": str(b.get("dit", "")), "audio": str(b.get("audio", "")), "geste": geste,
		"enchainer": enchainer if enchainer in ["voix", "delai", "visiteur"] else "voix", "secondes": clampf(float(b.get("secondes", 0.0)), 0.0, 8.0),
		"urgence": bool(b.get("urgence", false)), "langue": str(b.get("langue", ""))}
	if t.dit == "" and geste == null:
		return {}
	return t


## Compatibilité avec un main.gd d'avant la v2, qui n'écoute que `reponse` : il reçoit le parcours d'un bloc, à l'ancien
## format (texte entier, premières actions traduisibles, son du premier temps seulement). À retirer une fois main.gd
## branché sur `temps` / `fini`.
func _ancien(resume: Dictionary) -> void:
	if reponse.get_connections().is_empty() or not temps.get_connections().is_empty() or _lot.is_empty():
		return
	var actions: Array = []
	for t: Dictionary in _lot:
		if t.geste == null or actions.size() >= 3:
			continue
		match str(t.geste.type):
			"amener": actions.append({"type": "aller", "cible": t.geste.cible})
			"corps": actions.append({"type": "aller", "cible": "Corps humain"})
			"eclairer": actions.append({"type": "filtre", "id": t.geste.filtre})
			"noms": actions.append({"type": "etiquettes", "oui": t.geste.oui})
			"animer": actions.append({"type": "effet", "cible": t.geste.cible, "mode": t.geste.mode, "cycles": t.geste.cycles})
			"visite": actions.append({"type": "visite", "id": t.geste.id})
	reponse.emit({"reponse": str(resume.get("dit", "")), "actions": actions, "visite": null, "niveau": clampi(int(resume.get("niveau", 1)), 0, 2),
		"hors_sujet": false, "sources": resume.get("sources", []), "reste": int(resume.get("reste", -1)), "audio": str(_lot[0].audio)})
