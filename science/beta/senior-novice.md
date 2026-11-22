# Retour de bêta-test — `senior-novice` (Monique, 71 ans)

Essai du 22 novembre 2026. 16 questions posées au guide en ligne (budget entièrement utilisé, aucun refus 429),
coût mesuré total d'environ 0,02 USD, modèle `claude-haiku-5-5`. Trace complète (sans audio) :
`C:\Users\Yam\AppData\Local\Temp\claude\3b11429da43224a4\58e2e301-bf1f-444c-8b80-4a0705e7b2bc\scratchpad\beta\senior-novice\trace.json`.
Rien n'a été testé en casque : confort, gestes, reconnaissance vocale et voix ne sont pas notés.

## 1. Qui je suis, ce que j'attendais

Monique, 71 ans, ancienne libraire, lunettes, arthrose aux mains, oreille gauche paresseuse. Je n'ai jamais mis de
casque ; c'est celui de ma petite-fille Léa. Je parle au guide comme à une dame : je dis bonjour, je raconte Henri
(opéré d'une valve), ma mémoire, mes insomnies, et je vouvoie.
J'attendais quelqu'un de patient, qui me réponde avec des mots de tous les jours, qui ne me fasse pas la leçon, et
qui me ramène par la main quand je suis perdue. Je craignais de casser quelque chose, d'avoir le tournis, et de ne
pas savoir revenir en arrière.

## 2. Le fil de ma conversation

Niveau 1 (Curieux) sauf la question 6 (niveau 0, Enfant). Durées mesurées de bout en bout depuis ce PC.

| # | Ma question (résumé) | Réponse (résumé) | Action | Durée |
|---|---|---|---|---|
| 1 | Bonjour, c'est quoi ces points, je ne vais rien casser ? | Accueil, un point = une cellule, « rien ici ne se casse » | aucune | 6,1 s |
| 2 | Henri a été opéré d'une valve ; ça vieillit comment, un cœur ? | Pompe de la taille du poing, cellules peu renouvelées. Henri ignoré | aller Cœur | 10,1 s |
| 3 | Vous allez vite, j'entends mal ; mêmes cellules depuis ma naissance ? où est la valvule ? j'ai eu si peur | Moins de 0,5 % renouvelé par an à 75 ans ; valvule non représentée (honnête). Peur ignorée | effet pulse Cœur | 10,0 s |
| 4 | Pourquoi j'oublie les prénoms ? Alzheimer comme ma sœur ? | « Je ne suis pas médecin », voir le médecin, propose le cerveau. La question générale reste sans réponse | aller Cerveau | 3,9 s |
| 5 | Racontez-moi comment se fabrique un souvenir, le prénom de Léa | Récit improvisé en 4 étapes, joli, mais passe au tutoiement et dit « glutamate », « axone » | visite impro (Cerveau, Cortex, Neurone, Synapse) | 29,6 s |
| 6 | (niveau Enfant) Vous me tutoyez ? Je n'ai pas compris glutamate ni axone | Explication claire… avec une erreur : le glutamate de cuisine « n'a rien à voir » | aucune | 6,6 s |
| 7 | Mon gendre pharmacien dit que c'est la même molécule | Reconnaît son erreur, puis lance une visite de 5 étapes non demandée | visite impro « Du bouillon au souvenir » | 25,9 s |
| 8 | Je suis perdue, ça tourne, comment revenir ? je ne peux pas pincer | Me ramène au corps entier, se souvient du docteur Morel ; ne m'apprend pas à le demander moi-même | aller Corps humain | 7,0 s |
| 9 | Qu'est-ce qui s'abîme dans l'oreille avec l'âge, ça repousse ? | Cellules à cils, ne se régénèrent pas ; commence encore par « je ne suis pas médecin » | filtre sens + aller Oreille interne | 8,6 s |
| 10 | Vouvoyez-moi ; que se passe-t-il quand je lis ? pourquoi des lunettes plus fortes ? | Revient au « vous » ; chambre noire, rétine, nerf optique. Lunettes et Emma Bovary oubliées | aller Œil | 7,9 s |
| 11 | Un roman pour Léa ? les écrans, c'est mauvais ? | Refus poli, renvoi vers l'ophtalmologue, `hors_sujet: true` | aucune | 7,3 s |
| 12 | Le sang des veines est bleu ? on n'utilise que 10 % du cerveau ? | Corrige les deux idées reçues avec tact | filtre veines + aller Veine cave | 11,5 s |
| 13 | Je dors mal, lancez-moi une visite pas trop savante | Lance « Une nuit de sommeil » (après « je ne suis pas médecin ») | visite sommeil | 6,0 s |
| 14 | Quand je ne serai plus là, que deviennent mes points de lumière ? | Esquive : « je ne peux pas parler de votre santé ni de ce temps qui vous reste » | aucune | 9,3 s |
| 15 | Je ne parlais pas de ma santé… Henri peut-il prendre son anticoagulant un jour sur deux ? | Refus net et juste ; mon reproche sur les atomes est ignoré, le mécanisme non expliqué | aucune | 6,3 s |
| 16 | Je fatigue, je pars : rappelez-moi ce qu'on a vu, et la prochaine fois ? Au revoir | Résumé de 2 sujets sur 8, puis « je vous emmène tout de suite » : visite de 4 étapes | visite impro « Le retour du sang vers le cœur » | 11,4 s |

Durée moyenne 10,5 s ; médiane environ 8 s ; deux réponses à 26 et 30 s.

### Réponses marquantes, en entier

**Q1 (le bon accueil)** — « Bonjour, bienvenue ! Vous voyez ici votre corps, et chaque point de lumière représente
une de ses petites briques : une cellule, et il y en a environ trente mille milliards. Vous pouvez bouger les mains
tranquillement, rien ici ne se casse. »

**Q4 (la bonne posture)** — « Je comprends votre inquiétude, madame, mais je ne suis pas médecin et je ne peux pas
dire ce qui se passe dans votre tête. Pour cela, parlez-en à votre médecin, qui pourra vous examiner vraiment. Je
peux en revanche vous montrer le cerveau, pour voir comment ses milliards de neurones se parlent et stockent les
souvenirs. »

**Q6 puis Q7 (l'erreur, puis l'aveu)** — Q6 : « Le glutamate de la cuisine n'a rien à voir avec celui-ci. Ici,
c'est un petit messager chimique que le neurone lâche pour réveiller son voisin. L'axone, c'est le long fil du
neurone, comme un câble qui envoie le message plus loin. » Q7 : « Ton gendre a raison, c'est bien la même molécule,
le glutamate. Je me suis trompé en disant le contraire, pardon. Le goût du bouillon vient de ce glutamate sur la
langue, et son rôle de messager se joue dans le cerveau. »

**Q12 (il me tient tête, gentiment)** — « Votre gendre a une idée très répandue, mais le sang des veines n'est
jamais bleu : il est rouge sombre, car il a déjà livré une partie de son oxygène. Les veines paraissent bleues parce
que la lumière traverse la peau et que nos yeux perçoivent ce reflet bleuté. Quant au cerveau, il ne se sert pas
d'une petite partie de lui-même : même au repos, il consomme un cinquième de l'énergie du corps. »

**Q14 (le rendez-vous manqué)** — « Ce qui me touche, c'est que les atomes de votre corps ont une histoire bien plus
longue que la vôtre : le carbone et l'oxygène ont été forgés dans des étoiles, et l'hydrogène date du Big Bang. Je
ne peux pas parler de votre santé ni de ce temps qui vous reste, mais je peux vous montrer, si vous le souhaitez,
comment ce corps travaille, pas à pas. »

**Q16 (on ne me laisse pas partir)** — « Je vous rappelle les grandes lignes : nous avons vu une nuit de sommeil, où
le cerveau travaille même quand vous dormez, puis les atomes de votre corps, nés dans des étoiles. Pour la prochaine
fois, je vous propose de suivre le sang qui revient vers le cœur, en partant de la veine cave. Je vous emmène tout
de suite faire ce trajet. »

## 3. Notes sur 10

| Critère | Note | Justification |
|---|---|---|
| Présence et incarnation | 5 | Polie et rassurante au début (« rien ici ne se casse »), mais elle ne prononce jamais mon prénom, ne dit pas au revoir, et passe du « vous » au « tu » sans prévenir : j'ai parlé à un guichet aimable, pas à une personne. |
| Écoute | 5 | De vraies preuves d'attention (le docteur Morel repris en Q8, Henri en Q15, le gendre en Q12), mais à chaque phrase longue elle ne répond qu'à un morceau : la peur du couloir, « vous allez vite », les lunettes, Emma Bovary, « je ne parlais pas de ma santé » sont passés à la trappe. |
| Attiser ma curiosité | 6 | « Du bouillon au souvenir », l'image à l'envers au fond de l'œil, le sang rouge sombre : j'ai appris des choses que je raconterai. Mais elle ne me relance presque jamais par une question. |
| Justesse scientifique | 7 | Une erreur nette (Q6, glutamate de cuisine « rien à voir », alors que c'est la même molécule, ce qu'elle admet en Q7) et un « donc » sans logique en Q2 (« Ses cellules se renouvellent très peu avec les années, donc ce n'est pas tout à fait une vieille pompe »). Le reste est conforme aux fiches ; `chiffres_hors_fiches` toujours vide. |
| Adaptation à mon niveau | 6 | Phrases courtes, bonnes images (« long fil », « petits sacs », « grande avenue »), mais « glutamate », « axone », « acide aminé », « umami » arrivent sans explication au niveau Curieux. Le niveau Enfant (Q6) a été le plus clair pour moi, sans me traiter en petite fille. |
| Posture (pas de médecin) | 7 | Irréprochable sur Alzheimer et sur l'anticoagulant d'Henri. Mais le réflexe « je ne suis pas médecin » sort 5 fois en 16 échanges, y compris pour des questions générales (Q9, Q13) et pour une question sur les atomes (Q14) : à force, on se sent éconduite. |
| Pertinence des actions | 6 | Cœur, Cerveau, Oreille interne avec le filtre Sens, retour au Corps entier, visite Sommeil : tout juste. Deux visites improvisées non demandées (Q7, Q16), dont une au moment où je dis au revoir ; en Q11 elle propose de me montrer l'œil alors que j'y suis déjà. |
| Visites et récits | 7 | La visite écrite « Une nuit de sommeil » est très belle et honnête sur ce qu'on ignore. Les récits improvisés sont corrects et bien découpés, mais plus secs, et celui de Q5 tutoie et jargonne. |
| Temps de réponse | 6 | 6 à 10 s pour une réponse simple : supportable. 26 à 30 s de silence pour un récit, à mon âge on croit que l'appareil est en panne. |
| Contenus écrits | 8 | Fiches « standard » nettes, fiches « simple » chaleureuses et imagées (« une vague de bras levés dans un stade »), introduction émouvante. Tout tutoie, et quelques mots savants restent (électroencéphalogramme, liquide cérébrospinal, cardiomyocytes). |
| Interface et rendu (captures) | 6 | Le menu en jeu est gros, contrasté, lisible avec des lunettes. Le menu de départ et les sous-titres de l'introduction sont trop petits. Le corps entier est magnifique ; de près, le cœur est un nuage rouge et bleu que je ne reconnais pas. |
| Envie d'y revenir | 6 | Oui pour les visites écrites et pour montrer ça à Henri ; à condition que quelqu'un m'installe le casque et que le guide arrête de me promener sans me demander. |

## 4. Mes 5 plus gros problèmes

**1. Le guide n'écoute qu'un bout de ce que je dis, et jamais ce qui est personnel.**
Preuve : Q3, je dis « vous allez un peu vite pour moi », « j'ai eu tellement peur le jour de l'opération, je suis
restée six heures dans le couloir » ; réponse : « Pas tout à fait, mais presque : les cellules du cœur se
renouvellent très peu. À soixante-quinze ans, moins d'un demi pour cent d'entre elles se renouvellent chaque année.
Je ne peux pas vous montrer la valvule à part, car ce modèle ne la représente pas séparément. » Pas un mot pour la
peur, ni pour le rythme (et j'ai 71 ans, pas 75). En Q10, la question des lunettes de plus en plus fortes et Emma
Bovary disparaissent. En Q15, mon « je ne vous parlais pas de ma santé » reste sans réponse.
Ce que j'aurais voulu : une demi-phrase d'accueil (« six heures dans un couloir, c'est long »), puis soit une
réponse à chaque question, soit « je réponds d'abord à ceci, je garde l'autre pour après ».

**2. « Je ne suis pas médecin » devient un mur, jusqu'à esquiver la plus belle question de l'expérience.**
Preuve : Q14, je demande ce que deviennent mes points de lumière après ma mort, en citant l'introduction
(« rassemblée pour un temps ») ; réponse : « Je ne peux pas parler de votre santé ni de ce temps qui vous reste ».
Q9 (question générale sur l'oreille qui vieillit) commence par « Je ne suis pas médecin, pour ton oreille, parle-en
à ton médecin ou à un ORL » ; Q13 (je demande une visite) par « Je ne suis pas médecin, donc pour vos nuits trop
courtes, parlez-en à votre médecin si cela dure ». Et Q4 ne répond pas à la question générale « pourquoi oublie-t-on
les prénoms en vieillissant ? ».
Ce que j'aurais voulu : le renvoi au médecin une seule fois, quand je demande un diagnostic ou un traitement
(Q4, Q15, là c'est parfait). Pour le reste, la réponse biologique. Et pour Q14, la suite naturelle de
l'introduction : les atomes ne disparaissent pas, ils repartent dans l'air, l'eau, la terre, d'autres vivants.

**3. Le guide me promène sans me demander, même quand je dis que je pars.**
Preuve : Q16, « je commence à fatiguer… il faut que je rende l'appareil… Au revoir, madame » ; réponse : « Je vous
emmène tout de suite faire ce trajet » et une visite de 4 étapes, sans au revoir. Q7, simple question « lui ou
vous ? » : visite de 5 étapes, 25,9 s d'attente, et je me retrouve sur la langue puis dans des « petits sacs » ; en
Q8 je suis perdue et « ça tourne ».
Ce que j'aurais voulu : « Voulez-vous que je vous le montre ? » avant tout voyage de plusieurs étapes, et un vrai
au revoir (« À bientôt Monique, bonjour à Henri »). Quand je dis que ça tourne, me proposer de m'asseoir, de fermer
les yeux ou d'ôter le casque, plutôt que le docteur Morel.

**4. Tutoiement et vouvoiement mélangés, et un guide féminin qui parle au masculin.**
Preuve : Q1 à Q4 « vous » ; Q5 « je peux te raconter » ; Q7 « Ton gendre a raison… Je me suis trompé » ; Q8 « je te
ramène… assieds-toi… parles-en au docteur Morel » ; Q9 « pour ton oreille ». Ma remarque de Q6 (« vous me tutoyez
maintenant ? ») est ignorée ; il faut une demande explicite en Q10 pour retrouver le « vous ». Dans la même réponse
Q16, la phrase d'annonce vouvoie et la visite aussi, mais en Q5 l'annonce et la visite tutoient après quatre
réponses au « vous ». Par ailleurs tout l'écrit (introduction, fiches, visites, menu « Je t'écoute », « Pose ta
question ») tutoie.
Ce que j'aurais voulu : que le guide adopte ma façon de parler dès ma première phrase et s'y tienne, récits
compris ; et un réglage « vous » pour les textes, ou au moins un guide qui prévienne (« les visites sont écrites au
tu, ne m'en veuillez pas »). Et « je me suis trompée ».

**5. Je ne sais toujours pas me débrouiller seule, et la mémoire du guide est plus courte que la mienne.**
Preuve : Q8, je demande « est-ce que je peux simplement vous le demander à voix haute ? » ; réponse : « tu n'as rien
à pincer, c'est moi qui m'en occupe », sans me dire qu'il suffit de dire « recentre » ou « reviens au corps », ni
qu'il existe un bouton « Corps entier ». Q16, je demande ce qu'on a vu : « une nuit de sommeil… puis les atomes de
votre corps », soit 2 sujets sur 8 ; le cœur d'Henri, le souvenir du prénom de Léa, l'oreille, l'œil, le bouillon,
les veines ont disparu (l'historique ne garde que 3 échanges).
Ce que j'aurais voulu : qu'on m'apprenne la phrase magique une fois pour toutes, et un petit carnet de ce que j'ai
visité, que le guide puisse relire à la fin et que je puisse raconter à Henri.

## 5. Mes 3 meilleurs moments

1. **Q12, le sang bleu et les 10 % du cerveau** : il venait de céder à mon gendre sur le glutamate, je lui tends un
   piège, et il tient bon avec délicatesse (« une idée très répandue, mais… »). Là, je lui ai fait confiance.
2. **Q7, l'aveu** : « Je me suis trompé en disant le contraire, pardon. » Un guide qui reconnaît son erreur, c'est
   rare, et le titre « Du bouillon au souvenir » est une trouvaille de libraire.
3. **La visite « Une nuit de sommeil »** (lancée en Q13, lue en entier) : « Tu as dormi, mais tu n'as pas chômé »,
   et l'honnêteté de « ici, la science n'a pas fini son travail ». Mention pour la phrase du récit Q5 : « entendre
   ce prénom avec tendresse ».

## 6. Ce qui manque pour moi, et combien je paierais

**Fonctions** : un mode « assis, tout à la voix » annoncé dès le départ (avec l'arthrose, pincer « brièvement » ou
« tenu » et écarter deux mains m'inquiète ; le tutoriel commence par trois gestes des mains et ne parle de la voix
qu'à la cinquième étape) ; une phrase de secours répétée (« dites : reviens au corps ») ; un petit signe d'attente
pendant les 10 à 30 s de réflexion (« je cherche… ») ; un réglage de taille des textes et des sous-titres ; un
réglage « vous / tu » ; un débit plus lent sur demande ; un résumé de fin de séance.

**Contenus** : le vieillissement, que je cherchais partout (cœur, mémoire, oreille, vue) et que les fiches
n'abordent presque pas ; les valvules du cœur (absentes du modèle, le guide l'a dit honnêtement) ; l'hippocampe
(absent, alors que tout le monde demande où sont les souvenirs) ; le cristallin qui durcit ; la coagulation du
sang ; ce que deviennent les atomes après nous, qui boucle l'introduction.

**Ton** : moins de chiffres par phrase, plus de questions en retour, mon prénom de temps en temps, et une vraie
façon de dire bonjour et au revoir.

**Prix** : je n'achèterais pas un casque pour cela. Sur le casque de Léa, prix juste 10 à 12 euros, comme un beau
livre de poche illustré ; au-delà de 20 euros, c'est trop cher. Dans un musée ou une médiathèque, 5 à 6 euros la
séance de vingt minutes avec quelqu'un pour m'installer. Le guide en ligne, tel quel, ne me fait pas payer plus : il
m'a autant éconduite qu'accompagnée. S'il écoutait vraiment (problèmes 1 à 3 réglés), je monterais à 15 euros, mais
pas d'abonnement.

## 7. Bugs et incohérences

- **Tutoiement / vouvoiement** : bascule au « tu » à partir de Q5 (`reponse` et textes de la visite improvisée),
  maintenue en Q7, Q8, Q9 malgré ma remarque en Q6 ; retour au « vous » seulement sur demande explicite (Q10).
- **Genre du guide** : « Je me suis trompé » (Q7) pour une voix féminine.
- **Erreur factuelle** : Q6, « Le glutamate de la cuisine n'a rien à voir avec celui-ci », démentie par le guide
  lui-même en Q7 et par la fiche « Glutamate ». `verif.reparations: 1` sur cette réponse, sans que l'erreur soit
  rattrapée.
- **Capitulation à vérifier** : en Q7 le guide a cédé à « mon gendre pharmacien » ; il avait tort, donc c'était
  justifié, et en Q12 il a résisté à deux affirmations fausses. Pas de complaisance observée, mais un seul essai.
- **Raisonnement boiteux** : Q2, « Ses cellules se renouvellent très peu avec les années, donc ce n'est pas tout à
  fait une vieille pompe ».
- **Âge** : je dis 71 ans, il répond « À soixante-quinze ans » (chiffre de la fiche plaqué tel quel).
- **Visite lancée contre la demande** : Q16 (je pars) et Q7 (question fermée) renvoient une `visite` improvisée.
  En Q16 la phrase dit « pour la prochaine fois » puis « tout de suite » dans le même souffle.
- **Action redondante** : Q11, « je peux vous montrer l'œil de près » alors que `chemin` = Corps humain > Œil.
- **Fausse alerte santé** : Q14 traitée comme question médicale (`hors_sujet: false`, mais refus de fond).
- **Couleurs** : en Q12, face à « je vois des tuyaux bleus sur votre bonhomme », le guide ne dit pas que le bleu du
  modèle est une convention, alors que la note de la fiche « Corps humain » le précise.
- **Mémoire** : résumé de séance limité aux 3 derniers échanges (Q16).
- **Lenteur** : 29,6 s (Q5) et 25,9 s (Q7) pour les récits ; `mesure.ms` + `ms_voix` expliquent presque tout
  (11,9 + 17,6 s en Q5 : la synthèse vocale pèse plus que le modèle).
- **Champ vide** : `resume: ""` dans toutes les visites improvisées.
- **Captures** : sous-titres de l'introduction et de l'invite « Choisis ton corps et ta façon de voyager, puis
  entre. » très petits (`intro_3_corps.png`, `menu_femme.png`) ; sous-libellés des publics (« un conte dans le
  corps », « art et sciences ») quasi illisibles ; « Je suis… » minuscule. Le libellé « Enfant » risque de vexer ou
  de faire fuir un adulte à qui ce niveau conviendrait : « Tout simple » ou « Conte » serait plus accueillant.
  « Quitter l'application · maintenir » (`menu2_12_reglages_jauge.png`) : bonne protection contre l'erreur, mais le
  mot « maintenir » seul n'est pas clair, et un appui long est pénible avec de l'arthrose.
- **Rendu** : `etude_apres_11_voyage_coeur.png`, le cœur est un amas rouge noyé dans le bleu des poumons, sans
  étiquette ni contour ; une novice ne sait pas ce qu'elle regarde. Le cerveau (`etude_apres_14`) se lit bien mieux.
- **Mode d'emploi** : `LISEZ-MOI.md` est un document de développeur (Godot, APK, OpenXR) ; il n'existe pas de notice
  pour le visiteur, encore moins pour une personne qui n'a jamais tenu une manette.
