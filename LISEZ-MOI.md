# Le corps galaxie — v3

Une expérience de réalité virtuelle artistico-scientifique : un corps humain fait de points lumineux, à taille réelle,
qu'on explore de l'organisme jusqu'aux quarks, accompagné par un guide vocal.

Version 0.3.0, pour Meta Quest 3. Projet Godot 4.4.1 (OpenXR), conçu pour être porté sur d'autres casques.

## Ce que fait la v3

- **Introduction** : une animation de poussière d'étoiles avec la voix du guide (on peut la passer), puis le menu de
  départ : corps féminin ou masculin, public (Enfant, Curieux, Scientifique), Démarrer.
- **Corps construit par systèmes**, à l'échelle 1:1 : peau, squelette, muscles, artères (rouges), veines (bleues),
  nerfs (jaunes) et une trentaine d'organes. 148 objets en tout, jusqu'aux quarks.
- **Viser et cliquer** : gâchette de l'index (manette) ou pincement bref (main). L'élément visé porte un anneau et son
  nom ; un clic le fait venir devant soi et le guide le présente. Le voisinage s'estompe pour le détacher.
- **Saisir** : gâchette du majeur ou pincement tenu ; deux mains pour agrandir et tourner ; joystick pour zoomer.
- **Recentrer** à tout moment : bouton du menu, clic sur le joystick, ou « recentre ». « Revenir au corps » (bouton,
  B ou Y) remet tout au point de départ, instantanément.
- **Filtres** : sang, nerfs, oxygène, digestion, squelette, muscles, hormones, défenses… avec animation des flux.
- **Sept visites narrées** (sommeil, sang, nerfs, oxygène, digestion, défenses, échelles), avec les boutons
  « Étape précédente », « Étape suivante », « Quitter la visite ».
- **Étiquettes** : le nom des éléments visibles, en option.
- **Guide vocal embarqué** : « montre-moi un neurone », « c'est quoi ? », « montre le sang », « étape suivante »,
  « lance la visite de la digestion », « recentre »… Rien ne sort du casque.
- **Trois publics** : un conte scientifique pour les enfants, un texte précis et élégant pour les curieux, le détail des
  mécanismes pour les scientifiques.
- **Réalité mixte**, paysage sonore par échelle, avertissements de représentation sur chaque carte.

## Dossiers

| Dossier | Contenu |
|---|---|
| `godot/` | Le projet Godot. `main.gd` (rendu, pointeur, gestes, voyage, visites, filtres), `intro.gd` (introduction et menu de départ), `panneau.gd` (boutons au doigt ou au pointeur), `guide.gd` (compréhension), `voix.gd`, `sons.gd`, `guide_api.gd` (mode en ligne, inactif), `contenus.json` (textes) |
| `godot/voix/clips/` | Les enregistrements de la voix du guide |
| `model.js`, `outils/exporter-modele.js` | Le générateur du modèle 3D et sa conversion pour Godot |
| `plugin-voix/` | Sources de l'extension Android de reconnaissance vocale (sherpa-onnx) |
| `science/` | Registre du comité scientifique : `validation.md`, `corrections.json`, `enfants.json` |
| `serveur/` | Relais du mode en ligne (préparé, non déployé) |
| `outils/` | Scripts de fabrication (APK, voix, sons, modèle, essai du guide) |
| `version-web-2d/`, `index.html`, `vr.js` | La v1 web, conservée |
| `.toolchain/` | Outils de build installés en local (Godot, Java 17, SDK Android, Piper, sherpa-onnx). Non versionné |

## Fabriquer

```powershell
powershell -ExecutionPolicy Bypass -File outils\fabriquer.ps1 -Installer
```

Lance l'essai automatique (zoom jusqu'aux quarks, voyage guidé vers chaque objet, compréhension de demandes types),
fabrique `godot\build\corps-galaxie.apk`, puis l'installe sur le casque branché.

Après une modification du modèle : `node outils\exporter-modele.js`.

Après une modification des textes (`godot/contenus.json` ou les phrases de `main.gd`) :

```powershell
.toolchain\godot\Godot_v4.4.1-stable_win64_console.exe --headless --xr-mode off --path godot --quit-after 200 -- --exporter-textes
```

```powershell
node outils\fabriquer-voix.js
```

Seuls les textes modifiés sont réenregistrés.

## Rigueur scientifique

Chaque texte affiché ou prononcé passe par `science/`. La voix est enregistrée à partir de ces textes : ce qui est
entendu est exactement ce qui a été relu.

**Limites à connaître**

- La relecture a été faite par des agents IA. Les textes de la v3 (33 nouveaux objets, visites, filtres, introduction,
  narration pour enfants) reposent sur des valeurs de manuel, sans vérification en ligne. `science/validation.md`
  liste ce qu'un spécialiste humain doit confirmer avant la mise en vente.
- Le modèle 3D assume des simplifications : corps féminin dérivé du gabarit masculin, organes pairs en miroir,
  poumons sans lobes, pas de nœud « muscle lisse », côtes et bassin stylisés, échelles internes non strictes.
- Atomes, protéines et quarks gardent leurs formes schématiques de la v1 ; les cartes le disent.

## Mode en ligne (préparé, désactivé)

Le guide local ne répond qu'aux commandes et aux objets du modèle. Le mode en ligne ajoutera les questions libres :
seules celles-ci partiront, en texte, vers un relais (`serveur/relais.mjs`) qui interroge Claude Haiku 5.5 avec les
fiches du comité en préfixe mis en cache. Coût estimé : 0,2 à 0,3 USD par utilisateur sur la durée de vie (estimation,
pas une mesure). Avant activation : déployer le relais, vérifier l'achat et tenir un quota côté serveur, ajouter la
permission INTERNET, recueillir le consentement, choisir une voix de synthèse en ligne. Le relais n'a jamais été
essayé contre l'API réelle.

## Autres casques

Le code ne dépend d'aucun fabricant : session, mains, manettes et réalité mixte passent par OpenXR. La reconnaissance
vocale est une extension Android (elle fonctionnera sur tout casque Android arm64).

- **HTC Vive Focus** : ajouter un préréglage d'export (chargeur Khronos, profil Vive Focus 3). Non fait, faute d'appareil.
- **Android XR** : premier candidat pour un portage, mais demande Godot 4.6 et l'extension Vendors 5.x.
- **Pico** : plus tard. **Apple Vision Pro, lunettes AR grand public** : non pour l'instant.

## Crédits et licences (à faire figurer dans l'application publiée)

- Voix du guide : synthèse Piper, voix « fr_FR-siwis-medium » (corpus SIWIS, Université d'Édimbourg et Idiap), CC-BY 4.0.
- Reconnaissance vocale : sherpa-onnx (k2-fsa, Apache 2.0), ONNX Runtime (Microsoft, MIT), Silero VAD (MIT), modèle
  français « sherpa-onnx-streaming-zipformer-fr-kroko-2025-08-06 » (Kroko ASR / Banafo, CC BY-SA — version de la
  licence à vérifier avant une publication payante : partage à l'identique et attribution obligatoires).
- Moteur : Godot Engine (MIT), extension Godot OpenXR Vendors (MIT).

## Suite

1. Relecture des textes par des spécialistes humains ; relecture des fiches « reproduction » par un pédagogue.
2. Atomes en nuages de probabilité, protéines tracées d'après la PDB, organes encore absents.
3. Version anglaise, voix masculine en option, démo gratuite, mode kiosque pour musées et classes.
4. Clé de signature définitive, crédits dans l'application, politique de confidentialité : requis avant le store.
