class_name Guide
extends RefCounted
## Le guide : comprend une demande en français et décide quoi faire.
##
## Ce fichier ne contient que la compréhension (aucun son, aucun affichage) : il reçoit une phrase et rend une
## « décision » sous forme de dictionnaire. Le mode local (ce fichier seul) et le mode en ligne (guide_api.gd)
## rendent le même format, ce qui les rend interchangeables.
##
## La phrase vient d'une reconnaissance vocale en dictée libre : elle contient des fautes (« nerone », « mito
## chondrie », « l'isosome », « nez franc »…). Le guide rapproche donc ce qu'il entend des noms qu'il connaît, par le
## son (clé phonétique) puis à quelques lettres près, mais seulement quand la phrase ressemble à une demande :
## « bonjour » ou « attends » ne déclenchent rien.
##
## Décision : {"action": String, "cible": int, "cle": String, "texte": String}
##   action  "aller"      voyager jusqu'au nœud `cible`
##           "proposer"   la chose n'existe pas telle quelle : proposer `cible` (clip `cle`, phrase `texte`)
##           "decrire"    redire où l'on est, au niveau d'explication courant
##           "niveau"     le niveau d'explication a changé (déjà appliqué), puis redire
##           "visite"     lancer une visite guidée ; `cle` = sang, nerfs, oxygene, digestion, defenses, sommeil, ou ""
##           "suivant" / "precedent"   étape suivante / précédente de la visite
##           "quitter_visite"          quitter la visite en cours
##           "recentrer"  remettre le modèle devant soi
##           "etiquettes" afficher (`cle` = "oui") ou cacher (`cle` = "non") les noms
##           "filtre"     ne montrer qu'un système ; `cle` = tout, sang, nerfs, oxygene, digestion, squelette, muscles,
##                        hormones, defenses, urinaire, reproduction, sens
##           "retour"     revenir au corps entier
##           "remonter"   remonter d'un niveau
##           "oui" / "non"  réponse à une proposition
##           "silence"    se taire
##           "aide"       dire ce qu'on peut demander
##           "libre"      question libre : seul le mode en ligne sait y répondre (`cle` = "question" si la phrase
##                        est tournée comme une demande, "" si ce n'est peut-être qu'une conversation voisine)
##           "rien"       rien à faire (bruit, politesse, phrase banale)

const NIVEAUX := ["simple", "standard", "approfondi"]

var noms: PackedStringArray            # nom de chaque nœud du modèle
var atteignable: PackedByteArray       # 1 si le nœud a un chemin depuis le corps
var exact: Array = []                  # [clé normalisée, indice du nœud, clé phonétique, nombre de mots]
var proche: Array = []                 # [clé normalisée, indice du nœud, « ce qui manque », identifiant du clip, clé phonétique, nombre de mots]
var niveau := 1                        # indice dans NIVEAUX
var _score := 0.0                      # estimation du niveau de l'utilisateur, entre -1 (débutant) et +1 (expert)
var _a_entendre := {}                  # mots à faire connaître à la reconnaissance vocale (écrits avec leurs accents)

# Autres façons de nommer une chose du modèle : [ce qu'on dit, nom de l'objet]. Un objet absent du modèle est ignoré.
const SYNONYMES := [
	["cœur", "Cœur"], ["poumon", "Poumon"], ["œil", "Œil"], ["yeux", "Œil"], ["rein", "Rein"], ["intestin", "Intestins"],
	["intestin grêle", "Intestins"], ["foie", "Foie"], ["estomac", "Estomac"], ["cerveau", "Cerveau"], ["peau", "Peau"],
	["ADN", "ADN"], ["ARN", "ARN"], ["axone", "Axone myélinisé"], ["myéline", "Axone myélinisé"],
	["gaine de myéline", "Axone myélinisé"], ["cortex", "Cortex cérébral"], ["matière grise", "Cortex cérébral"],
	["substance grise", "Cortex cérébral"], ["matière blanche", "Substance blanche"], ["cervelet", "Cortex du cervelet"],
	["noyau de la cellule", "Noyau"], ["noyau cellulaire", "Noyau"], ["mitochondrie", "Mitochondrie"],
	["carbone", "Atome de carbone"], ["oxygène", "Atome d'oxygène"], ["hydrogène", "Atome d'hydrogène"], ["azote", "Atome d'azote"],
	["fer", "Atome de fer"], ["calcium", "Atome de calcium"], ["phosphore", "Atome de phosphore"], ["soufre", "Atome de soufre"],
	["eau", "Eau (H₂O)"], ["molécule d'eau", "Eau (H₂O)"], ["bactérie", "Bactérie intestinale"],
	["membrane", "Membrane cellulaire"], ["alvéole", "Alvéole pulmonaire"],
	["rétine", "Rétine"], ["épiderme", "Peau"], ["capillaire", "Capillaire sanguin"], ["golgi", "Appareil de Golgi"],
	["réticulum", "Réticulum endoplasmique"], ["phosphate", "Groupe phosphate"], ["CO2", "Dioxyde de carbone (CO₂)"],
	["gaz carbonique", "Dioxyde de carbone (CO₂)"], ["dioxyde de carbone", "Dioxyde de carbone (CO₂)"],
	["O2", "Dioxygène (O₂)"], ["dioxygène", "Dioxygène (O₂)"],
	["ATP", "ATP"], ["globule rouge", "Globule rouge"], ["hématie", "Globule rouge"],
	["électron", "Électron"], ["proton", "Proton"], ["neutron", "Neutron"], ["synapse", "Synapse"], ["neurone", "Neurone"],
	["cellule nerveuse", "Neurone"], ["ribosome", "Ribosome"], ["hémoglobine", "Hémoglobine"], ["collagène", "Collagène"],
	["anticorps", "Anticorps"], ["glucose", "Glucose"], ["néphron", "Néphron"], ["lysosome", "Lysosome"], ["nucléole", "Nucléole"],
	["chromatine", "Fibre de chromatine"], ["villosité", "Villosité intestinale"], ["lobule", "Lobule hépatique"],
	["lobule du foie", "Lobule hépatique"], ["cellule du foie", "Hépatocyte"], ["cellule de la peau", "Kératinocyte"],
	["cellule osseuse", "Ostéocyte"], ["cellule musculaire", "Fibre musculaire"], ["cellule du cœur", "Cardiomyocyte"],
	["cellule du poumon", "Pneumocyte"], ["cellule de l'intestin", "Entérocyte"], ["cellule de l'estomac", "Cellule gastrique"],
	["cellule du rein", "Cellule du tubule rénal"], ["tubule rénal", "Cellule du tubule rénal"],
	["muscle cardiaque", "Tissu cardiaque"], ["polymérase", "ARN polymérase"], ["synthase", "ATP synthase"],
	["pore du noyau", "Pore nucléaire"], ["désoxyribose", "Désoxyribose"],
	# organes, tissus et cellules ajoutés au modèle
	["moelle épinière", "Moelle épinière"], ["moelle", "Moelle épinière"], ["trachée", "Trachée"], ["trachée artère", "Trachée"],
	["œsophage", "Œsophage"], ["pancréas", "Pancréas"], ["rate", "Rate"], ["vésicule biliaire", "Vésicule biliaire"],
	["bile", "Vésicule biliaire"], ["vessie", "Vessie"], ["thyroïde", "Thyroïde"], ["glande thyroïde", "Thyroïde"],
	["glande surrénale", "Glande surrénale"], ["surrénale", "Glande surrénale"], ["glandes surrénales", "Glande surrénale"],
	["thymus", "Thymus"], ["ganglion lymphatique", "Ganglion lymphatique"], ["ganglion", "Ganglion lymphatique"],
	["hypophyse", "Hypophyse"], ["glande pituitaire", "Hypophyse"], ["langue", "Langue"],
	["oreille interne", "Oreille interne"], ["oreille", "Oreille interne"], ["cochlée", "Oreille interne"],
	["larynx", "Larynx"], ["cordes vocales", "Larynx"], ["diaphragme", "Diaphragme"], ["utérus", "Utérus"],
	["ovaire", "Ovaire"], ["testicule", "Testicule"], ["prostate", "Prostate"], ["fémur", "Fémur"],
	["os de la cuisse", "Fémur"], ["vertèbre", "Vertèbre"], ["colonne vertébrale", "Vertèbre"],
	["muscle squelettique", "Muscle squelettique"], ["muscle", "Muscle squelettique"], ["biceps", "Muscle squelettique"],
	["aorte", "Aorte"], ["artère aorte", "Aorte"], ["artère", "Aorte"], ["veine cave", "Veine cave"], ["veine", "Veine cave"],
	["nerf périphérique", "Nerf périphérique"], ["nerf", "Nerf périphérique"],
	["îlot de Langerhans", "Îlot de Langerhans"], ["Langerhans", "Îlot de Langerhans"], ["îlot pancréatique", "Îlot de Langerhans"],
	["îlot du pancréas", "Îlot de Langerhans"], ["follicule thyroïdien", "Follicule thyroïdien"],
	["follicule", "Follicule thyroïdien"], ["cellule ciliée", "Cellule ciliée"], ["cellule de l'oreille", "Cellule ciliée"],
	["papille gustative", "Papille gustative"], ["papille", "Papille gustative"], ["bourgeon du goût", "Papille gustative"],
	["ovocyte", "Ovocyte"], ["ovule", "Ovocyte"], ["spermatozoïde", "Spermatozoïde"], ["insuline", "Insuline"],
]

# La chose demandée n'existe pas telle quelle : le guide le dit et propose ce qui s'en rapproche, sans partir.
# (L'ordre compte : le rang de chaque ligne donne le nom de son enregistrement, proche_<rang>.)
const PROCHES := [
	["os", "Ostéon", "un os entier"], ["squelette", "Ostéon", "le squelette"], ["dent", "Hydroxyapatite", "les dents"],
	["muscle", "Faisceau musculaire", "un muscle entier"], ["sang", "Vaisseau sanguin", "le sang en tant que tel"],
	["artère", "Vaisseau sanguin", "une artère précise"], ["veine", "Vaisseau sanguin", "une veine précise"],
	["cellule", "Neurone", "une cellule générique"], ["gène", "ADN", "un gène précis"], ["génome", "ADN", "le génome entier"],
	["chromosome", "Fibre de chromatine", "un chromosome entier"], ["énergie", "Mitochondrie", "l'énergie en tant que telle"],
	["respiration", "Alvéole pulmonaire", "la respiration"], ["digestion", "Estomac", "la digestion"],
	["vue", "Rétine", "la vue"], ["vision", "Rétine", "la vision"], ["sucre", "Glucose", "le sucre en général"],
	["graisse", "Phospholipide", "la graisse"], ["cheveu", "Kératine", "les cheveux"], ["ongle", "Kératine", "les ongles"],
	["microbiote", "Bactérie intestinale", "le microbiote entier"], ["immunité", "Lymphocyte", "le système immunitaire"],
	["globule blanc", "Lymphocyte", "les globules blancs en général"], ["atome", "Atome de carbone", "un atome générique"],
	["molécule", "Eau (H₂O)", "une molécule générique"], ["noyau", "Noyau", "le mot noyau tout seul"],
	["pensée", "Cortex cérébral", "la pensée"], ["mémoire", "Cortex cérébral", "la mémoire"], ["nerf", "Axone myélinisé", "un nerf entier"],
	["liaison", "Synapse", "les liaisons en général"], ["connexion", "Synapse", "les connexions en général"],
	["quark", "Quark up", "le mot quark tout seul"], ["protéine", "Protéine", ""], ["acide aminé", "Glycine", "un acide aminé générique"],
]

# Mots qui trahissent quelqu'un qui connaît déjà le sujet : ils font monter l'estimation du niveau.
const MOTS_SAVANTS := ["atp", "synthase", "rhodopsine", "hydroxyapatite", "nucleosome", "chromatine", "histone", "polymerase",
	"phospholipide", "glutamate", "cysteine", "desoxyribose", "ribose", "uracile", "guanine", "cytosine", "thymine", "adenine",
	"tubuline", "microtubule", "myosine", "actine", "astrocyte", "osteocyte", "pneumocyte", "enterocyte", "hepatocyte",
	"keratinocyte", "cardiomyocyte", "nephron", "osteon", "lysosome", "reticulum", "golgi", "nucleole", "quark", "gluon", "heme"]

# Ce que la reconnaissance vocale écrit à la place des sigles et de quelques mots courts : [entendu, voulu].
const HOMOPHONES := [
	["l a d n", "l adn"], ["la d n", "l adn"], ["a d n", "adn"], ["la dn", "l adn"], ["ladn", "l adn"], ["l a dn", "l adn"],
	["l adéenne", "l adn"], ["la déenne", "l adn"], ["adéenne", "adn"], ["a dé enne", "adn"], ["l a dé enne", "l adn"],
	["la des haines", "l adn"], ["d n a", "adn"],
	["l a r n", "l arn"], ["la r n", "l arn"], ["a r n", "arn"], ["la rn", "l arn"], ["larn", "l arn"], ["l a rn", "l arn"],
	["l a t p", "l atp"], ["la t p", "l atp"], ["a t p", "atp"], ["la tp", "l atp"], ["latp", "l atp"], ["a té pé", "atp"],
	["l a té pé", "l atp"], ["c o 2", "co2"], ["co 2", "co2"], ["c o deux", "co2"], ["co deux", "co2"],
	["o 2", "o2"], ["o deux", "o2"], ["h 2 o", "eau"], ["h deux o", "eau"], ["h2o", "eau"],
	["chœur", "cœur"], ["cœurs", "cœur"], ["oeuil", "œil"], ["nerone", "neurone"],
]

# Les mêmes, mais seulement quand la phrase est une demande (« montre-moi le foi ») : ces mots sont trop courants.
const HOMOPHONES_EN_DEMANDE := [
	["le foi", "le foie"], ["la foi", "le foie"], ["le rin", "le rein"], ["les rin", "les rein"], ["le rhin", "le rein"],
	["le faire", "le fer"], ["l o", "l eau"], ["l oh", "l eau"], ["lot", "l eau"], ["le pot", "la peau"], ["la pot", "la peau"],
	["le sans", "le sang"], ["le cent", "le sang"], ["le sens", "le sang"], ["le corp", "le corps humain"],
	["l euil", "l œil"], ["l oeuil", "l œil"], ["la ratte", "la rate"], ["la dent", "l adn"],
]

# Mots sans contenu : ils ne comptent pas pour savoir si « toute la phrase » désigne une chose.
const MOTS_VIDES := ["le", "la", "les", "l", "un", "une", "des", "du", "de", "d", "au", "aux", "a", "et", "en", "je", "j", "tu",
	"on", "nou", "vou", "me", "m", "moi", "toi", "te", "t", "ce", "c", "ca", "cela", "est", "s", "il", "elle", "y", "que", "qu", "qui",
	"mon", "ma", "mes", "ton", "ta", "tes", "son", "sa", "ses", "ne", "n", "pa", "pas", "plu", "plus", "tre", "tres", "bien", "oui", "non",
	"euh", "heu", "hum", "ah", "oh", "eh", "ben", "bah", "bon", "alor", "alors", "donc", "voila", "merci", "plait", "stp", "svp",
	"peux", "peut", "pourrai", "veux", "voudrai", "aimerai", "voir", "vois", "voi", "va", "vas", "aller", "allon", "montre", "montrer",
	"montrez", "montrent", "montron", "monte", "emmene", "amene", "maintenant", "encore", "aussi", "juste", "petit", "peu", "ici",
	"la bas", "cette", "cet", "ces", "sur", "dans", "vers", "pour", "avec", "ou", "quoi", "comment", "dis", "dit", "explique", "repete", "raconte", "decri", "redi", "parle", "cherche", "trouve",
	"zoom", "zoome", "affiche", "direction", "vraiment", "beaucoup", "comme", "mais", "par", "lui", "leur", "se", "si", "sui", "suis", "ai", "as", "ont", "sont", "etre", "avoir", "fait", "faire", "tout"]

# Mots courants qui ressemblent de trop près à un nom du modèle : jamais rapprochés « à une lettre près ».
const MOTS_COURANTS := ["serie", "routine", "timide", "racine", "insulte", "serveur", "cerceau", "proto", "photon", "bouton", "mouton",
	"bonjour", "bonsoir", "salut", "pardon", "attend", "attends", "attention", "super", "genial", "histoire", "nature", "culture",
	"maison", "raison", "saison", "question", "reponse", "moment", "minute", "seconde", "personne", "quelqu", "chose", "truc",
	"neutre", "normal", "central", "cellulaire", "nucleaire", "solaire", "systeme", "probleme", "exemple", "simple", "encore",
	"nouveau", "nouvelle", "regarde", "ecoute", "arrete", "attente", "entend", "entends", "comprend", "comprends", "langage",
	"cortege", "glace", "sirene", "serein", "cytise", "retenir", "retenu", "octobre", "novembre", "decembre", "internet", "interne"]

# Tournures d'une demande adressée au guide.
const DEMANDE := ["montre", "montrer", "montrez", "montrent", "montrons", "monte moi", "voir", "vois", "va", "vas y", "aller", "allons",
	"emmène", "amène", "conduis", "direction", "zoom", "zoome", "cherche", "trouve", "où est", "où sont", "c'est quoi", "qu'est-ce",
	"explique", "parle moi", "dis moi", "je veux", "je voudrais", "j'aimerais", "affiche"]

const QUESTION := ["pourquoi", "comment", "combien", "c'est quoi", "qu'est-ce", "est-ce que", "quel", "quelle", "quels", "quelles",
	"à quoi", "où", "quand", "qui", "explique", "parle moi", "dis moi", "raconte"]

# Politesses et bruits de conversation : seuls, ils ne déclenchent rien.
const BANAL := ["bonjour", "bonsoir", "salut", "coucou", "hello", "merci", "merci beaucoup", "pardon", "attends", "attend", "attendez",
	"une seconde", "une minute", "deux secondes", "euh", "heu", "hum", "hein", "ah", "oh", "eh", "ben", "bah", "bon", "bien", "très bien",
	"alors", "voilà", "super", "génial", "cool", "wow", "waouh", "incroyable", "magnifique", "c'est beau", "c'est joli", "d'accord", "ok",
	"oui", "non", "ouais", "si", "peut-être", "je ne sais pas", "je sais pas", "aucune idée", "au revoir", "à bientôt", "bonne nuit",
	"s'il te plaît", "s'il vous plaît", "excuse moi", "désolé", "tant pis", "c'est bon", "ça va", "ça marche", "on verra", "un instant",
	"laisse", "rien", "rien du tout", "c'est tout", "voyons", "tiens", "regarde", "écoute", "dis donc", "eh bien", "ah bon", "ah oui"]

# Filtres : [identifiant, façons de le demander]. Demandés avec « montre », « affiche », « seulement »…
const FILTRES := [
	["sang", ["le sang", "la circulation", "circulation sanguine", "système sanguin", "système circulatoire", "les vaisseaux", "les veines", "les artères"]],
	["nerfs", ["les nerfs", "système nerveux", "le système nerveux"]],
	["oxygene", ["l'oxygène", "la respiration", "système respiratoire", "l'air", "le souffle"]],
	["digestion", ["la digestion", "système digestif", "tube digestif", "appareil digestif"]],
	["squelette", ["le squelette", "les os"]],
	["muscles", ["les muscles", "la musculature", "système musculaire"]],
	["hormones", ["les hormones", "système hormonal", "système endocrinien", "les glandes"]],
	["defenses", ["les défenses", "système immunitaire", "l'immunité", "défenses immunitaires", "les défenses immunitaires"]],
	["urinaire", ["système urinaire", "appareil urinaire", "l'urine", "les urines", "les reins et la vessie"]],
	["reproduction", ["la reproduction", "système reproducteur", "appareil reproducteur", "appareil génital"]],
	["sens", ["les sens", "les cinq sens", "les 5 sens", "organes des sens", "les organes des sens"]],
	["tout", ["tout le corps", "tous les systèmes", "sans filtre", "enlève le filtre", "enlève les filtres", "retire le filtre",
		"plus de filtre", "tout afficher", "affiche tout", "montre tout", "montre moi tout", "tout montrer", "remets tout", "remet tout"]],
]

const VERBES_FILTRE := ["montre", "montrer", "montrez", "montrent", "affiche", "afficher", "filtre", "filtrer", "isole", "garde",
	"seulement", "uniquement", "rien que", "allume", "éclaire", "mets en avant", "surligne", "remets", "remet"]

# Thèmes des visites guidées : [identifiant, mots qui le désignent].
const THEMES := [
	["sang", ["sang", "circulation", "sanguin", "sanguine"]],
	["nerfs", ["nerf", "nerfs", "nerveux", "influx"]],
	["oxygene", ["oxygène", "respiration", "air", "souffle"]],
	["digestion", ["digestion", "digestif", "repas", "aliment", "aliments"]],
	["defenses", ["défense", "défenses", "immunitaire", "immunité", "microbe", "microbes"]],
	["sommeil", ["sommeil", "nuit", "dormir", "dort", "dors", "rêve", "rêves"]],
]

var _phon_formes := {}      # forme écrite → [" normalisée ", " phonétique " ou ""]
var _homophones: Array = []
var _homophones_demande: Array = []
var _vides := {}
var _courants := {}
var _banal := {}
var _re_par: RegEx
var _re_non_alnum: RegEx
static var _re_phon: Array = []


func _init(noms_modele: PackedStringArray, atteignables: PackedByteArray) -> void:
	noms = noms_modele
	atteignable = atteignables
	_re_par = RegEx.create_from_string("\\(.*?\\)")
	var par_nom := {}      # nom normalisé → indice du premier nœud atteignable qui le porte
	for i in noms.size():
		if atteignable[i]:
			var cle := normaliser(noms[i])
			if cle != "" and not par_nom.has(cle):
				par_nom[cle] = i
				_ajouter_exact(cle, i)
				_noter_a_entendre(noms[i])
	for s in SYNONYMES:
		var cible := normaliser(s[1])
		if par_nom.has(cible):
			_ajouter_exact(normaliser(s[0]), par_nom[cible])
			_noter_a_entendre(s[0])
	for j in PROCHES.size():
		var p: Array = PROCHES[j]
		var cible := normaliser(p[1])
		if par_nom.has(cible) and p[2] != "":
			var cle := normaliser(p[0])
			proche.append([cle, par_nom[cible], p[2], "proche_%d" % j, phonetique_phrase(cle), cle.count(" ") + 1])
	for h: Array in HOMOPHONES:
		_homophones.append([" " + normaliser(h[0]) + " ", " " + normaliser(h[1]) + " "])
	for h: Array in HOMOPHONES_EN_DEMANDE:
		_homophones_demande.append([" " + normaliser(h[0]) + " ", " " + normaliser(h[1]) + " "])
	for m: String in MOTS_VIDES:
		_vides[m] = true
		_vides[normaliser(m)] = true
	for m: String in MOTS_COURANTS:
		_courants[normaliser(m)] = true
	for m: String in BANAL:
		_banal[normaliser(m)] = true


func _ajouter_exact(cle: String, i: int) -> void:
	for e: Array in exact:
		if e[0] == cle:
			return
	exact.append([cle, i, phonetique_phrase(cle), cle.count(" ") + 1])


func _noter_a_entendre(ecrit: String) -> void:
	var mots := PackedStringArray()
	for w in _re_par.sub(ecrit, " ", true).replace("₂", "2").split(" ", false):
		mots.append(w if w.length() >= 2 and w == w.to_upper() else w.to_lower())      # les sigles restent en capitales
	var t := " ".join(mots)
	# les mots très courts (« fer », « eau », « os ») sont bien reconnus sans aide, et les favoriser en ferait entendre partout
	if t.length() >= 4 or (t.length() >= 2 and t == t.to_upper()):
		_a_entendre[t] = true


## Minuscules, sans accents ni ponctuation, pluriels simples retirés : « Les Mitochondries ! » → « les mitochondrie ».
static func normaliser(t: String) -> String:
	var s := t.to_lower()
	var paires := {"à": "a", "â": "a", "ä": "a", "é": "e", "è": "e", "ê": "e", "ë": "e", "î": "i", "ï": "i", "ô": "o", "ö": "o",
		"ù": "u", "û": "u", "ü": "u", "ç": "c", "œ": "oe", "æ": "ae", "ÿ": "y", "ñ": "n", "₂": "2", "'": " ", "’": " "}
	for k: String in paires:
		s = s.replace(k, paires[k])
	var re := RegEx.create_from_string("\\(.*?\\)")
	s = re.sub(s, " ", true)
	re = RegEx.create_from_string("[^a-z0-9]+")
	s = re.sub(s, " ", true)
	var mots := PackedStringArray()
	for w in s.split(" ", false):
		if w.length() > 3 and (w.ends_with("s") or w.ends_with("x")):
			w = w.left(-1)
		mots.append(w)
	return " ".join(mots)


# ───────── rapprochement par le son ─────────

const _VOYELLES := "aeiouy"

## Clé phonétique d'un mot déjà normalisé : une écriture approximative de sa prononciation, pour que
## « lisosome », « lysosomes » et « l'isosome » se ressemblent. Volontairement simple : elle n'a pas à être juste,
## seulement à donner la même chose pour deux orthographes d'un même son.
static func phonetique(mot: String) -> String:
	if mot.length() <= 1 or mot.is_valid_int():
		return mot
	if _re_phon.is_empty():
		# c et g doux (devant e, i, y) sont marqués d'abord : les règles suivantes changent les voyelles qui les suivent
		for r: Array in [["c(?=[eiy])", "C"], ["g(?=[eiy])", "J"],
				["(ain|ein|aim|eim)(?![aeiouynm])", "in"], ["(en|em|am)(?![aeiouynm])", "an"], ["om(?![aeiouynm])", "on"],
				["(im|ym|yn|un)(?![aeiouynm])", "in"], ["(?<!s)tion", "ssion"]]:
			_re_phon.append([RegEx.create_from_string(r[0]), r[1]])
	var s := mot
	for r: Array in [["choeu", "ke"], ["coeu", "ke"], ["oeu", "e"], ["oe", "e"], ["sch", "ch"], ["chr", "kr"], ["chl", "kl"], ["chond", "kond"],
			["ph", "f"], ["th", "t"], ["rh", "r"], ["gh", "g"], ["ck", "k"], ["cqu", "k"], ["qu", "k"], ["q", "k"], ["gue", "g#e"], ["gui", "g#i"],
			["w", "v"]]:
		s = s.replace(r[0], r[1])
	for r: Array in _re_phon:
		s = (r[0] as RegEx).sub(s, r[1], true)
	for r: Array in [["eau", "o"], ["au", "o"], ["ou", "u"], ["ai", "e"], ["ei", "e"], ["ay", "e"], ["eu", "e"], ["y", "i"]]:
		s = s.replace(r[0], r[1])
	var o := ""
	var n := s.length()
	for i in n:
		var c := s[i]
		var suiv := s[i + 1] if i + 1 < n else ""
		var prec := s[i - 1] if i > 0 else ""
		match c:
			"c":
				o += "S" if suiv == "h" else "k"
			"C":
				o += "s"
			"J":
				o += "j"
			"h", "#":
				pass
			"s":
				if prec != "" and suiv != "" and _VOYELLES.contains(prec) and _VOYELLES.contains(suiv):
					o += "z"
				else:
					o += "s"
			"x":
				if suiv != "":
					o += "ks"
			_:
				o += c
	# fins muettes
	if o.length() > 3 and (o.ends_with("er") or o.ends_with("ez")):
		o = o.left(-1)
	else:
		for k in 2:
			if o.length() > 2 and "stdpz".contains(o[-1]):
				o = o.left(-1)
		if o.length() > 3 and (o.ends_with("ng") or o.ends_with("nk")):
			o = o.left(-1)      # sang, franc, tronc
	if o.length() > 2 and o.ends_with("e"):
		o = o.left(-1)
	# lettres doublées
	var d := ""
	for i in o.length():
		if i == 0 or o[i] != o[i - 1]:
			d += o[i]
	return d


## Clé phonétique d'une suite de mots normalisés, collés (« globule rouge » → « globulruj »).
static func phonetique_phrase(p: String) -> String:
	var s := ""
	for w in p.split(" ", false):
		s += phonetique(w)
	return s


## Nombre de lettres à changer pour passer de a à b ; rend `borne` + 1 dès que c'est trop.
static func distance(a: String, b: String, borne: int) -> int:
	var la := a.length()
	var lb := b.length()
	if absi(la - lb) > borne:
		return borne + 1
	var avant := PackedInt32Array()
	avant.resize(lb + 1)
	for j in lb + 1:
		avant[j] = j
	var cour := PackedInt32Array()
	cour.resize(lb + 1)
	for i in range(1, la + 1):
		cour[0] = i
		var mini_ligne := i
		for j in range(1, lb + 1):
			var v := mini(mini(avant[j] + 1, cour[j - 1] + 1), avant[j - 1] + (0 if a[i - 1] == b[j - 1] else 1))
			cour[j] = v
			if v < mini_ligne:
				mini_ligne = v
		if mini_ligne > borne:
			return borne + 1
		var tmp := avant
		avant = cour
		cour = tmp
	return avant[lb]


static func _seuil(longueur: int) -> int:
	if longueur < 5:
		return 0
	if longueur < 8:
		return 1
	if longueur < 12:
		return 2
	return 3


## Cherche dans `liste` l'entrée qui sonne comme un morceau de la phrase. `flou` : accepter quelques lettres d'écart.
## `demande` : la phrase est tournée comme une demande ; sinon il faut que la chose soit toute la phrase.
func _approcher(liste: Array, mots: PackedStringArray, demande: bool, flou: bool) -> Array:
	var n := mots.size()
	var ph := PackedStringArray()
	var plein := PackedByteArray()
	var nb_pleins := 0
	for w in mots:
		ph.append(phonetique(w))
		var p := 0 if _vides.has(w) else 1
		plein.append(p)
		nb_pleins += p
	var mieux: Array = []
	var mieux_note := 1e9
	for i in n:
		if not plein[i]:
			continue
		var colle := ""
		var pleins_dedans := 0
		for j in range(i, mini(n, i + 5)):
			colle += ph[j]
			pleins_dedans += plein[j]
			if not plein[j] or (not demande and pleins_dedans < nb_pleins):
				continue
			var taille := j - i + 1
			if taille == 1 and _courants.has(mots[i]):
				continue
			var essais := [colle]
			if i > 0 and mots[i - 1] == "la":
				essais.append("a" + colle)      # « la orte » : l'aorte
			for essai: String in essais:
				if essai.length() < 4:
					continue
				var r := _meilleur(liste, essai, taille, demande, flou)
				if not r.is_empty() and r[1] < mieux_note:
					mieux_note = r[1]
					mieux = r[0]
	return mieux


## L'entrée de `liste` la plus proche de `colle` (clé phonétique d'un morceau de phrase de `taille` mots), avec sa note.
func _meilleur(liste: Array, colle: String, taille: int, demande: bool, flou: bool) -> Array:
	var mieux: Array = []
	var mieux_note := 1e9
	var lc := colle.length()
	for e: Array in liste:
		var cle: String = e[-2]
		var le := cle.length()
		if le < 4 or taille > (e[-1] as int) + 2:
			continue
		var seuil := _seuil(le) if flou else 0
		if absi(le - lc) > seuil:
			continue
		var d := 0 if cle == colle else (distance(colle, cle, seuil) if seuil > 0 else 99)
		if d > seuil:
			continue
		# sans tournure de demande, on n'accepte un rapprochement « à peu près » que s'il est net
		if d > 0 and not demande and d * 5 > le:
			continue
		var note := float(d) / le - 0.0001 * le
		if note < mieux_note:
			mieux_note = note
			mieux = e
	return [] if mieux.is_empty() else [mieux, mieux_note]


# ───────── compréhension ─────────

func _trouver(liste: Array, phrase: String) -> Array:
	var p := " " + phrase + " "
	var mieux: Array = []
	var long := 0
	for k: Array in liste:
		var cle: String = k[0]
		if cle.length() > long and p.contains(" " + cle + " "):
			mieux = k
			long = cle.length()
	return mieux


func _forme(f: String) -> Array:
	if not _phon_formes.has(f):
		var nf := normaliser(f)
		var pf := PackedStringArray()
		var total := 0
		for w in nf.split(" ", false):
			var k := phonetique(w)
			pf.append(k)
			total += k.length()
		# les formes courtes ne se comparent qu'à la lettre : « oui » et « huit » sonnent pareil
		_phon_formes[f] = [" " + nf + " ", (" " + " ".join(pf) + " ") if total >= 6 else "", nf.length()]
	return _phon_formes[f]


var _p := ""       # phrase en cours, normalisée, entre deux espaces
var _pp := ""      # la même, mot à mot en phonétique

func _poser(p: String) -> void:
	_p = " " + p + " "
	var pf := PackedStringArray()
	for w in p.split(" ", false):
		pf.append(phonetique(w))
	_pp = " " + " ".join(pf) + " "


## La phrase contient-elle une de ces formes (à la lettre, ou au son pour les formes assez longues) ?
func _contient(_phrase: String, formes: Array) -> bool:
	return _longueur_forme(formes) > 0


func _longueur_forme(formes: Array) -> int:
	var long := 0
	for f: String in formes:
		var k := _forme(f)
		if (k[2] as int) > long and (_p.contains(k[0]) or (k[1] != "" and _pp.contains(k[1]))):
			long = k[2]
	return long


func _d(action: String, cible := -1, cle := "", texte := "") -> Dictionary:
	return {"action": action, "cible": cible, "cle": cle, "texte": texte}


func _remplacer(p: String, paires: Array) -> String:
	var s := " " + p + " "
	for h: Array in paires:
		if s.contains(h[0]):
			s = s.replace(h[0], h[1])
	return s.strip_edges()


## Comprend une phrase. `en_attente` : une proposition attend une réponse (« oui » / « non »).
func comprendre(phrase_brute: String, en_attente := false) -> Dictionary:
	var p := normaliser(phrase_brute)
	if p == "":
		return _d("rien")
	p = _remplacer(p, _homophones)
	_poser(p)
	var nb_mots := p.count(" ") + 1
	# visite en cours : quitter, avancer, reculer
	if _contient(p, ["visite", "visites", "démo", "parcours"]) and _contient(p, ["quitte", "quitter", "arrête", "arrêter", "arrêtez",
			"stop", "stoppe", "termine", "terminer", "fin de", "finis", "sors de", "sortir de", "annule", "interromps", "coupe"]):
		return _d("quitter_visite")
	if _contient(p, ["silence", "tais toi", "tais-toi", "taisez-vous", "chut", "stop", "arrête", "arrêter", "ça suffit", "la ferme"]):
		return _d("silence")
	if en_attente:
		if _contient(p, ["oui", "ouais", "d'accord", "ok", "vas-y", "allons-y", "volontiers", "on y va", "je veux bien", "avec plaisir",
				"bien sûr", "pourquoi pas", "carrément", "allez"]) or (nb_mots <= 2 and _contient(p, ["montre", "emmène moi", "go"])):
			return _d("oui")
		if _contient(p, ["non", "pas maintenant", "laisse", "annule", "plus tard", "non merci", "pas la peine"]):
			return _d("non")
	# niveau d'explication
	if _contient(p, ["plus simple", "plus simplement", "simplifie", "trop compliqué", "je ne comprends pas", "je comprends pas",
			"j'ai pas compris", "je n'ai pas compris", "pas compris", "comme à un enfant", "explique simplement", "moins compliqué",
			"plus facile", "c'est compliqué", "rien compris"]):
		_noter(-0.6)
		niveau = maxi(0, niveau - 1)
		return _d("niveau")
	if _contient(p, ["plus de détails", "plus de détail", "plus détaillé", "plus précis", "approfondi", "approfondir", "approfondis",
			"en savoir plus", "plus complet", "niveau expert", "va plus loin", "plus technique", "dis m'en plus", "dis-moi en plus",
			"plus compliqué", "plus savant"]):
		_noter(0.6)
		niveau = mini(NIVEAUX.size() - 1, niveau + 1)
		return _d("niveau")
	if _contient(p, ["aide", "aide moi", "que puis-je dire", "que puis-je demander", "comment ça marche", "quoi dire",
			"qu'est-ce que je peux dire", "qu'est-ce que je peux demander", "qu'est-ce que tu sais faire", "que sais-tu faire"]):
		return _d("aide")
	if _contient(p, ["étape précédente", "étapes précédentes", "précédent", "précédente", "étape d'avant", "l'étape d'avant",
			"reviens à l'étape", "retour à l'étape", "étape arrière"]):
		return _d("precedent")
	if _contient(p, ["étape suivante", "étapes suivantes", "suivant", "suivante", "continue", "continuer", "continuez", "continuons",
			"la suite", "ensuite", "passe à la suite", "prochaine étape", "étape d'après", "next"]):
		return _d("suivant")
	if _contient(p, ["recentre", "recentrer", "recentrez", "re centre", "au centre", "remets devant moi", "remet devant moi",
			"remettre devant moi", "mets devant moi", "devant moi", "replace", "replacer", "replacez", "recadre", "ramène devant",
			"reviens devant", "remets le devant", "remets-toi devant"]):
		return _d("recentrer")
	if _contient(p, ["étiquette", "étiquettes", "les noms", "le nom des", "légende", "légendes"]):
		var cacher := _contient(p, ["cache", "cacher", "cachez", "enlève", "enlever", "masque", "masquer", "retire", "retirer", "sans",
				"plus de", "plus d'", "désactive", "supprime", "efface", "ôte", "vire", "pas de", "pas d'", "éteins"])
		return _d("etiquettes", -1, "non" if cacher else "oui")
	# visites guidées
	var theme := ""
	for t: Array in THEMES:
		if _contient(p, t[1]):
			theme = t[0]
			break
	if _contient(p, ["visite", "visites", "visite guidée", "démo", "parcours guidé"]):
		return _d("visite", -1, theme)
	if _contient(p, ["sommeil", "dort", "dormir", "dors", "rêve", "nuit de sommeil", "une nuit"]):
		return _d("visite", -1, "sommeil")
	if _contient(p, ["reviens au corps", "retour au corps", "corps entier", "retour au début", "recommence", "accueil",
			"reviens au début", "revenir au corps", "le corps humain", "retourne au corps", "revenir au début", "corps humain"]):
		return _d("retour")
	if _contient(p, ["remonte", "remonter", "niveau au-dessus", "sors", "sortir", "recule", "reculer", "dézoome", "dézoomer",
			"dézoom", "en arrière"]):
		return _d("remonter")
	# filtres : « montre le sang », « seulement les nerfs », « montre tout »
	if _contient(p, VERBES_FILTRE) and not _contient(p, ["atome", "molécule", "noyau"]):
		var f_mieux := ""
		var f_long := 0
		for f: Array in FILTRES:
			var l := _longueur_forme(f[1])
			if l > f_long:
				f_long = l
				f_mieux = f[0]
		if f_mieux == "" and p.ends_with(" tout") and nb_mots <= 4:
			f_mieux = "tout"
			f_long = 99
		var nomme := _trouver(exact, p)      # « montre les glandes surrénales » : un objet nommé plus précisément l'emporte
		if f_mieux != "" and (nomme.is_empty() or (nomme[0] as String).length() <= f_long):
			return _d("filtre", -1, f_mieux)
	# une chose du modèle, nommée
	var demande := _contient(p, DEMANDE)
	if demande:
		p = _remplacer(p, _homophones_demande)
		_poser(p)
	for mot: String in MOTS_SAVANTS:
		if _p.contains(" " + mot + " "):
			_noter(0.25)
			break
	var e := _trouver(exact, p)
	if not e.is_empty() and (e[0] as String).length() <= 3 and nb_mots == 1 and not ["adn", "arn", "atp", "co2", "o2"].has(e[0]):
		return _d("rien")
	if not e.is_empty():
		return _d("aller", e[1])
	var n := _trouver(proche, p)
	if not n.is_empty() and (n[0] as String).length() <= 3 and nb_mots == 1:
		return _d("rien")
	if not n.is_empty():
		return _d("proposer", n[1], n[3], "Le modèle ne contient pas %s. Ce qui s'en rapproche le plus : %s." % [n[2], noms[n[1]]])
	if not _banal.has(p):
		var mots := p.split(" ", false)
		e = _approcher(exact, mots, demande, true)
		if not e.is_empty():
			return _d("aller", e[1])
		n = _approcher(proche, mots, demande, false)
		if not n.is_empty():
			return _d("proposer", n[1], n[3], "Le modèle ne contient pas %s. Ce qui s'en rapproche le plus : %s." % [n[2], noms[n[1]]])
	if _contient(p, ["c'est quoi", "qu'est-ce que c'est", "qu'est-ce que je vois", "qu'est-ce que c'est que ça", "c'est quoi ça", "explique", "où suis-je", "où sommes-nous",
			"où on est", "je suis où", "on est où", "répète", "redis", "décris", "raconte", "dis moi", "parle moi", "qu'est-ce que je regarde"]):
		return _d("decrire")
	if _contient(p, ["oui", "non", "merci", "d'accord", "ok"]) or _est_banal(p):
		return _d("rien")
	return _d("libre", -1, "question" if demande or _contient(p, QUESTION) else "", phrase_brute)


## Politesse, hésitation ou mot isolé : rien qui s'adresse vraiment au guide.
func _est_banal(p: String) -> bool:
	if _banal.has(p) or not p.contains(" "):
		return true
	var s := " " + p + " "
	for b: String in _banal:
		if b.contains(" ") and s.contains(" " + b + " "):
			s = s.replace(" " + b + " ", " ")
	for w in s.split(" ", false):
		if not _vides.has(w) and not _banal.has(w):
			return false
	return true


## L'estimation du niveau glisse lentement ; elle ne change le niveau d'explication que si elle penche nettement.
func _noter(delta: float) -> void:
	_score = clampf(_score * 0.7 + delta, -1.0, 1.0)


## À appeler quand l'utilisateur a nommé de lui-même une chose savante : s'il le fait souvent, on passe à « approfondi ».
func niveau_suggere() -> int:
	if _score > 0.55:
		return 2
	if _score < -0.55:
		return 0
	return niveau


## Mots que la reconnaissance vocale doit connaître d'avance (elle les favorise quand elle hésite) : les noms des objets
## du modèle et leurs synonymes, écrits avec leurs accents. La liste se déduit toute seule du modèle chargé.
func vocabulaire() -> PackedStringArray:
	var sortie := PackedStringArray()
	for k: String in _a_entendre:
		sortie.append(k)
	return sortie
