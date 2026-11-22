extends Node
## Le paysage sonore : une nappe par échelle (corps, cellule, protéine, atome, noyau), fondues l'une dans l'autre
## quand on change de niveau, et de petits sons d'interaction. Tous les sons sont fabriqués par programme
## (outils/fabriquer-sons.js) ; s'ils manquent, l'application reste simplement silencieuse.

const NAPPES := 5
const FORT := -15.0        # volume d'une nappe active, en décibels
const SOUS_LA_VOIX := -9.0

var _nappes: Array[AudioStreamPlayer] = []
var _effets := {}
var _echelle := -1
var _baisse := false
var _suspendu := false


func _ready() -> void:
	for i in NAPPES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -60.0
		var chemin := "res://sons/nappe_%d.wav" % i
		if ResourceLoader.exists(chemin):
			var w := load(chemin) as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
			p.stream = w
		add_child(p)
		_nappes.append(p)
	for nom in ["saisie", "entree", "sortie", "clic", "compris"]:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		var chemin := "res://sons/%s.wav" % nom
		if ResourceLoader.exists(chemin):
			p.stream = load(chemin)
		add_child(p)
		_effets[nom] = p


func jouer(nom: String) -> void:
	var p: AudioStreamPlayer = _effets.get(nom)
	if p and p.stream and not _suspendu:
		p.play()


func echelle(e: int) -> void:
	_echelle = clampi(e, 0, NAPPES - 1)


func baisser(oui: bool) -> void:
	_baisse = oui


func suspendre(oui: bool) -> void:
	_suspendu = oui


func _process(dt: float) -> void:
	for i in NAPPES:
		var p := _nappes[i]
		if p.stream == null:
			continue
		var cible := -60.0
		if i == _echelle and not _suspendu:
			cible = FORT + (SOUS_LA_VOIX if _baisse else 0.0)
		p.volume_db = lerpf(p.volume_db, cible, 1.0 - exp(-dt * 1.6))
		if p.volume_db > -55.0 and not p.playing:
			p.play()
		elif p.volume_db <= -58.0 and p.playing:
			p.stop()
