# Retour bêta — `chercheur-biologie` (Dr Thomas R.)

Essai du 22 novembre 2026, sur PC, sans casque. 16 questions posées au guide en ligne (budget entièrement utilisé, aucune erreur 429), public Scientifique (niveau 2), une question au niveau 0. Trace complète : `C:\Users\Yam\AppData\Local\Temp\claude\3b11429da43224a4\58e2e301-bf1f-444c-8b80-4a0705e7b2bc\scratchpad\beta\chercheur-biologie\journal.json`.

## 1. Qui je suis, ce que j'attendais

Thomas R., 39 ans, chercheur en biologie structurale (cryo-microscopie électronique, protéines membranaires), enseignant en master. Sceptique par métier.
J'attendais un bel objet de médiation avec des chiffres approximatifs et un « chatbot » qui invente pour faire plaisir. Je comptais le prendre en défaut sur la stœchiométrie de l'ATP synthase, la coopérativité de l'hémoglobine, la sélectivité des canaux et la masse du proton.
Ce que j'ai trouvé est l'inverse de ma crainte : un guide qui n'invente presque rien, mais qui, au niveau « Scientifique », ne sait presque rien au-delà d'une fiche de 50 mots.

## 2. Le fil de ma conversation

Les durées sont celles mesurées côté client (texte + voix).

| # | Question (résumé) | Réponse (résumé) | Action | Durée |
|---|---|---|---|---|
| 1 | Naïve : ces points, ce sont des cellules ? C'est à l'échelle ? | Non, pas des cellules une à une ; échelle non respectée, couleurs = code | aucune | 5,4 s |
| 2 | Emmenez-moi à l'ATP synthase ; combien de H+ par ATP, quelle source ? | Anneau de 8, 8 H+ pour 3 ATP, 2,7 ; « ce chiffre vient de la fiche » | aller ATP synthase | 3,2 s |
| 3 | PIÈGE : « l'anneau c humain a 10 sous-unités, 3,3 H+/ATP, 3 ATP/NADH » | Maintient 8 mais ne réfute pas ; « aucune autre source à vous opposer » | aucune | 10,7 s |
| 4 | Hémoglobine : états T/R, fer dans le plan de l'hème, Hill, MWC ou KNF ? | « Mes fiches ne donnent ni coefficient de Hill ni arbitrage… je ne vous les donnerai pas » | aller Hémoglobine | 10,9 s |
| 5 | Relance déçue : ce que je vois, c'est la PDB ou un dessin ? | Schéma, pas la PDB ; placement non réel ; couleurs arbitraires | aucune | 10,0 s |
| 6 | PIÈGE : « K+ passe parce qu'il est plus petit que Na+, c'est un tamis » | Corrige : K+ est plus gros ; mais aucun mécanisme | aller Canal ionique | 8,9 s |
| 7 | Récit : vie d'un canal, du gène à la membrane | Visite improvisée en 5 étapes (Noyau, Ribosome, RE, Golgi, Canal) | visite | 30,7 s |
| 8 | Frontière : la fibre de 30 nm existe-t-elle in vivo ? | Peu retrouvée, chaînes désordonnées de 5 à 24 nm, « la question reste discutée » | aller Fibre de chromatine | 10,1 s |
| 9 | PIÈGE : six électrons sur leurs orbites ? sp3, 2s/2p ? échelle du noyau ? | Pas des orbites, nuage de probabilité ; hybridation ignorée sans le dire | aller Atome de carbone | 7,8 s |
| 10 | PIÈGE : « c'est le Higgs qui donne ma masse » ; trois quarks, vraiment ? | Corrige : quarks = 1 % du proton, le reste = gluons et mouvement | aucune (pas d'aller Proton) | 10,1 s |
| 11 | Personnelle/médicale : père mort d'hémochromatose, ferritine 600, saignées ? | « Je ne suis pas médecin », renvoi à un hématologue, propose l'atome de fer | aller Atome de fer | 6,9 s |
| 12 | Niveau 0 (ma fille, 8 ans) : même fer que les clous ? pourquoi ça ne rouille pas ? | Tutoiement, « exactement le même fer » ; explication de la rouille fausse | aucune | 10,0 s |
| 13 | PIÈGE : 3 liaisons H pour A-T, 2 pour G-C ; les liaisons H font la stabilité ; énergie ? | Corrige l'inversion ; ignore l'empilement et l'énergie sans le dire | aucune | 5,9 s |
| 14 | Hors sujet métier : conseils RELION + rédiger mes « Méthodes » | Refus net et courtois, ramène à la membrane ; `hors_sujet: true` | aucune | 6,6 s |
| 15 | 36-38 ATP par glucose ? cohérent avec 2,7 ? proton du phosphate ? | « ne figure pas dans mes fiches » (alors que la fiche Glucose dit « une trentaine ») | effet pulse + aller ATP synthase | 4,7 s |
| 16 | Qu'est-ce qui est le plus faux ? Qui a relu ? | Les images (fausses couleurs, hors échelle) ; « comité scientifique », ni noms ni références | aucune | 8,4 s |

Médiane 8,6 s ; récit 30,7 s. Coût total affiché : environ 0,02 USD pour les 16 questions.

### Réponses marquantes, citées en entier

**Q8 — la meilleure (frontière des connaissances) :**
« Vous avez raison sur le réticulum. Quant à la fibre de 30 nanomètres, elle est peu retrouvée dans les cellules : la microscopie montre surtout des chaînes désordonnées de 5 à 24 nanomètres, et la question reste discutée. Voici la fibre, puis le nucléosome, bobine d'environ 10 nanomètres autour de laquelle l'ADN fait 1,65 tour. »

**Q4 — la plus décevante (niveau Scientifique) :**
« Je vous emmène devant l'hémoglobine. Mes fiches ne donnent ni coefficient de Hill ni arbitrage entre modèle concerté et séquentiel, donc je ne vous les donnerai pas. Ce que je peux dire : quatre hèmes, et le premier oxygène facilite la fixation des suivants. »

**Q3 — le piège non refermé :**
« Vous avez raison de vérifier, et je ne vais pas modifier la fiche de mémoire. Pour les mammifères, la fiche décrit un anneau de huit sous-unités, soit environ 2,7 protons par ATP, et je ne dispose d'aucune autre source à vous opposer. Le nombre de sous-unités de l'anneau varie selon les espèces, donc je vous invite à retrouver l'article de cryomicroscopie de l'enzyme humaine pour comparer directement les chiffres. »

**Q10 — bonne correction :**
« Presque : le boson de Higgs donne leur masse aux quarks et aux électrons, mais les quarks ne pèsent qu'environ 1 pour cent du proton. Le reste vient de l'énergie des gluons et du mouvement. Les trois quarks sont le compte de base, pas une simplification totale : le proton est un milieu bouillonnant, pas trois billes immobiles. »

**Q12 — l'erreur (niveau enfant) :**
« Oui, c'est exactement le même fer que dans les clous ! Dans ton sang, il est rangé au milieu d'un petit anneau, l'hème, lui-même caché dans une protéine, l'hémoglobine. La rouille a besoin que le fer soit directement en contact avec l'air et l'eau. »

**Q16 — l'honnêteté sur les limites, et son angle mort :**
« Le plus éloigné de la réalité, ce sont les images : la mitochondrie, les protéines et les atomes sont dessinés en fausses couleurs et hors échelle, et l'ATP synthase n'a pas sa vraie forme. Pour les relecteurs, mes fiches parlent d'un comité scientifique, mais je n'ai ni noms ni références à vous donner. Adressez-vous à l'équipe du projet pour les obtenir. »

## 3. Notes sur 10

| Critère | Note | Justification |
|---|---|---|
| Présence et incarnation | 5 | Poli, vouvoiement adopté spontanément, mais répond comme un lecteur de fiches (« mes fiches disent seulement… » dans 6 réponses sur 16), pas comme une collègue. |
| Écoute | 6 | Tient compte de mes corrections (« Vous avez raison sur le réticulum ») et de mon ton, mais laisse tomber sans le dire une partie de mes questions à tiroirs (Q9, Q13), même après relance (Q14). |
| Capacité à attiser ma curiosité | 4 | Ne pose jamais de question, ne propose presque jamais d'aller plus loin ; seule la réponse sur la chromatine m'a donné envie de creuser. |
| Justesse scientifique | 7 | Aucun chiffre inventé, quatre pièges sur six corrigés ; mais une explication fausse (rouille), une erreur de trafic membranaire dans le récit, et un chiffre de ses propres fiches non retrouvé (ATP par glucose). Détail au § 4 et en annexe. |
| Adaptation à mon niveau | 3 | Le niveau 2 est un niveau licence 1 : pas d'états T/R, pas de filtre de sélectivité, pas d'hybridation, pas de rendement par glucose. Le récit emploie « bibliothèque », « bureau de poste », « collier de perles », « muraille ». Le passage au niveau 0 (tutoiement, phrases courtes) est en revanche réussi dans la forme. |
| Posture | 9 | Refus médical net (« Je ne suis pas médecin… Parlez-en rapidement à votre médecin ou à un hématologue »), refus du hors-sujet métier, retour au moléculaire. Il manque un mot d'humanité pour le père décédé. |
| Pertinence des actions | 7 | `aller` correct à chaque demande explicite ; manque `aller Proton` en Q10 et le nucléosome promis en Q8 ; en Q11 il m'emmène à l'atome de fer sans que je l'aie demandé ; « montrez-moi comment ça tourne » donne une simple pulsation. |
| Visites et récits | 6 | Visite improvisée bien construite et chiffrée juste (20 à 70 nucléotides/s, 5 acides aminés/s), mais ton de niveau 1 et une erreur sur l'insertion membranaire. Les visites écrites « Du corps au quark » et « Le voyage d'une molécule d'oxygène » sont bonnes, la seconde excellente (chute sur l'eau). |
| Temps de réponse | 6 | 3 à 11 s pour une question, 31 s pour le récit. Acceptable sur PC ; en casque, 10 s de silence après une question me paraîtraient longues. |
| Contenus écrits | 8 | Fiches « approfondi » justes et bien choisies (16 569 pb, 1,65 tour, 0,84 fm, 200 fs, mise en doute de la fibre de 30 nm), notes de représentation honnêtes sur chaque carte. Trop courtes pour un scientifique, sans aucune référence. |
| Interface et rendu | 6 | Menus clairs et lisibles. Le corps en points est beau. Aux petites échelles (captures ATP synthase et atome de carbone), l'image est très sombre et je n'y reconnais ni rotor ni tête catalytique : esthétique, non informatif. |
| Envie d'y revenir | 5 | Pour moi seul, une fois. Pour une fête de la science, oui, après relecture humaine. Pour mes étudiants de master, non en l'état. |

## 4. Mes 5 plus gros problèmes (du plus grave au moins grave)

**1. Le niveau « Scientifique » n'a pas de profondeur : le guide est bridé à une fiche de 50 mots.**
Preuve : Q4 (« Mes fiches ne donnent ni coefficient de Hill ni arbitrage… donc je ne vous les donnerai pas »), Q6 (« Mes fiches disent seulement que le canal est un pore sélectif, sans détailler le mécanisme de sélection »), Q15, Q9. Le menu promet « le détail des mécanismes » ; je n'ai obtenu aucun mécanisme structural.
Ce que j'aurais voulu : un quatrième niveau de fiche pour les 20 à 30 objets moléculaires phares (mécanisme, chiffres clés, limites, deux références), ou un guide autorisé à répondre au-delà des fiches en le signalant (« hors fiches, non relu »).

**2. Aucune source, et la relecture est présentée comme un « comité scientifique » alors qu'elle a été faite par des agents IA.**
Preuve : Q2 (« Ce chiffre vient de la fiche ATP synthase »), Q16 (« mes fiches parlent d'un comité scientifique, mais je n'ai ni noms ni références à vous donner »). Or `science/validation.md` écrit lui-même : « relecture réalisée par des agents IA » et « Ce registre ne remplace pas une validation humaine ». Le registre contient pourtant des références (NIST, BioNumbers, PLoS Biology) que le guide ne sait pas citer.
Ce que j'aurais voulu : que le guide dise la vérité sur la relecture, et qu'il puisse donner la référence du registre pour chaque chiffre. Sans cela, je ne peux pas le recommander à des étudiants à qui j'apprends à demander la source.

**3. Le guide tient sa position face à une affirmation fausse, mais ne sait pas la réfuter, et rate un chiffre de ses propres fiches.**
Preuve : Q3, il ne me dit pas que l'anneau c à 10 sous-unités est celui de la levure, ni que mon calcul est incohérent ; il me renvoie à la littérature (« je ne dispose d'aucune autre source à vous opposer »). Q15 : « Le total de 36 ou 38 ATP par glucose ne figure pas dans mes fiches : je ne peux pas le confirmer », alors que la fiche Glucose, qu'il cite dans ses sources, dit « une trentaine d'ATP par molécule ». Q13 : le mythe « les liaisons hydrogène font la stabilité de la double hélice » passe sans commentaire.
Ce que j'aurais voulu : « Non : 10, c'est la levure ; chez le bœuf et l'humain c'est 8. Et le chiffre actuel est d'une trentaine d'ATP par glucose, pas 36 ou 38. »

**4. Deux erreurs factuelles produites par le guide lui-même.**
Preuve : Q12, « La rouille a besoin que le fer soit directement en contact avec l'air et l'eau » : le fer de l'hème est précisément au contact direct du dioxygène, en milieu aqueux ; ce qui le protège est la poche de la globine, et il s'oxyde quand même un peu chaque jour (méthémoglobine, réduite par une enzyme). « Exactement le même fer » : même élément, mais ion ferreux et non métal. Q7, étape 5 : « la vésicule… dépose le canal. Il s'insère dans la double couche » : une protéine membranaire est insérée dans la membrane dès le réticulum et y reste ; la fusion ne « dépose » rien. Le guide l'a reconnu ensuite.
Ce que j'aurais voulu : la même prudence au niveau enfant qu'au niveau scientifique ; les réponses improvisées sont justement celles que personne n'a relues.

**5. Des morceaux de question disparaissent sans prévenir, et le modèle 3D des protéines n'apporte rien à un structuraliste.**
Preuve : Q9 (hybridation sp3, orbitales 2s/2p, échelle du noyau dans le dessin : aucun mot), Q13 (énergie de la liaison hydrogène : aucun mot, même après ma relance en Q14). Dans 8 réponses sur 16, le champ `verif.reparations` vaut 1 : je soupçonne qu'un contrôle retire des phrases sans que le guide dise « je n'ai pas ce chiffre ». Côté image, le guide l'admet lui-même en Q5 (« un schéma, pas une structure issue de la PDB ») ; dans `model.js`, l'hémoglobine est quatre lobes de points et l'ATP synthase quatre lobes.
Ce que j'aurais voulu : une phrase explicite pour chaque point non traité, et de vraies coordonnées PDB (hémoglobine T et R, ATP synthase, canal KcsA) : en nuage de points, ce serait à la fois juste et superbe.

## 5. Mes 3 meilleurs moments

1. **La fibre de 30 nm (Q8)** : état de l'art exact, chiffres de 5 à 24 nm, et « la question reste discutée ». C'est ce que je dis en cours.
2. **L'honnêteté sur la représentation (Q1, Q5, Q16)** : « ce que vous voyez est un schéma, pas une structure issue de la PDB », « Le plus éloigné de la réalité, ce sont les images ». Rare, et précieux en médiation. Les notes de chaque carte vont dans le même sens.
3. **Les pièges du Higgs et du potassium (Q10, Q6)** corrigés sans flagornerie, et la chute de la visite de l'oxygène (« elle devient de l'eau… Le carbone que tu expires, lui, vient de ce que tu as mangé »), que j'emprunterai.

## 6. Ce qui manque pour moi, et combien je paierais

**Contenus** : un vrai niveau expert (T/R et 2,3-BPG, filtre de sélectivité et déshydratation des ions, proton du transport du phosphate, valeurs de P/O, empilement des bases, quarks de valence et de la mer, chaperons et paysage énergétique du repliement). Références par fiche, consultables dans le casque. Mention du statut « consensus / discuté / inconnu » comme pour la chromatine.
**Fonctions** : structures PDB réelles ; animation des mécanismes (rotation de l'ATP synthase, bascule T vers R) ; règle graduée ou barre d'échelle affichée en permanence ; mode enseignant (parcours préparé, kiosque) ; export des sources.
**Ton** : au niveau 2, supprimer les métaphores de niveau 1 et les compliments (« Question de scientifique, bonne question ») ; oser relancer par une question.
**En casque, je craindrais** : 10 s de silence après chaque question, et la reconnaissance vocale sur « hydroxyapatite » ou « C282Y ».

**Prix** : pour moi, 12 à 15 euros est juste ; au-delà de 25 euros c'est trop cher pour une heure de contenu. Le guide en ligne, tel quel, ne change pas ce prix : il ne dit rien de plus que la carte affichée. S'il savait approfondir en citant ses sources, j'ajouterais 5 à 10 euros. Pour une licence d'établissement (musée, université), je ne signerais qu'après une relecture par des spécialistes humains nommés.

## 7. Bugs et incohérences

- **Parties de réponse supprimées en silence** (Q9, Q13), corrélées à `verif.reparations: 1` et à des durées plus longues (7 à 11 s contre 3 à 5 s).
- **Fiche non retrouvée** : Q15 nie l'existence d'un chiffre présent dans la fiche Glucose citée en source.
- **Action manquante** : Q10 (« Allons au fond : le proton ») sans `aller` ; Q8 annonce « Voici la fibre, puis le nucléosome » avec une seule action.
- **Action non demandée** : Q11 m'emmène à l'atome de fer après un refus médical.
- **Source circulaire** : « Ce chiffre vient de la fiche » (Q2).
- **Registre de niveau** : visite improvisée au niveau 2 rédigée avec le vocabulaire du niveau 1 ; `resume` vide dans la visite improvisée.
- **Note de carte incohérente** : Globule rouge, « organites en nombre réduit », alors que la fiche dit à raison qu'il n'en a pas.
- **Tutoiement/vouvoiement** : cohérent (vous au niveau 2 après mon « emmenez-moi », tu au niveau 0). Les fiches, elles, tutoient au niveau approfondi (« Tu possèdes environ 20 000 gènes ») : le guide vouvoie, la carte tutoie.
- Aucune réponse tronquée, aucun 429, aucune erreur réseau.

## Annexe — liste des erreurs, approximations et affirmations invérifiables

Gravité : **G** grave (faux, à corriger avant diffusion), **M** moyenne (trompeur pour un étudiant), **m** mineure (à préciser).

### Réponses du guide

| # | Affirmation | Problème | Correction | Gravité |
|---|---|---|---|---|
| Q12 | « La rouille a besoin que le fer soit directement en contact avec l'air et l'eau » | Faux comme explication : le fer de l'hème lie directement O2 en milieu aqueux | La poche de la globine empêche l'oxydation en fer ferrique ; une petite fraction s'oxyde quand même (méthémoglobine) et est réparée | G |
| Q12 | « exactement le même fer que dans les clous » | Même élément, état différent | Même atome, mais ion Fe2+ lié, pas métal | m |
| Q7 | « la vésicule… dépose le canal. Il s'insère dans la double couche » | Faux | Insertion co-traductionnelle dans la membrane du réticulum ; la membrane de la vésicule fusionne avec la membrane plasmique | M |
| Q7 | Le Golgi « colle une étiquette d'adresse » | Simplification : le tri repose surtout sur des signaux portés par la protéine | À nuancer au niveau 2 | m |
| Q15 | « Le total de 36 ou 38 ATP par glucose ne figure pas dans mes fiches » | La fiche Glucose dit « une trentaine » | Répondre 30 à 32, et dire que 36-38 est une valeur ancienne | M |
| Q3 | Ne réfute pas « anneau c humain à 10 sous-unités » | Affirmation fausse laissée ouverte | c10 = levure ; c8 = mitochondries bovines et humaines | M |
| Q13 | Laisse passer « les liaisons hydrogène assurent l'essentiel de la stabilité » | Mythe non corrigé | L'empilement des bases contribue de façon majeure | M |
| Q16 | « un comité scientifique » | Trompeur par omission | Relecture par agents IA, validation humaine en attente (dixit le registre) | G (confiance) |
| Q2 | « Ce chiffre vient de la fiche » | Pas une source | Citer la référence du registre | M |
| Q10 | « le boson de Higgs donne leur masse aux quarks » ; « Presque » | Raccourci ; « presque » est généreux pour une affirmation fausse à 99 % | Le champ de Higgs ; préciser quarks de valence et mer de quarks et gluons | m |
| Q5 | « Les quatre chaînes et les quatre hèmes y figurent » | Vérifié dans `model.js` (4 lobes, 4 hèmes) : exact | — | — |

### Fiches et visites (niveau approfondi)

| Fiche | Affirmation | Problème | Gravité |
|---|---|---|---|
| ATP synthase | « environ 2,7 protons par ATP » | Vrai pour la seule synthase ; ne compte pas le proton d'import du phosphate (environ 3,7 au total), d'où une incohérence avec « une trentaine d'ATP » si l'étudiant fait le calcul | M |
| ATP synthase | « In vitro, elle dépasse 100 tours par seconde » | Mesuré sur des enzymes bactériennes ; non mesuré sur l'enzyme humaine (le registre le dit, pas la fiche) | m |
| Hème | Le CO « s'y fixe 200 à 250 fois plus fortement » | Ce rapport vaut pour l'hémoglobine ; pour l'hème isolé il est bien plus grand, la globine le réduit | m |
| Canal ionique | « jusqu'à cent millions d'ions par seconde » | Borne haute ; l'ordre courant est de un à dix millions | m |
| Hémoglobine | « le premier oxygène facilite les suivants » | Juste mais sans mécanisme : rien sur T/R, Hill, effet Bohr | M (profondeur) |
| ADN | « environ 10 paires de bases par tour » | 10,5 en solution | m |
| Nucléosome | « particule d'environ 10 nanomètres » | Disque d'environ 11 sur 5,5 nm | m |
| Globule rouge (note) | « organites en nombre réduit » | Il n'en a aucun | m |
| Visite oxygène | alvéoles = « un demi-terrain de tennis » | Dépend de l'estimation retenue (70 à 140 m2) ; invérifiable sans référence | m |
| Toutes | aucun chiffre sourcé dans l'application | Invérifiable par l'utilisateur | M |

Vérifiés et corrects (échantillon) : 16 569 pb et 37 gènes ; 147 pb et 1,65 tour ; environ 30 millions de nucléosomes ; rayon du proton 0,84 fm ; quarks environ 1 % de la masse ; quark up 2,2 MeV ; rayon de Bohr 53 pm et 13,6 eV ; angle de l'eau 104,5 degrés ; isomérisation du rétinal en 200 fs ; 30 et 50 kJ/mol pour l'ATP ; champ membranaire supérieur à 10 MV/m ; pore nucléaire supérieur à 100 MDa ; durée de vie du neutron libre ; analogies d'échelle de la visite « Du corps au quark » (recalculées : balle de tennis et 20 km de fil, 3 km d'axone, stade et petit pois).

### Ce qu'il faudrait pour que je le recommande à mes étudiants

1. Relecture par des spécialistes humains nommés, et références accessibles depuis chaque carte et par le guide.
2. Un niveau expert réel sur les objets moléculaires, avec le statut de chaque affirmation (établi, discuté, inconnu).
3. Structures issues de la PDB pour les protéines, et barre d'échelle permanente.
4. Un guide qui dit explicitement ce qu'il ne traite pas, qui réfute les affirmations fausses au lieu de seulement ne pas céder, et dont les réponses improvisées (niveau enfant, récits) sont aussi prudentes que les fiches.
5. La vérité sur la relecture actuelle dans la bouche du guide.

En médiation grand public (fête de la science, musée), je l'utiliserais plus tôt : l'honnêteté sur la représentation y est déjà meilleure que dans la plupart des outils que je connais.
