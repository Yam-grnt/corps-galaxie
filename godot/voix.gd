extends Node
## La voix du guide, en mode local : rien ne sort du casque.
##
## Parler : des enregistrements faits à la fabrication (voix/clips/<identifiant>.wav), validés mot pour mot par le
## comité scientifique. Le casque ne synthétise rien.
## Écouter : reconnaissance vocale embarquée (extension Android « GalaxieVoix », moteur sherpa-onnx, modèle français
## en dictée libre). Elle rend ce qu'elle entend tel quel, fautes comprises ; le vocabulaire du projet lui est transmis
## pour qu'elle le favorise, et c'est guide.gd qui rapproche ce texte de ce qu'il connaît.
## Pendant que le guide parle, le micro est en pause : il ne s'écoute pas lui-même. Quand l'application passe en
## arrière-plan, l'extension rend le micro au système et le reprend au retour.
## Sur un appareil sans cette extension (ordinateur, autre casque), le guide parle mais n'écoute pas :
## on le commande alors par les boutons.

signal entendu(texte: String)      # une phrase complète a été reconnue
signal partiel(texte: String)      # reconnaissance en cours
signal etat(e: String)             # "ecoute", "coupe", "refuse", "absent"
signal parole(en_cours: bool)      # le guide commence ou finit de parler

var micro := false                 # l'utilisateur a activé le micro
var a_des_clips := false
var _lecteur: AudioStreamPlayer
var _file: Array = []
var _parle := false
var _ext = null                    # extension Android, si présente
var _pret := false
var _attend_permission := false
var _suspendu := false
var _vocabulaire := "[]"


func _ready() -> void:
	_lecteur = AudioStreamPlayer.new()
	_lecteur.volume_db = 2.0
	add_child(_lecteur)
	_lecteur.finished.connect(_suite)
	a_des_clips = ResourceLoader.exists("res://voix/clips/p_accueil.wav")
	if Engine.has_singleton("GalaxieVoix"):
		_ext = Engine.get_singleton("GalaxieVoix")
		_ext.connect("pret", _sur_pret)
		_ext.connect("partiel", func(t: String) -> void: if t != "": partiel.emit(t))
		_ext.connect("entendu", _sur_entendu)
		_ext.connect("erreur", _sur_erreur)
		get_tree().on_request_permissions_result.connect(_sur_permission)


# ───────── parler ─────────

## Dit une suite d'enregistrements. Par défaut, ce qui était en cours est interrompu ; `a_la_suite` l'ajoute à la file.
func dire(cles: Array, a_la_suite := false) -> void:
	if not a_la_suite:
		_file.clear()
		_lecteur.stop()
	_file.append_array(cles)
	if not _lecteur.playing:
		_suite()


func taire() -> void:
	_file.clear()
	_lecteur.stop()
	_fin_parole()


func parle() -> bool:
	return _parle


func _suite() -> void:
	while not _file.is_empty():
		var element = _file.pop_front()
		var son: AudioStream = element if element is AudioStream else null
		if son == null and ResourceLoader.exists("res://voix/clips/%s.wav" % element):
			son = load("res://voix/clips/%s.wav" % element)
		if son != null:
			_lecteur.stream = son
			_lecteur.play()
			if not _parle:
				_parle = true
				parole.emit(true)
				if _ext and _pret:
					_ext.pause(true)      # le micro ne doit pas entendre le guide
			return
	_fin_parole()


## Dit un son reçu du guide en ligne (fichier WAV 16 bits encodé en base 64). Renvoie faux s'il est illisible.
func dire_wav(base64: String, a_la_suite := false) -> bool:
	var o := Marshalls.base64_to_raw(base64)
	if o.size() < 64 or o.slice(0, 4).get_string_from_ascii() != "RIFF":
		return false
	var p := 12
	var debut := -1
	var taille := 0
	while p + 8 <= o.size():      # on cherche le bloc « data »
		var nom := o.slice(p, p + 4).get_string_from_ascii()
		var n := o.decode_u32(p + 4)
		if nom == "data":
			debut = p + 8
			taille = mini(n, o.size() - debut)
			break
		p += 8 + n + (n % 2)
	if debut < 0 or taille <= 0:
		return false
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.stereo = o.decode_u16(22) == 2
	s.mix_rate = o.decode_u32(24)
	s.data = o.slice(debut, debut + taille)
	dire([s], a_la_suite)
	return true


func _fin_parole() -> void:
	if _parle:
		_parle = false
		parole.emit(false)
		if _ext and _pret and micro and not _suspendu:
			_ext.pause(false)


# ───────── écouter ─────────

func activer_micro(vocabulaire: PackedStringArray) -> void:
	if _ext == null:
		etat.emit("absent")
		return
	_vocabulaire = JSON.stringify(Array(vocabulaire))      # mots à favoriser : noms des objets et synonymes
	if OS.request_permission("RECORD_AUDIO"):
		_demarrer()
	else:
		_attend_permission = true


func couper_micro() -> void:
	micro = false
	if _ext:
		_ext.arreter()
	etat.emit("coupe")


func _sur_permission(permission: String, accordee: bool) -> void:
	if not _attend_permission or not permission.ends_with("RECORD_AUDIO"):
		return
	_attend_permission = false
	if accordee:
		_demarrer()
	else:
		etat.emit("refuse")


func _demarrer() -> void:
	micro = true
	if _pret:
		_sur_pret()
	else:
		_ext.preparer(_vocabulaire)      # charge le modèle (quelques secondes, sans bloquer l'image), puis émet « pret »


func _sur_pret() -> void:
	_pret = true
	if micro and _ext.ecouter(_vocabulaire):
		if _parle or _suspendu:
			_ext.pause(true)      # le guide est en train de parler, ou le casque est retiré : on n'écoute qu'après
		etat.emit("ecoute")
	elif micro:
		micro = false
		etat.emit("refuse")


func _sur_entendu(t: String) -> void:
	var propre := t.strip_edges()
	if propre != "" and not _parle and not _suspendu:
		entendu.emit(propre)


## Le micro a été perdu en cours de route (pris par une autre application, permission retirée…) ou le modèle est illisible.
func _sur_erreur(message: String) -> void:
	push_warning("voix : " + message)
	if micro and (message.begins_with("micro") or message.begins_with("modele")):
		micro = false
		_ext.arreter()
		etat.emit("refuse")


## Casque retiré ou menu système ouvert : on se tait et on n'écoute plus.
func suspendre(oui: bool) -> void:
	_suspendu = oui
	if oui:
		taire()
	if _ext and _pret and micro:
		_ext.pause(oui)
