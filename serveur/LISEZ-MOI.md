# Relais du guide en ligne — v2 : parcours mis en scène, envoyés au fil de l'eau

Prototype de test. Le casque envoie la phrase entendue (du texte, jamais de son) ou un événement ; le relais interroge
Claude en flux, avec la persona (`persona.md`) et les textes du projet en préfixe mis en cache, et rend un
**parcours** : 1 à 7 « temps », chacun = ce que la guide dit + au plus un geste exécuté par le moteur du casque + une
façon d'enchaîner. Chaque temps est validé, réparé, mis en voix (Piper) et rendu dès qu'il est complet, pendant que
le modèle écrit la suite.

`relais-v1.mjs` est la version précédente (réponse d'un bloc : actions + visite improvisée), gardée pour mémoire.
Le relais v2 répond encore à l'ancien format aux clients qui n'envoient pas `"protocole": 2` (APK déjà installés).

État : vérifié en simulation (28 parcours + 27 contrôles), avec l'API réelle (Haiku 5.5 : 28 parcours ; Sonnet 5.5 : 4)
et avec le client Godot sans casque (`--headless --xr-mode off`). **Jamais essayé dans le casque** ; `main.gd` n'est
pas encore branché sur le nouveau protocole.

## Lancer

```powershell
cd C:\Users\Yam\Documents\corps-galaxie\serveur
npm install                                   # une seule fois
node essai.mjs                                # simulation : gratuit, sans clé, doit finir par « Contrat respecté »
$env:ANTHROPIC_API_KEY = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY','User'); node relais.mjs   # réel, payant
node essai.mjs --reel --detail                # 13 questions de qualité, ≈ 0,03 $ avec Haiku 5.5 (≈ 0,45 $ avec Sonnet 5.5)
```

Le relais écoute sur `127.0.0.1:8787` (`PORT`, `HOTE`) ; le casque le joint par `adb reverse tcp:8787 tcp:8787`
(adb de SideQuest) et lit son adresse dans `user://reglages.json`, clé `relais`. La clé d'API n'est lue que dans la
variable d'environnement : ni écrite, ni affichée, jamais dans l'APK.

## Protocole

| Route | Rôle |
|---|---|
| `POST /guide` | Demande. Répond dès que le **premier temps est prêt** (texte + voix) : `{id, temps:[…], fini, resume?}` |
| `GET /suite?id=…&apres=n` | Attente longue (15 s au plus) : les temps de rang > n dès qu'il y en a, et `fini` + `resume` à la fin |
| `POST /annuler` `{id}` | Le visiteur a repris la parole ou la main : le flux est coupé chez le fournisseur |
| `GET /sante` | `{ok, protocole: 2, simulation, modele, persona, voix}` |

**Demande** (tous les champs sauf `question` ou `evenement` sont facultatifs) :

```json
{"protocole": 2, "appareil": "…", "question": "…",            "evenement": "parole | debut | arrivee | retour_corps | silence | fin",
 "mode": "incarne | descriptif", "nom": "Lune", "tutoiement": true, "niveau": 1,
 "chemin": ["Corps humain", "Poumon"], "filtre": "tout", "visibles": ["Bronche", "Alvéole pulmonaire"], "vus": ["Cœur"],
 "temps_restant_s": 240, "historique": [{"q": "…", "r": "…"}], "seance": {…}}
```

`silence_long` et `depart` sont acceptés comme synonymes de `silence` et `fin`. `historique` : 6 échanges au plus.
`seance` est l'état que le relais a rendu au tour précédent (voir plus bas) : le casque le renvoie tel quel.

**Un temps** :

```json
{"n": 2, "dit": "Regarde, là : une alvéole.", "audio": "<WAV base 64>",
 "geste": {"type": "designer", "enfant": "Alvéole pulmonaire"},
 "enchainer": "voix | delai | visiteur", "secondes": 0, "urgence": true, "langue": "en"}
```

`urgence` et `langue` ne sont présents que lorsqu'ils s'appliquent. Le geste part **en même temps** que la voix ;
`voix` = temps suivant quand la voix a fini et le geste est accompli ; `delai` = `secondes` de plus ; `visiteur` =
dernier temps, la guide rend la parole (question).

| Geste | Champs | Dans le casque |
|---|---|---|
| `amener` | `cible`, `taille` (0,25–1 m), `angle` (°) | `aller(indice, taille, angle)` |
| `corps` | `angle` | `aller(racine, TAILLE_CORPS, angle)` |
| `eclairer` | `filtre`, `systemes`, `flux` (−1, 0, 1) | `_regler_filtre(filtre, false)` ; `flux: 0` = lumière fixe |
| `animer` | `cible`, `mode` (pulse, wave, noise), `cycles` | `_effets([[cible, mode, cycles]])` |
| `designer` | `enfant` (enfant de l'objet courant) | `vise = k` puis `_maj_vise()` |
| `noms` | `oui` | `etiquettes = oui` |
| `posture` | `allonge` | `couche_cible` |
| `visite` | `id` | `_lancer_visite(id)` (toujours le dernier temps) |
| `silence` | `secondes` | attendre |
| `arreter` | — | `_arreter_visite(false)`, `_effets([])`, fin du parcours |

**Résumé de fin** (`resume`) : `niveau`, `langue`, `sources`, `attend_visiteur`, `urgence`, `ignore` (la phrase captée
ne s'adressait pas à la guide : parcours vide, aucun son), `tutoiement`, `seance`, `reste`, `verif`, `mesure` ; ou
`{annule: true}`, `{tu: "mode" | "frequence" | "quota" | "budget"}` (initiative refusée sans appel au modèle),
`{erreur: …}` (fournisseur perdu en route). Erreurs HTTP avant tout temps : 400, 413, 429 (`quota`, `budget`),
502/503/504 → le casque retombe sur le guide local.

**État de séance** (`resume.seance`, à renvoyer dans la demande suivante ; gardé en mémoire vive par `guide_api.gd`) :
`memoire` (note de 40 mots tenue par le modèle : activité en cours, goûts, promesses), `proposition` (la dernière
proposition de la guide, pour qu'un « oui » ouvre un récit), `drapeaux` (`detresse` : persiste jusqu'à la fin),
`tutoiement`. Le relais lui-même ne garde rien d'un tour à l'autre.

## Ce que le relais décide sans le modèle

- **Proportion** (`Longueur permise`, dite au modèle et imposée) : salut, merci, au revoir, demande de conclusion ou
  moins de 75 s restantes → 1 temps sans geste ; question fermée courte → 1 temps ; cas courant → 2 temps (3 au public
  scientifique) ; demande de récit (« raconte », « montre-moi comment », « surprends-moi »…) ou « oui » à une
  proposition → jusqu'à 7 temps (3 s'il reste moins de 4 minutes).
- **Initiatives** (`debut`, `arrivee`, `retour_corps`, `silence`, `fin`) : mode incarné seulement, un temps bref ou
  rien ; pas plus d'une toutes les `INITIATIVE_MIN_S` secondes (45) ni de `INITIATIVES_JOUR` (30) par appareil.
- **Tenir parole** : un geste de déplacement, de filtre ou de visite est retiré quand la parole du même temps ne fait
  que le proposer (« tu veux que je te montre… ? ») ; la parole est alors rendue au visiteur. Un déplacement ou une
  lumière annoncés sans geste sont signalés (`verif.coherence`) — pas réparables après coup.
- **Secours** : une phrase qui oriente vers le 15, le 18, le 112, le 114 ou le 3114 n'est jamais coupée ni retouchée,
  porte `urgence: true`, arrête tout et clôt le parcours. Ces numéros ne sont pas signalés comme « hors textes ».
- **Santé** : une valeur personnelle dans la question (tension, glycémie, pouls…) ajoute au message la consigne de ne
  citer aucun chiffre de référence ; un signal de détresse pose le drapeau `detresse`, rappelé à chaque tour suivant.
- **Tu / vous** : le visiteur qui vouvoie fait passer `tutoiement` à false (rendu au casque, qui le mémorise).
- **Langue** : si la guide répond dans une autre langue que le français, aucun son n'est synthétisé (`langue`).
- **Réparations** : une cible ou un filtre inconnus retirent le *geste*, jamais la parole ; un texte n'est coupé
  (à la fin d'une phrase) qu'au-delà de 75 mots (100 au public scientifique, 40 pour une initiative). Chaque
  réparation est décrite en clair dans `verif.reparations` et au journal.
- **Filet sur les chiffres** (`verif.chiffres_hors_fiches`) : signale tout nombre écrit *en chiffres* absent des textes
  du projet. Il n'attrape **ni** les nombres en lettres, **ni** un chiffre réel attribué au mauvais objet (−70 mV
  pour une cellule cardiaque), **ni** une erreur sans chiffre. Il mesure un risque, il ne garantit rien.

## Latence (mesurée, PC local, Haiku 5.5, effort bas, réflexion coupée, cache chaud)

Premier temps prêt (texte + voix) : **2,2 à 2,9 s** (médiane 2,7 s ; 3,4 s quand le cache est à réécrire), dont
≈ 1,4 s avant le premier jeton, ≈ 0,7 s pour écrire le premier temps, 0,3 à 0,7 s de voix. Temps suivants : un toutes
les 0,4 à 0,5 s, soit bien avant la fin de la voix du précédent : aucun silence entre deux temps. Un récit de
6 à 7 temps est entièrement prêt en 4,3 à 6,5 s (contre 20 à 35 s d'un bloc en v1). Sonnet 5.5 : 3,4 à 5,1 s pour le
premier temps. Pour gagner encore : accusé de réception local immédiat (son ou « hm » enregistré), synthèse de la
première phrase sans attendre la fin du temps, préfixe allégé.

## Coûts (mesurés)

Prix par million de jetons (documentation Anthropic, relevé du 3 novembre 2026) : Haiku 5.5 0,10 $ / 0,50 $ tant que la
demande fait moins de 100 000 jetons (**×5 au-delà : le préfixe en fait 92 500, il ne reste que ≈ 7 000 jetons de
marge** — le relais prévient au démarrage) ; Sonnet 5.5 2 $ / 10 $ ; lecture du cache 10 % (Haiku) ou 5 % (Sonnet) du
prix d'entrée ; écriture ×1,25 (5 min) ou ×2 (1 h).

| | Haiku 5.5 | Sonnet 5.5 |
|---|---|---|
| Échange simple, cache chaud | 0,0011 $ | 0,012 à 0,014 $ |
| Récit de 6–7 temps | 0,0013 à 0,0016 $ | 0,020 $ |
| Initiative | 0,0011 $ | ≈ 0,011 $ (estimé) |
| Écriture du cache (5 min / 1 h) | 0,012 $ / 0,018 $ | 0,23 $ / 0,37 $ |
| Séance type : 25 prises de parole dont 4 récits, 8 initiatives, 1 écriture de cache d'une heure | **≈ 0,06 $** | **≈ 0,8 $** |

Plafonds : `QUOTA_JOUR` (60 prises de parole), `INITIATIVES_JOUR` (30), `BUDGET_JOUR_USD` (1 $, tous appareils).

## Vie privée

Aucun son ne quitte le casque. Le relais n'écrit rien sur disque ; son journal ne contient que durées, jetons, coût,
types de gestes et nature des réparations — jamais les phrases. Un parcours en cours vit 2 minutes en mémoire.
L'identifiant de l'appareil n'est gardé que sous forme d'empreinte salée, pour la journée. L'état de séance (dont la
note de mémoire écrite par le modèle) voyage par le casque et n'est pas conservé par le relais ; le modèle a pour
consigne de n'y mettre ni nom, ni âge, ni santé, **mais il ne la respecte pas toujours** (Haiku y a noté « grand-père
a Alzheimer ») : cette note est envoyée au fournisseur à chaque tour comme le reste de la conversation. Les phrases
sont traitées par Anthropic selon sa politique de conservation. Avant diffusion : consentement explicite (parental
pour un mineur), HTTPS, authentification du casque, stockage durable des quotas.

## Limites connues

- Tout ce qui est improvisé échappe à toute relecture ; les textes du projet eux-mêmes ont été rédigés et relus par
  des agents IA, pas encore par des spécialistes humains (la guide le dit si on le lui demande).
- La cohérence parole/gestes n'est vérifiée que par des expressions régulières françaises.
- Refus du modèle (`stop_reason: refusal`) : phrase de repli ; pas de modèle de secours configuré.
- Quotas et budget en mémoire : remis à zéro au redémarrage. Rien n'authentifie le casque.
- La voix (Piper sur le PC du relais) est une solution d'essai : en production, synthèse dans le casque ou service de voix.

## Réglages (variables d'environnement)

`MODELE` (claude-haiku-5-5), `EFFORT` (low), `REFLEXION` (1 pour la laisser au modèle ; coupée par défaut),
`CACHE_TTL` (1h ou 5m), `QUOTA_JOUR` (60), `INITIATIVES_JOUR` (30), `INITIATIVE_MIN_S` (45), `BUDGET_JOUR_USD` (1),
`DELAI_MS` (30000), `PORT` (8787), `HOTE` (127.0.0.1), `VOIX` (0 pour la couper), `VOIX_PROCESSUS` (2),
`RELAIS_SIMULATION` (1), `SIMULATION_MS` (300). `node relais.mjs --schema` affiche le schéma imposé au modèle,
`--consignes` les consignes système sans les textes du projet.
