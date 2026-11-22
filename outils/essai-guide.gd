extends SceneTree
## Essai du guide sans casque : vérifie que des phrases — dont des transcriptions fautives, telles que la
## reconnaissance vocale les écrit vraiment — sont comprises comme prévu, et que les phrases banales ne déclenchent rien.
##
## Lancement (depuis la racine du projet) :
##   .toolchain\godot\Godot_v4.4.1-stable_win64_console.exe --headless --xr-mode off --path godot -s ../outils/essai-guide.gd
## Options (après « -- ») :
##   --transcriptions=fichier.json   évalue aussi un fichier {"nom.wav": "texte entendu", …} produit par un moteur de
##                                   reconnaissance, contre --attendus=fichier.json ([[phrase, action, cible], …])
##   --vocabulaire=fichier.txt       écrit la liste des mots transmis au moteur (un par ligne)

# Objets annoncés dans le modèle : ajoutés ici s'ils n'y sont pas encore, pour essayer leurs synonymes dès maintenant.
const A_VENIR := ["Moelle épinière", "Trachée", "Œsophage", "Pancréas", "Rate", "Vésicule biliaire", "Vessie", "Thyroïde",
	"Glande surrénale", "Thymus", "Ganglion lymphatique", "Hypophyse", "Langue", "Oreille interne", "Larynx", "Diaphragme",
	"Utérus", "Ovaire", "Testicule", "Prostate", "Fémur", "Vertèbre", "Muscle squelettique", "Aorte", "Veine cave",
	"Nerf périphérique", "Îlot de Langerhans", "Follicule thyroïdien", "Cellule ciliée", "Papille gustative", "Ovocyte",
	"Spermatozoïde", "Insuline"]

# [phrase entendue, action attendue, cible (nom de l'objet) ou clé, « une proposition attend une réponse »]
const CAS := [
	# ── demandes bien transcrites
	["montre-moi un neurone", "aller", "Neurone"], ["je veux voir les mitochondries", "aller", "Mitochondrie"],
	["emmène-moi au cœur", "aller", "Cœur"], ["Montre l'ADN.", "aller", "ADN"], ["va voir le néphron", "aller", "Néphron"],
	["Montre-moi l’axone.", "aller", "Axone myélinisé"], ["montre l'appareil de Golgi", "aller", "Appareil de Golgi"],
	["je veux voir le réticulum endoplasmique", "aller", "Réticulum endoplasmique"], ["un globule rouge", "aller", "Globule rouge"],
	["Montre-moi les globules rouges.", "aller", "Globule rouge"], ["la mitochondrie", "aller", "Mitochondrie"],
	["Neurone.", "aller", "Neurone"], ["montre-moi l'hydroxyapatite", "aller", "Hydroxyapatite"],
	["je voudrais voir les yeux", "aller", "Œil"], ["va voir l'oxygène", "aller", "Atome d'oxygène"],
	["montre-moi un atome d'oxygène", "aller", "Atome d'oxygène"], ["emmène-moi dans le noyau de la cellule", "aller", "Noyau"],
	["montre-moi le gaz carbonique", "aller", "Dioxyde de carbone (CO₂)"], ["l'ATP synthase", "aller", "ATP synthase"],
	["montre-moi la matière grise", "aller", "Cortex cérébral"], ["ADN", "aller", "ADN"],
	# ── transcriptions fautives relevées sur les moteurs essayés (voix de synthèse)
	["Montre - moi à un heuron.", "aller", "Neurone"], ["montre moi un nerone", "aller", "Neurone"],
	["Montre-moi un neuron", "aller", "Neurone"], ["Je veux voir les mythes au conduit.", "aller", "Mitochondrie"],
	["je veux voir les mito chondries", "aller", "Mitochondrie"], ["montre moi la mitochondri", "aller", "Mitochondrie"],
	["Montre-moi Laxson.", "aller", "Axone myélinisé"], ["Montre-moi l’axon.", "aller", "Axone myélinisé"],
	["Montre- moi la xonne.", "aller", "Axone myélinisé"], ["Montre l'appareil de Golgie", "aller", "Appareil de Golgi"],
	["Je veux voir le réticulumum endopasmique.", "aller", "Réticulum endoplasmique"],
	["Va voir le nez franc.", "aller", "Néphron"], ["va voir le néphronc.", "aller", "Néphron"],
	["Montre - moi un l'isosome", "aller", "Lysosome"], ["MONTRE MOI LISOSOMES", "aller", "Lysosome"],
	["Je veux voir le nucléal", "aller", "Nucléole"], ["Montre - moi la déénine", "aller", "Adénine (A)"],
	["Montre- moi la dénine.", "aller", "Adénine (A)"], ["Montre la gouanine.", "aller", "Guanine (G)"],
	["Va voir la citosine", "aller", "Cytosine (C)"], ["va voir la citazine", "aller", "Cytosine (C)"],
	["Montre-moi la timine.", "aller", "Thymine (T)"], ["Je veux voir l'Uracil.", "aller", "Uracile (U)"],
	["Je veux voir le racile.", "aller", "Uracile (U)"], ["Montre- moi une istone.", "aller", "Histone"],
	["Montre-moi un eston", "aller", "Histone"], ["Montre lactine et la myosine.", "aller", "Myosine"],
	["Je veux voir la redopsine.", "aller", "Rhodopsine"], ["Je veux voir la roboxine.", "aller", "Rhodopsine"],
	["Montre-moi un astro site.", "aller", "Astrocyte"], ["Montre-moi un astrocite.", "aller", "Astrocyte"],
	["Je veux voir l'infosite.", "aller", "Lymphocyte"], ["Montre - moi un népatocite", "aller", "Hépatocyte"],
	["Montre-moi un épatocite.", "aller", "Hépatocyte"], ["Montre un pnémocyte", "aller", "Pneumocyte"],
	["va avoir un enterrocyte.", "aller", "Entérocyte"], ["va avoir un antérocyte", "aller", "Entérocyte"],
	["Montre-moi l’ostéan.", "aller", "Ostéon"], ["montre-moi l'hostéon", "aller", "Ostéon"],
	["Je veux voir la vélosité intestinale.", "aller", "Villosité intestinale"],
	["Je veux voir la velocité intestinale.", "aller", "Villosité intestinale"],
	["Montre-moi l’hoxyapatite.", "aller", "Hydroxyapatite"], ["MONTRE MOI L'HYDROXY APATITE", "aller", "Hydroxyapatite"],
	["montre-moi la DN", "aller", "ADN"], ["montre moi l'a d n", "aller", "ADN"], ["Montre-moi la dent.", "aller", "ADN"],
	["je veux voir la RN", "aller", "ARN"], ["montre l'A T P", "aller", "ATP"],
	["Je veux voir les moglobine", "aller", "Hémoglobine"], ["Emmène - moi au chœur", "aller", "Cœur"],
	["Montrons- moi le nuque osome.", "aller", "Nucléosome"], ["Je veux voir un karatinocyte", "aller", "Kératinocyte"],
	["Je veux voir un caratinocyte, sir.", "aller", "Kératinocyte"], ["Monte- moi la synapse.", "aller", "Synapse"],
	["montre moi le rin", "aller", "Rein"], ["montre moi le foi", "aller", "Foie"], ["emmène moi au serveau", "aller", "Cerveau"],
	["montre moi le co deux", "aller", "Dioxyde de carbone (CO₂)"], ["je veux voir un globul rouge", "aller", "Globule rouge"],
	["montre moi les alvéoles pulmonaire", "aller", "Alvéole pulmonaire"], ["montre moi un ribozome", "aller", "Ribosome"],
	["va voir la fibre de cromatine", "aller", "Fibre de chromatine"], ["montre le lobule épatique", "aller", "Lobule hépatique"],
	# ── objets nouveaux et leurs synonymes
	["montre-moi le pancréas", "aller", "Pancréas"], ["Montre - moi le pancréa", "aller", "Pancréas"],
	["va voir la moelle épinière", "aller", "Moelle épinière"], ["Montre-moi la thyroïde.", "aller", "Thyroïde"],
	["Montre- moi la tyroïde.", "aller", "Thyroïde"], ["montre-moi la tiroïde", "aller", "Thyroïde"],
	["Je veux voir un spermatozoïde.", "aller", "Spermatozoïde"], ["Montre l’îlot de l’angérant.", "aller", "Îlot de Langerhans"],
	["Montre l'îlot de Langérand", "aller", "Îlot de Langerhans"], ["montre-moi la trachée", "aller", "Trachée"],
	["emmène-moi dans l'œsophage", "aller", "Œsophage"], ["montre moi l'ésophage", "aller", "Œsophage"],
	["montre-moi la rate", "aller", "Rate"], ["va voir la vésicule biliaire", "aller", "Vésicule biliaire"],
	["je veux voir la vessie", "aller", "Vessie"], ["montre-moi les glandes surrénales", "aller", "Glande surrénale"],
	["montre-moi le thymus", "aller", "Thymus"], ["va voir un ganglion", "aller", "Ganglion lymphatique"],
	["montre-moi l'hypophyse", "aller", "Hypophyse"], ["montre moi l'hippofise", "aller", "Hypophyse"],
	["je veux voir la langue", "aller", "Langue"], ["montre-moi l'oreille", "aller", "Oreille interne"],
	["emmène-moi dans le larynx", "aller", "Larynx"], ["montre-moi le diaphragme", "aller", "Diaphragme"],
	["montre moi le diafragme", "aller", "Diaphragme"], ["va voir l'utérus", "aller", "Utérus"],
	["montre-moi un ovaire", "aller", "Ovaire"], ["montre-moi un testicule", "aller", "Testicule"],
	["va voir la prostate", "aller", "Prostate"], ["montre-moi le fémur", "aller", "Fémur"],
	["montre-moi une vertèbre", "aller", "Vertèbre"], ["je veux voir un muscle", "aller", "Muscle squelettique"],
	["montre-moi l'aorte", "aller", "Aorte"], ["Montre-moi la orte", "aller", "Aorte"], ["va voir la veine cave", "aller", "Veine cave"],
	["montre-moi un nerf", "aller", "Nerf périphérique"], ["montre-moi un follicule thyroïdien", "aller", "Follicule thyroïdien"],
	["je veux voir une cellule ciliée", "aller", "Cellule ciliée"], ["montre-moi une papille gustative", "aller", "Papille gustative"],
	["va voir un ovocyte", "aller", "Ovocyte"], ["montre-moi un ovule", "aller", "Ovocyte"],
	["montre-moi l'insuline", "aller", "Insuline"], ["montre moi un spermato zoïde", "aller", "Spermatozoïde"],
	# ── la chose n'existe pas telle quelle
	["montre-moi un os", "proposer", "Ostéon"], ["je veux voir un chromosome", "proposer", "Fibre de chromatine"],
	["montre-moi une dent", "proposer", "Hydroxyapatite"], ["montre-moi un globule blanc", "proposer", "Lymphocyte"],
	# ── commandes
	["c'est quoi", "decrire", ""], ["C’est quoi?", "decrire", ""], ["qu'est-ce que c'est", "decrire", ""], ["répète", "decrire", ""],
	["plus simple", "niveau", ""], ["je n'ai pas compris", "niveau", ""], ["plus de détails", "niveau", ""],
	["aide", "aide", ""], ["qu'est-ce que je peux dire", "aide", ""],
	["reviens au corps", "retour", ""], ["Revient au corps.", "retour", ""], ["REVIENT AU CORPS", "retour", ""],
	["remonte", "remonter", ""], ["recule", "remonter", ""], ["silence", "silence", ""], ["tais-toi", "silence", ""], ["stop", "silence", ""],
	["oui", "oui", "", true], ["d'accord", "oui", "", true], ["vas-y", "oui", "", true], ["non merci", "non", "", true],
	["lance la visite", "visite", ""], ["Lance la visite.", "visite", ""], ["visite guidée", "visite", ""],
	["lance la visite du sang", "visite", "sang"], ["lance la visite des nerfs", "visite", "nerfs"],
	["lance la visite de l'oxygène", "visite", "oxygene"], ["Lance la visite de la digestion.", "visite", "digestion"],
	["lance la visite des défenses", "visite", "defenses"], ["lance la visite du sommeil", "visite", "sommeil"],
	["je veux la visite sur la respiration", "visite", "oxygene"], ["raconte-moi une nuit de sommeil", "visite", "sommeil"],
	["étape suivante", "suivant", ""], ["Étapes suivantes.", "suivant", ""], ["suivant", "suivant", ""], ["continue", "suivant", ""],
	["Étapes suivant.", "suivant", ""], ["étape précédente", "precedent", ""], ["Étapes précédentes", "precedent", ""],
	["quitte la visite", "quitter_visite", ""], ["arrête la visite", "quitter_visite", ""], ["Arrêtes la visite.", "quitter_visite", ""],
	["recentre", "recentrer", ""], ["Recentre.", "recentrer", ""], ["RE CENTRE", "recentrer", ""], ["Au centre", "recentrer", ""],
	["remets devant moi", "recentrer", ""], ["replace", "recentrer", ""], ["remet devant moi", "recentrer", ""],
	["ressentre", "recentrer", ""], ["Recentrez.", "recentrer", ""],
	["montre les étiquettes", "etiquettes", "oui"], ["Montre les étiquettes.", "etiquettes", "oui"], ["affiche les noms", "etiquettes", "oui"],
	["cache les étiquettes", "etiquettes", "non"], ["enlève les étiquettes", "etiquettes", "non"], ["cache les noms", "etiquettes", "non"],
	["montre le sang", "filtre", "sang"], ["montre la circulation", "filtre", "sang"], ["montre les nerfs", "filtre", "nerfs"],
	["Montre le squelette.", "filtre", "squelette"], ["montre les muscles", "filtre", "muscles"], ["montre la digestion", "filtre", "digestion"],
	["montre l'oxygène", "filtre", "oxygene"], ["montre les hormones", "filtre", "hormones"], ["montre les défenses", "filtre", "defenses"],
	["montre tout", "filtre", "tout"], ["montre-moi tout", "filtre", "tout"], ["montre le système urinaire", "filtre", "urinaire"],
	["montre la reproduction", "filtre", "reproduction"], ["montre les sens", "filtre", "sens"], ["seulement le système nerveux", "filtre", "nerfs"],
	["montre-moi le système immunitaire", "filtre", "defenses"], ["enlève le filtre", "filtre", "tout"],
	# ── questions hors du modèle
	["la tour Eiffel", "libre", ""], ["pourquoi le ciel est bleu", "libre", ""], ["comment fonctionne un vaccin", "libre", ""],
	# ── phrases banales : rien ne doit se passer
	["bonjour", "rien", ""], ["Bonjour.", "rien", ""], ["attends", "rien", ""], ["Attends.", "rien", ""], ["euh", "rien", ""],
	["Euh...", "rien", ""], ["hum", "rien", ""], ["merci", "rien", ""], ["merci beaucoup", "rien", ""], ["oui", "rien", ""],
	["non", "rien", ""], ["d'accord", "rien", ""], ["ok", "rien", ""], ["ah bon", "rien", ""], ["c'est beau", "rien", ""],
	["super", "rien", ""], ["génial", "rien", ""], ["wow", "rien", ""], ["bon", "rien", ""], ["alors", "rien", ""],
	["voilà", "rien", ""], ["je ne sais pas", "rien", ""], ["attends une seconde", "rien", ""], ["euh bon alors", "rien", ""],
	["pardon", "rien", ""], ["salut", "rien", ""], ["oh là là", "rien", ""], ["très bien", "rien", ""], ["au revoir", "rien", ""],
	["fer", "rien", ""], ["os", "rien", ""], ["incroyable", "rien", ""], ["Hein ?", "rien", ""], ["ah oui d'accord", "rien", ""],
	# ── phrases de tous les jours : aucun voyage, aucune commande
	["Qu’est-ce qu’on mange ce soir?", "libre|rien", ""], ["Tu as vu le match hier soir.", "libre|rien", ""],
	["Passe-moi la manette s’il te plaît.", "libre|rien", ""], ["Il fait chou ici.", "libre|rien", ""],
	["je suis timide", "libre|rien", ""], ["il est serein", "libre|rien", ""], ["j'aime bien cette série", "libre|rien", ""],
	["on mange quoi ce soir", "libre|rien", ""], ["tu as vu le match hier", "libre|rien", ""], ["c'est ma routine", "libre|rien", ""],
	["je vais chercher un café", "libre|rien", ""], ["il fait chaud ici", "libre|rien", ""], ["passe-moi la manette", "libre|rien", ""],
	["regarde derrière toi", "libre|rien", ""], ["quelle heure est-il", "libre|rien", ""], ["j'ai une question", "libre|rien", ""],
	["c'est vraiment bien fait", "libre|rien", ""], ["je reviens dans deux minutes", "libre|rien", ""],
]


func _init() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://modele.json"))
	var noms := PackedStringArray()
	for nd: Dictionary in d.noeuds:
		noms.append(str(nd.nom))
	var classe: GDScript = load("res://guide.gd")
	# 1. le modèle tel qu'il est : les synonymes d'objets absents doivent être ignorés sans erreur
	var tous := PackedByteArray()
	tous.resize(noms.size())
	tous.fill(1)
	var guide_reel = classe.new(noms, tous)
	print("modèle actuel : ", noms.size(), " objets, ", guide_reel.exact.size(), " façons de les nommer, ",
			guide_reel.vocabulaire().size(), " mots transmis à la reconnaissance vocale")
	# 2. le modèle complété des objets annoncés
	var ajoutes := 0
	for n: String in A_VENIR:
		if not noms.has(n):
			noms.append(n)
			ajoutes += 1
	tous.resize(noms.size())
	tous.fill(1)
	var guide = classe.new(noms, tous)
	print("avec les ", ajoutes, " objets à venir : ", guide.exact.size(), " façons de nommer, ", guide.vocabulaire().size(), " mots transmis")

	var options := {}
	for a in OS.get_cmdline_user_args():
		var k := a.split("=", true, 1)
		options[k[0]] = k[1] if k.size() > 1 else ""
	if options.has("--vocabulaire"):
		var f := FileAccess.open(options["--vocabulaire"], FileAccess.WRITE)
		f.store_string("\n".join(guide.vocabulaire()) + "\n")
		f.close()

	var bons := 0
	var t0 := Time.get_ticks_usec()
	for c: Array in CAS:
		if _bon(guide, noms, c[0], c[1], c[2], c.size() > 3 and c[3], true):
			bons += 1
	var duree := (Time.get_ticks_usec() - t0) / 1000.0
	print("GUIDE : %d / %d phrases comprises comme prévu (%.1f %%) — %.2f ms par phrase" % [bons, CAS.size(), 100.0 * bons / CAS.size(), duree / CAS.size()])

	if options.has("--transcriptions"):
		var lu_e = JSON.parse_string(FileAccess.get_file_as_string(options["--transcriptions"]))
		var lu_a = JSON.parse_string(FileAccess.get_file_as_string(options.get("--attendus", "")))
		if not (lu_e is Dictionary and lu_a is Array):
			print("ARRÊT : --transcriptions ou --attendus illisible")
			quit(2)
			return
		var entendus: Dictionary = lu_e
		var attendus: Array = lu_a
		var cles := entendus.keys()
		cles.sort()
		var par_voix := {}
		for k: String in cles:
			var rang := int(k.substr(1, 2)) - 1
			var a: Array = attendus[rang]
			var ok := _bon(guide, noms, entendus[k], a[1], a[2], false, options.has("--detail"))
			var v := k.left(1)
			if not par_voix.has(v):
				par_voix[v] = [0, 0]
			par_voix[v][1] += 1
			if ok:
				par_voix[v][0] += 1
		var ligne := "MOTEUR " + str(options["--transcriptions"]).get_file().get_basename() + " :"
		for v: String in par_voix:
			ligne += "  voix %s %d / %d" % [v, par_voix[v][0], par_voix[v][1]]
		print(ligne)
	quit(0 if bons == CAS.size() else 1)


func _bon(guide, noms: PackedStringArray, phrase: String, action: String, cible: String, en_attente: bool, dire: bool) -> bool:
	guide.niveau = 1
	var d: Dictionary = guide.comprendre(phrase, en_attente)
	var ok: bool = (action.split("|") as PackedStringArray).has(d.action)
	if ok and (d.action == "aller" or d.action == "proposer"):
		ok = d.cible >= 0 and noms[d.cible] == cible
	elif ok and ["filtre", "visite", "etiquettes"].has(d.action):
		ok = d.cle == cible
	if not ok and dire:
		print("  RATÉ « ", phrase, " » → ", d.action, " ", noms[d.cible] if d.cible >= 0 else d.cle, "   (attendu : ", action, " ", cible, ")")
	return ok
