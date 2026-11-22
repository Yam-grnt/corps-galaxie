# Consignes communes aux bêta-testeurs — « Le corps galaxie », essai de résistance du 22 novembre 2026

Tu joues un bêta-testeur précis (ton profil t'est donné dans ta mission). Tu ne portes pas de casque : tu testes tout
ce qui peut l'être depuis ce PC, **dans la peau de ton personnage**, puis tu rends un retour honnête, y compris
désagréable. Un retour complaisant ne sert à rien.

## Le produit
Expérience de réalité virtuelle (Meta Quest 3) : un corps humain à taille réelle, fait de nuages de points lumineux,
qu'on explore du corps entier jusqu'aux quarks (148 objets). Un guide vocal (voix féminine) accompagne : il comprend
des commandes dans le casque, et — nouveauté en test — un **guide en ligne** (grand modèle de langage) répond aux
questions libres, peut emmener vers un objet, allumer un filtre, lancer une visite écrite ou en improviser une.
Trois publics au menu : Enfant, Curieux (art et sciences), Scientifique. Cibles commerciales : amateurs d'art,
passionnés de science, joueurs ; plus les institutions (musées, écoles).

## Ce que tu peux tester, et comment

### 1. Le guide en ligne (le cœur de l'essai)
Un relais tourne sur ce PC : `POST http://127.0.0.1:8787/guide`, corps JSON UTF-8 :
```json
{"appareil": "<ton identifiant de testeur>", "question": "…", "chemin": ["Corps humain"], "niveau": 1,
 "filtre": "tout", "historique": [{"q": "question précédente", "r": "réponse précédente"}]}
```
- `niveau` : 0 enfant, 1 curieux, 2 scientifique (prends celui de ton personnage, et essaie d'en changer une fois).
- `chemin` : là où « se trouve » le visiteur, du corps à l'objet courant (ex. `["Corps humain","Cœur","Tissu cardiaque"]`).
  Fais-le évoluer selon les actions `aller` que le guide renvoie, comme si tu le suivais.
- `historique` : les 3 derniers échanges au plus, pour que la conversation ait une mémoire.
- La réponse contient `reponse` (ce que dit le guide), `actions`, éventuellement `visite` (improvisée), `niveau`,
  `hors_sujet`, `mesure` (durée, coût). Elle contient aussi un champ `audio` très volumineux (le son) :
  **ne l'affiche jamais** et ne le garde pas (retire-le, ainsi que `etapes[].audio`, avant d'imprimer ou d'enregistrer).
- Écris un petit script Node dans le dossier temporaire
  `C:\Users\Yam\AppData\Local\Temp\claude\3b11429da43224a4\58e2e301-bf1f-444c-8b80-4a0705e7b2bc\scratchpad\beta\`
  (crée un sous-dossier à ton nom) pour mener la conversation et en garder la trace (question, réponse, actions, durée).
- **Budget : 16 questions au maximum**, une à la fois, jamais en parallèle (le relais est partagé avec les autres
  testeurs ; chaque question coûte de l'argent réel au commanditaire). Une demande de récit (« raconte-moi… »,
  « montre-moi comment… ») peut prendre 20 secondes : règle ton délai d'attente à 60 s. Un refus `429` signifie
  quota ou budget épuisé : arrête-toi et signale-le.
- Mène une vraie conversation de ton personnage, pas un questionnaire : rebondis sur les réponses, pose des
  questions de relance, dis ce que « tu ressens », essaie au moins : une question naïve, une question pointue de ton
  domaine, une demande de récit, une relance émotionnelle ou personnelle, une demande hors sujet ou limite propre à
  ton profil, et une tentative de mettre le guide en défaut (erreur factuelle, contradiction, question médicale
  personnelle, provocation…).

### 2. Les contenus
`godot/contenus.json` : `noeuds` (146 fiches par nom, trois niveaux `simple` / `standard` / `approfondi` + `note`),
`visites` (7 visites narrées, 6 à 8 étapes), `filtres`, `intro` (voix off d'ouverture). Lis l'introduction, une
dizaine de fiches au niveau de ton personnage (choisis-les comme il les choisirait) et une visite complète.

### 3. L'interface et le rendu (captures d'écran prises sur PC, pas en casque)
Dossier `C:\Users\Yam\AppData\Roaming\Godot\app_userdata\Le corps galaxie\` — regarde avec l'outil Read, au choix :
`menu_femme.png` (menu de départ), `intro_3_corps.png`, `intro_1_galaxie.png` (introduction),
`menu2_04_accueil_actif.png`, `menu2_06_montrer.png`, `menu2_09_visites_en_cours.png`, `menu2_12_reglages_jauge.png`
(menu en jeu), `etude_apres_01_corps_1_25m.png`, `etude_apres_04_thorax_x3_0.png`, `etude_apres_11_voyage_coeur.png`,
`etude_apres_14_voyage_cerveau.png`, `etude_apres_20_voyage_atome_de_carbone.png` (rendu du corps et des objets).
Si un fichier manque, liste le dossier et prends le plus proche. Le mode d'emploi général est dans `LISEZ-MOI.md`.

### Ce que tu ne peux PAS juger
Le confort en casque, la fluidité, les gestes des mains, la qualité de la reconnaissance vocale, la voix elle-même.
Ne les note pas ; dis seulement ce que ton personnage en attendrait ou en craindrait.

## Règles
- Ne modifie aucun fichier du projet. Tu n'écris que ton rapport `science/beta/<ton-identifiant>.md` et tes
  fichiers de travail dans le dossier temporaire. Pas d'adb, pas de git, pas de Godot. N'arrête ni ne relance le relais.
- N'invente aucun résultat : cite les réponses réelles du guide (verbatim, entre guillemets) pour appuyer chaque
  critique ou éloge.
- Reste dans ton personnage pour les questions et pour le ressenti, mais rédige le rapport de façon exploitable.

## Le rapport `science/beta/<ton-identifiant>.md`
1. **Qui je suis** (3 lignes) et ce que j'attendais avant de commencer.
2. **Le fil de ma conversation** : chaque échange en une ligne (question → résumé de la réponse → action → durée),
   avec les 4 ou 5 réponses les plus marquantes citées en entier.
3. **Notes sur 10**, avec une phrase de justification chacune : présence et incarnation du guide (ai-je eu
   l'impression de parler à quelqu'un ?) · écoute (a-t-il tenu compte de ce que je disais ?) · capacité à attiser
   ma curiosité · justesse scientifique (signale toute erreur ou approximation, preuve à l'appui) · adaptation à
   mon niveau · posture (reste-t-il biologique, moléculaire, sans jouer au médecin ?) · pertinence des actions
   (m'a-t-il emmené au bon endroit, au bon moment ?) · qualité des visites et récits · temps de réponse ·
   contenus écrits (fiches, visite, introduction) · interface et rendu (d'après les captures) · envie d'y revenir.
4. **Mes 5 plus gros problèmes**, du plus grave au moins grave, chacun avec la preuve et ce que j'aurais voulu à la place.
5. **Mes 3 meilleurs moments.**
6. **Ce qui manque pour moi** (fonctions, contenus, ton) et **combien je paierais** (prix juste, prix trop cher), en
   précisant si le guide en ligne change ce prix.
7. **Bugs et incohérences** relevés (réponse tronquée, tutoiement/vouvoiement, action absurde, lenteur…).

Termine ta mission par un résumé de 25 lignes au plus : tes notes, tes 5 problèmes, tes 3 meilleurs moments, ton prix.
