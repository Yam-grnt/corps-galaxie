# Viabilité à l'échelle d'un guide conversationnel en ligne (grand modèle de langage)

Étude du département « intelligence économique et marketing » — 22 novembre 2026.
Question posée : « À quel point c'est fou de mettre une API pour améliorer la conversation et donner au guide un
pouvoir d'animation, de création de visites spontanées et d'activation de filtres ? Est-ce viable à l'échelle ? »

Convention : **[V]** = vérifié ce jour sur la source citée ; **[E]** = estimation ou hypothèse de notre part ;
**[M]** = chiffre de mémoire, non revérifié. Tous les prix sont en USD hors mention contraire. Cette étude n'est pas
un avis juridique.

---

## 0. Réponse courte

**Ce n'est pas fou. C'est même devenu bon marché — à une condition : que la voix reste synthétisée dans le casque.**

- Avec le modèle économique actuel de la gamme Claude (Haiku 5.5 : 0,10 $ / 0,50 $ par million de jetons, lecture de
  cache 0,01 $), un échange coûte environ **0,04 centime**, une séance médiane **moins d'un centime**, et la « vie »
  d'un utilisateur médian **environ 0,04 $**, soit **0,4 à 0,5 % du revenu net** d'une vente à 14,99 $.
  La précédente estimation interne (0,2–0,3 $ par utilisateur) correspondait aux prix de la génération précédente ;
  elle est aujourd'hui divisée par cinq à dix.
- Le point de rupture (l'IA mange tout le revenu net d'une vente) se situe vers **15 000 à 25 000 échanges** par
  utilisateur : hors d'atteinte d'un usage humain. Le coût n'est donc **pas** le facteur limitant.
- Ce qui peut faire dérailler le projet est ailleurs : **(1)** une voix de synthèse en ligne (35 à 90 fois plus
  chère que le texte du modèle), **(2)** l'exactitude scientifique d'un contenu improvisé, **(3)** le public enfant
  et les données, **(4)** l'engagement perpétuel d'un service vendu en achat unique, **(5)** la latence.

**Recommandation : GO SOUS CONDITIONS** — IA incluse dans l'achat unique, optionnelle et désactivable, plafonnée par
un quota d'usage raisonnable, réservée aux 13 ans et plus, voix et reconnaissance vocale embarquées, le guide hors
ligne actuel restant le produit de base garanti. Détail en section 6.

---

## 1. Coût unitaire

### 1.1 Prix publics vérifiés (par million de jetons)

| Modèle | Entrée | Écriture cache 5 min | Écriture cache 1 h | Lecture cache | Sortie | Source |
|---|---|---|---|---|---|---|
| **Claude Haiku 5.5** (invites ≤ 100 000 jetons) | 0,10 | 0,125 | 0,20 | 0,01 | 0,50 | [V] 1 |
| Claude Haiku 4.5 (génération précédente) | 1,00 | 1,25 | 2,00 | 0,10 | 5,00 | [V] 1 |
| **Claude Sonnet 5.5** (intermédiaire) | 2,00 | 2,50 | 4,00 | 0,10 | 10,00 | [V] 1 |
| Claude Sonnet 5 | 2,00 | 2,50 | 4,00 | 0,20 | 10,00 | [V] 1 |
| Google Gemini 3.5 Flash-Lite | 0,30 | — | — | 0,03 (+ stockage 1,00 $/M jetons/h) | 2,50 | [V] 2 |
| Google Gemini 2.5 Flash-Lite | 0,10 | — | — | 0,01 (+ stockage) | 0,40 | [V] 2 |
| OpenAI GPT-5.4 mini | 0,75 | — | — | 0,075 | 4,50 | [V] 3 |
| OpenAI GPT-5.4 nano | 0,20 | — | — | 0,02 | 1,25 | [V] 3 |

Sources : (1) https://platform.claude.com/docs/en/about-claude/pricing — (2) https://aistudio.google.com/docs/pricing
(redirection depuis ai.google.dev/gemini-api/docs/pricing ; la page est longue, lecture partielle) —
(3) https://developers.openai.com/api/docs/pricing

Points techniques qui pèsent sur la facture [V source 1 et https://platform.claude.com/docs/en/build-with-claude/prompt-caching] :

- **Cache** : écriture à 1,25 × le prix d'entrée (5 min) ou 2 × (1 h) ; lecture à 0,1 × (0,05 × sur Sonnet 5.5).
  Le cache est rafraîchi gratuitement à chaque lecture. Longueur minimale : 512 jetons pour Haiku 5.5 et Sonnet 5.5.
  Les caches sont isolés par organisation et par espace de travail ; la documentation ne décrit aucun cloisonnement
  par utilisateur final : un préfixe strictement identique (fiches + consignes) devrait donc être **partagé entre
  tous les casques** [E — inférence à confirmer par une mesure de `cache_read_input_tokens`]. À l'échelle, le cache
  reste chaud en permanence et l'écriture devient négligeable.
- **Nouveau tokeniseur** : les modèles Claude 4.7 et suivants produisent environ 30 % de jetons en plus pour le même
  texte. Les « 15 000 à 25 000 jetons de fiches » doivent être **mesurés** avec le point d'accès de comptage, pas
  estimés.
- **Réflexion** : sur Haiku 5.5 la réflexion adaptative est active par défaut et **se facture comme de la sortie**.
  Sans réglage (réflexion désactivée ou effort bas), la sortie réelle peut doubler ou tripler [E]. À régler et à
  mesurer par le département IA.
- **Seuil des 100 000 jetons** de Haiku 5.5 (prix × 5 au-delà) : sans objet ici, mais interdit de laisser gonfler
  l'historique de conversation.
- Résidence des données aux États-Unis seulement : × 1,1. Traitement par lots à −50 % : inutilisable en temps réel,
  mais utile pour **pré-générer et relire** des visites (voir 4.2).

### 1.2 Hypothèses du modèle

| Paramètre | Valeur | Nature |
|---|---|---|
| Préfixe en cache (consignes + fiches des 148 objets) | 20 000 jetons (fourchette 15 000–25 000) | donnée du cahier des charges |
| Entrée non mise en cache par échange (question + court historique glissant) | 700 jetons | [E] |
| Réponse structurée | 150 / 250 / 400 jetons (bas / médian / haut) | cahier des charges |
| Visite improvisée | 600 jetons de sortie | cahier des charges |
| Écritures de cache par séance | 1 / 1 / 3 (pire cas : petit volume, pauses > 5 min) | [E] prudent |
| Échanges par séance | 5 / 15 / 40 (dont 0 / 1 / 3 visites improvisées) | [E] |
| Séances sur la vie de l'utilisateur | 2 / 5 / 15 ; cas extrême 50 séances hautes (2 000 échanges) | [E] voir 1.5 |

### 1.3 Coût d'un échange, d'une séance, d'une vie d'utilisateur (USD)

| Modèle | Échange bas / médian / haut | Visite improvisée | Écriture du préfixe | Séance basse / médiane / haute | Vie basse / médiane / haute | Extrême (2 000 éch.) |
|---|---|---|---|---|---|---|
| **Claude Haiku 5.5** | 0,00034 / 0,00040 / 0,00047 | 0,00057 | 0,0025 | 0,004 / 0,009 / 0,027 | **0,008 / 0,043 / 0,40** | 1,33 |
| Claude Haiku 4.5 | 0,0035 / 0,0040 / 0,0047 | 0,0057 | 0,025 | 0,042 / 0,086 / 0,27 | 0,085 / 0,43 / 3,99 | 13,30 |
| **Claude Sonnet 5.5** | 0,0049 / 0,0059 / 0,0074 | 0,0094 | 0,050 | 0,075 / 0,142 / 0,45 | **0,15 / 0,71 / 6,78** | 22,60 |
| Gemini 3.5 Flash-Lite | 0,0012 / 0,0014 / 0,0018 | 0,0023 | (0,006) | 0,012 / 0,028 / 0,092 | 0,024 / 0,14 / 1,38 | 4,60 |
| Gemini 2.5 Flash-Lite | 0,00033 / 0,00037 / 0,00043 | 0,00051 | (0,002) | 0,004 / 0,008 / 0,023 | 0,007 / 0,038 / 0,35 | 1,17 |
| GPT-5.4 mini | 0,0027 / 0,0032 / 0,0038 | 0,0047 | (0,015) | 0,029 / 0,064 / 0,20 | 0,057 / 0,32 / 3,01 | 10,04 |
| GPT-5.4 nano | 0,00073 / 0,00085 / 0,0010 | 0,0013 | (0,004) | 0,008 / 0,017 / 0,054 | 0,015 / 0,086 / 0,82 | 2,72 |

Calculs maison [E] à partir des prix [V]. Entre parenthèses : chez Google et OpenAI il n'y a pas de surcoût
d'écriture, le premier appel est payé au prix d'entrée normal (et Google facture en plus le stockage du cache
explicite). Détail du calcul pour Haiku 5.5, échange médian : 20 000 × 0,01 + 700 × 0,10 + 250 × 0,50 = 395 $ par
million d'échanges, soit 0,000395 $.

Sensibilité (Haiku 5.5, échange médian) : préfixe de 15 000 jetons → 0,00034 $ ; 25 000 jetons → 0,00044 $. Le
préfixe pèse la moitié du coût d'un échange même en cache : ne pas le laisser enfler. Si la réflexion triple la
sortie : ≈ 0,00065 $ l'échange, soit ≈ 0,07 $ sur la vie médiane — toujours négligeable.

**Lecture** : avec Haiku 5.5, le coût sur la vie d'un utilisateur médian est de l'ordre de **4 centimes**. Même un
retour aux prix de la génération précédente (× 10, Haiku 4.5) donnerait 0,43 $, soit 4 à 5 % du revenu net : le
projet reste viable si le fournisseur augmente ses prix ou retire le modèle. Sonnet 5.5 (15 fois plus cher) reste
finançable pour l'utilisateur médian (0,71 $) mais **pas sans quota** pour la queue de distribution (7 à 23 $).

### 1.4 La voix : le vrai poste de coût

Une réponse de 250 jetons représente environ 900 caractères en français, une visite de 600 jetons environ 2 200 [E].

| Synthèse vocale | Prix public | Coût par réponse (≈ 900 car.) | Vie médiane (75 éch. ≈ 70 000 car.) | Gros utilisateur (600 éch.) | Source |
|---|---|---|---|---|---|
| **Embarquée** (Piper via sherpa-onnx, déjà dans le projet) | 0 | 0 | 0 | 0 | LISEZ-MOI du projet |
| OpenAI `tts-1` | 15 $ / M caractères | 0,0135 | ≈ 1,05 | ≈ 8 | [V] 3 |
| OpenAI `tts-1-hd` | 30 $ / M caractères | 0,027 | ≈ 2,10 | ≈ 16 | [V] 3 |
| Google Cloud Chirp 3 HD | 30 $ / M caractères | 0,027 | ≈ 2,10 | ≈ 16 | [V] via résultats de recherche de https://cloud.google.com/text-to-speech/pricing (page non lisible directement) |
| ElevenLabs Flash / Turbo | 0,04 $ / 1 000 car. (40 $ / M) | 0,036 | ≈ 2,80 | ≈ 22 | [V] https://elevenlabs.io/pricing/api |
| ElevenLabs Multilingual v2 / v3 | 0,08 $ / 1 000 car. | 0,072 | ≈ 5,60 | ≈ 43 | [V] idem |
| Google Gemini 3.8 Flash-Lite TTS | 6 $ / M jetons audio jusqu'au 31.12.2026, 12 $ ensuite | ≈ 0,01 à 0,02 [E] | ≈ 1 [E] | ≈ 8 [E] | [V] 2 pour le prix ; conversion en minutes [M] |
| Azure Neural TTS | non lisible (page affichant « $- ») ; ≈ 15–16 $ / M car. [M] | ≈ 0,014 [M] | ≈ 1 [M] | ≈ 8 [M] | non vérifié |

**Une voix en ligne coûte 35 à 90 fois le texte du modèle** (0,0135 à 0,036 $ contre 0,0004 $ par échange). Avec une
voix en ligne « premium », l'utilisateur médian coûterait 1 à 3 $ et le gros utilisateur 8 à 22 $ : l'achat unique à
14,99 $ ne tient plus sans abonnement ni crédits. **La synthèse embarquée est donc une condition du modèle
économique**, et elle a un second mérite : la voix du guide est déjà une voix Piper (fr_FR-siwis-medium) ; la générer
dans le casque garde le même timbre entre clips enregistrés et réponses improvisées.

Reconnaissance vocale : le projet embarque déjà sherpa-onnx (modèle français en flux). À conserver : coût nul et,
surtout, **aucun son ne quitte le casque** (seul du texte part vers le relais). Pour mémoire, la transcription en
ligne coûterait 0,003 à 0,006 $ la minute chez OpenAI [V 3] et 0,20–0,22 $ l'heure chez ElevenLabs [V].

### 1.5 Rétention et nombre de séances : ce que disent les données

Aucune référence publique fiable n'existe pour les applications VR **éducatives**. Ce que nous avons trouvé :

- Meta ne publie pas de moyennes de plateforme ; ses tableaux de bord mesurent la rétention J1–7 et J1–30
  (https://developers.meta.com/horizon/resources/publish-user-engagement/).
- Meta indique que les joueurs qui passent plus de 30 minutes le premier jour reviennent trois fois plus que ceux
  qui jouent moins de 5 minutes (jeux d'action, données internes ;
  https://developers.meta.com/horizon/blog/build-faster-earn-more-developers-guide-to-engagement-and-retention-meta-quest/).
- Sources faibles, sans méthode : rétention AR/VR ≈ 25 % à J1, 15 % à J7, < 5 % à J30
  (https://patentpc.com/blog/user-retention-in-ar-vr-apps-how-long-do-they-stay) ; jeux gratuits pour enfants sur
  Quest : J1 40–48 %, J7 20–27 % (https://jorgetereso.github.io/eggscape/retention-mechanics.html).
- Indice côté tutorat IA : dans un essai 2026 cité par un comparatif, l'élève médian n'écrivait à Khanmigo qu'un jour
  d'exercice sur trois (https://www.kidsaitools.com/en/articles/khanmigo-review-2026) — l'usage réel d'un tuteur IA
  est plus faible qu'on ne le craint.

D'où nos hypothèses [E] : une expérience contemplative payante à contenu fini est typiquement parcourue en 2 à 6
séances ; médiane retenue 5 séances, queue haute 15, cas extrême 50. À remplacer par les données réelles de la bêta.

### 1.6 Coûts fixes (ordre de grandeur) [E]

Relais serveur sans état (fonction à la demande) : 5 à 25 $ par mois à faible volume. Surveillance et alertes de
dépense : inclus chez le fournisseur. Les vrais coûts fixes sont humains : jeu d'évaluation scientifique, politique
de confidentialité, relecture des journaux de bêta, maintenance lors des changements de modèle (une à deux fois par
an). À 1 000 ventes, ces coûts fixes dépassent largement la facture de jetons (≈ 43 $ au total).

---

## 2. Économie du produit

### 2.1 Revenu net par vente

- Commission : Meta retient « 30 % sauf accord contraire » et verse le solde chaque mois, en USD [V]
  (https://developers.meta.com/horizon/resources/publish-account-management-bank-tax/).
- Taxes : prix **hors taxe** aux États-Unis et au Canada (taxe ajoutée au prix affiché) ; prix **toutes taxes
  comprises** ailleurs. Meta collecte et reverse la TVA pour l'UE et, entre autres, la Suisse [V même page et
  https://developers.meta.com/horizon/faqs/financial-faq/].
- La documentation ne dit pas noir sur blanc si les 30 % s'appliquent au prix hors taxe ; nous le supposons [E].
- Taux de TVA : Suisse 8,1 %, France 20 %, UE entre 17 % et 27 % (moyenne ≈ 21 %) [M — non revérifiés ce jour].

| Prix affiché | États-Unis | Suisse (8,1 %) | France (20 %) | UE moyenne (21 %) | Hongrie (27 %) |
|---|---|---|---|---|---|
| 14,99 $ | 10,49 | 9,71 | 8,74 | 8,67 | 8,26 |
| 19,99 $ | 13,99 | 12,94 | 11,66 | 11,56 | 11,02 |

À retrancher encore [E] : promotions (une part importante des ventes du store se fait en solde, −20 à −30 %),
remboursements, parrainages. Revenu net moyen réaliste : **≈ 8 à 9 $** à 14,99 $ et **≈ 10,5 à 12 $** à 19,99 $.

### 2.2 Part du revenu net consommée par l'IA (texte seul, voix embarquée)

Base : revenu net UE moyen (8,67 $ / 11,56 $).

| Scénario de vie | Haiku 5.5 | à 14,99 | à 19,99 | Sonnet 5.5 | à 14,99 | à 19,99 |
|---|---|---|---|---|---|---|
| Bas (10 échanges) | 0,008 $ | 0,1 % | 0,1 % | 0,15 $ | 1,7 % | 1,3 % |
| Médian (75 échanges) | 0,043 $ | 0,5 % | 0,4 % | 0,71 $ | 8,2 % | 6,1 % |
| Haut (600 échanges) | 0,40 $ | 4,6 % | 3,5 % | 6,78 $ | 78 % | 59 % |
| Extrême (2 000 échanges) | 1,33 $ | 15 % | 12 % | 22,60 $ | **261 %** | **196 %** |

Avec une voix en ligne à 15 $ par million de caractères, ajouter 1,05 $ (médian) et 8 $ (haut) : 12 % et 97 % du
revenu net à 14,99 $.

### 2.3 Point de rupture

Coût marginal « tout compris » d'un échange (échange médian + une écriture de cache amortie sur 15 échanges) :
Haiku 5.5 : 0,00056 $ ; Sonnet 5.5 : 0,0092 $ ; Haiku 5.5 + voix en ligne `tts-1` : ≈ 0,014 $ ; + ElevenLabs Flash :
≈ 0,037 $.

| Configuration | Échanges avant perte (net 8,67 $ / 13,99 $) | Échanges pour 10 % du net |
|---|---|---|
| **Haiku 5.5, voix embarquée** | **≈ 15 400 / 24 900** | ≈ 1 540 / 2 490 |
| Haiku 4.5 (prix × 10) | ≈ 1 540 / 2 490 | ≈ 154 / 249 |
| Sonnet 5.5, voix embarquée | ≈ 940 / 1 515 | ≈ 94 / 151 |
| Haiku 5.5 + voix en ligne à 15 $/M car. | ≈ 620 / 1 000 | ≈ 62 / 100 |
| Haiku 5.5 + ElevenLabs Flash | ≈ 235 / 380 | ≈ 23 / 38 |

15 400 échanges, c'est 385 séances de 40 questions : un humain n'y arrive pas. Seul un **automate** (relais détourné
en modèle gratuit) peut l'atteindre — d'où le quota et l'authentification, qui sont des mesures de sécurité avant
d'être des mesures d'économie.

### 2.4 Queue de distribution et effet d'un quota

Simulation [E] sur 10 000 acheteurs, Haiku 5.5 : 60 % bas, 30 % médians, 9 % hauts, 1 % extrêmes →
48 + 129 + 360 + 133 = **≈ 670 $ au total**, soit **0,067 $ par acheteur** (0,8 % du revenu net). Les 10 % les plus
actifs produisent près des trois quarts de la facture, mais la facture reste petite.

Quota proposé : **40 échanges par jour, 400 par mois, 3 visites improvisées par jour**, par compte.
Effet : coût mensuel maximal par compte = 400 × 0,00056 ≈ **0,22 $** (Haiku 5.5). Un compte qui épuiserait son
quota tous les mois pendant trois ans coûterait ≈ 8 $ ; c'est le seul profil déficitaire, et il est rarissime.
Sans quota, un détournement automatisé (10 000 requêtes par jour) coûterait ≈ 5,60 $ par jour et par compte.
Avec Sonnet 5.5, le même quota plafonne à 3,70 $ par mois et par compte : trop pour un achat unique — Sonnet
exigerait un quota dix fois plus serré ou un paiement récurrent.

Un quota de 40 échanges par jour est invisible pour 99 % des utilisateurs (une séance haute en compte 40) : à
présenter comme un « usage raisonnable », pas comme un compteur anxiogène. À épuisement, le guide **retombe sur le
mode hors ligne** — jamais d'écran de paiement.

### 2.5 Le vrai sujet économique : l'engagement perpétuel

Un achat unique finance un service qui coûte indéfiniment. Le risque n'est pas le montant (voir ci-dessus) mais la
**promesse** : si le fournisseur retire le modèle, change ses conditions ou si le projet s'arrête, l'acheteur ne
doit rien perdre d'essentiel. D'où la règle : *le produit vendu est l'expérience hors ligne complète ; le guide en
ligne est un supplément inclus, annoncé comme nécessitant une connexion et garanti jusqu'à une date donnée*
(par exemple 24 mois après l'achat [E]), prolongé tant que c'est soutenable.

---

## 3. Modèles économiques possibles

### 3.1 Ce que permettent les règles du Meta Horizon Store

- **Paiement** : toute application distribuée sur le store qui propose des achats intégrés **doit** utiliser les
  « Platform In-App Purchases » ; les solutions de paiement tierces sont interdites sauf accord écrit [V]
  (https://developers.meta.com/horizon/policy/app-policies, mise à jour du 10 mars 2026, règle 1.1.1).
- **Exception institutionnelle** : la vente **hors plateforme** de licences prépayées (achats ou abonnements) est
  autorisée **uniquement en gros à des clients professionnels**, « tels que des entreprises ou des établissements
  d'enseignement » [V même page, règle 1.1.2.1]. C'est la porte d'entrée pour musées, écoles et médiathèques.
- **Modèles reconnus** : payant à l'achat, gratuit, modules complémentaires (contenus et achats intégrés, y compris
  consommables), abonnements, lots [V] (https://developers.meta.com/horizon/resources/monetization/).
- **Abonnements** : durées de 1, 3, 6 ou 12 mois ; essais gratuits et prix de lancement ; « application payante +
  abonnement optionnel pour du contenu premium » explicitement admis ; **incompatibles avec le partage
  d'application** (seul le compte acheteur y a accès) [V] (https://developers.meta.com/horizon/resources/subscriptions/).
- Commission sur achats intégrés et abonnements : aucune page ne donne un taux distinct ; nous retenons 30 % [E].
- Changement de prix : délai de 30 jours entre deux modifications [V, résultat de recherche sur la page tarification].
- Les crédits Meta ne seraient plus en vente depuis le 9 juin 2026 et ne servent pas aux abonnements
  (https://www.meta.com/help/quest/1543535462925767/) [lu en résultat de recherche seulement].
- La page de règles ne contient **aucune clause** sur l'IA générative ou les agents conversationnels ; les règles de
  contenu sont dans un document séparé que nous n'avons pas lu.

### 3.2 Comparaison des modèles

| Modèle | Avantages | Risques | Précédents | Verdict |
|---|---|---|---|---|
| **IA incluse, quota d'usage raisonnable** | Simple, lisible, pas de friction en VR ; coût ≈ 0,5 % du net ; argument de vente | Engagement perpétuel ; nécessite relais, authentification, plafond | Ebers Anatomy sur Quest (questions médicales en temps réel, note 2,4/5 sur 9 avis — l'IA seule ne fait pas la qualité) : https://www.meta.com/experiences/ebers-anatomy/5572994846061763/ | **Retenu** |
| Crédits en achat intégré / extension payante | Aligne coût et revenu ; utile si modèle haut de gamme | 30 % de commission ; compteur anxiogène ; inadapté aux enfants ; interdit pour une application « enfants » (pas de SDK plateforme) ; à 0,04 centime l'échange, il n'y a rien à faire payer | Convai : 29 $/mois pour 3 000 interactions ; Mistscale : 1 crédit le texte, 5 la voix (https://app.cinevva.com/guides/ai-npcs-dialogue, https://mistscale.com/pricing) | Écarté au lancement ; option future « mode expert » (Sonnet) |
| Abonnement | Revenu récurrent ; couvre une voix premium | Friction forte pour un contenu fini ; rupture du partage familial ; mauvaise image (« payer pour poser des questions ») ; avis négatifs sur la visibilité des abonnements | Ovation (« abonnement requis pour les fonctions avancées »), AI Roommate Plus, Soulmate, Xiora sur Quest ; Khanmigo 4 $/mois ou 44 $/an (https://khanmigo.ai/pricing) ; Duolingo Max ≈ 30 $/mois selon des sources tierces | Écarté pour le grand public |
| **Licence institutionnelle annuelle** | Autorisé hors plateforme ; prix élevé par appareil ; budget prévisible pour l'acheteur ; mode kiosque déjà à la feuille de route | Cycle de vente long ; exigences (hors ligne, accord de traitement des données, support) | 3D Organon : licences de 12 mois par appareil, lots de sièges pour universités, « AI Study Assistant » intégré, prix sur devis (https://3dorganon.com/licensing-features) ; MadXR : personnage IA en option à +8 000 $ par module (https://www.madxr.io/ai-powered-npcs-vr-training) ; Khanmigo districts ≈ 10 $ par élève et par an (source tierce) | **Retenu**, IA en option désactivable |
| « Apportez votre clé » | Coût nul pour nous | Saisie d'une clé en VR, public minuscule, support, impossible pour les enfants ; statut vis-à-vis des règles Meta non vérifié | Courant dans les outils pour développeurs, pas dans le grand public VR | Écarté ; éventuellement pour une institution qui veut son propre contrat |

---

## 4. Risques hors coût

Gravité et probabilité sur 3 niveaux (faible / moyenne / forte).

### 4.1 Public enfant et données personnelles — gravité forte, probabilité moyenne

Faits :

- Meta distingue trois catégories d'âge : enfants (10–12 ans), âges mélangés, adolescents et adultes (13+). Dans
  tous les cas : pas de publicité et **blocage des moins de 10 ans**. Une application « enfants » ne peut utiliser
  **aucune** fonction du SDK plateforme (donc ni achats intégrés ni vérification de possession). Une application
  « âges mélangés » doit intégrer l'API « Get Age Category » sous 30 jours. À partir du 1er janvier 2027, l'API
  renverra une catégorie détaillée (CHILD, EARLY_TEEN, LATE_TEEN, ADULT, UNKNOWN) [V]
  (https://developers.meta.com/horizon/resources/age-groups/, mise à jour du 28 octobre 2026).
- Le développeur reste responsable des données collectées « y compris par les API et SDK tiers » [V même page].
- Anthropic : un mineur est toute personne de moins de 18 ans ; les produits qui laissent des mineurs dialoguer avec
  le modèle doivent prévoir vérification d'âge, modération et filtrage, surveillance et signalement, pédagogie,
  conformité affichée (COPPA cité), et **obligation** d'indiquer que l'on parle à une IA ; audits périodiques
  possibles, suspension en cas de manquement [V]
  (https://support.claude.com/en/articles/9307344-responsible-use-of-anthropic-s-models-guidelines-for-organizations-serving-minors).
- COPPA (États-Unis) : règle modifiée pleinement applicable depuis le 22 avril 2026 ; empreintes vocales ajoutées
  aux données personnelles, programme écrit de sécurité, consentement parental distinct pour certaines
  divulgations à des tiers [V via https://www.federalregister.gov/documents/2025/04/22/2025-05904/childrens-online-privacy-protection-rule
  et commentaires de cabinets].
- RGPD article 8 : âge du consentement numérique entre 13 et 16 ans selon l'État (France 15 ans, Allemagne 16 ans)
  [M] ; droit suisse : pas d'âge fixe, capacité de discernement [M]. Non revérifié.
- Meta Voice SDK : toute collecte de voix exige un consentement spécifique [V résultat de recherche] — sans objet
  si l'on garde la reconnaissance embarquée.

Parades : (a) reconnaissance vocale **dans le casque**, seul le texte part ; (b) déclarer l'application « âges
mélangés », lire la catégorie d'âge et **ne proposer le guide en ligne qu'aux 13 ans et plus** (CHILD et UNKNOWN →
guide hors ligne, qui reste complet) ; (c) activation explicite avec écran d'information, désactivée par défaut ;
(d) relais sans journal de contenu en production, identifiant pseudonyme, aucune donnée de compte transmise au
fournisseur ; (e) consigne « sécurité enfants » dans l'invite et filtrage côté relais ; (f) politique de
confidentialité, accord de traitement des données et clauses de transfert hors Europe ; durée de conservation chez
le fournisseur à vérifier contractuellement ; (g) faire valider par un juriste avant la bêta publique.

### 4.2 Exactitude scientifique d'un contenu improvisé — gravité forte, probabilité forte sans garde-fous

Le produit se vend sur sa rigueur (chaque texte passe par `science/`). Une seule erreur virale (« le guide m'a dit
que… ») coûte plus cher que toute la facture de jetons.

Parades : (a) le modèle **n'invente pas de faits** : il répond à partir des fiches fournies et cite l'identifiant de
la fiche ; hors fiches → « je ne sais pas, voici ce que je peux te montrer » ; (b) une « visite improvisée » est une
**sélection et un ordre** d'objets validés avec des transitions courtes, pas un exposé libre ; (c) animations et
filtres = commandes structurées prises dans une liste fermée, **validées par le casque** avant exécution ; (d)
signalétique visible : « réponse générée par IA à partir des fiches validées » ; (e) jeu d'évaluation de 200 à 300
questions (dont pièges, hors sujet, questions médicales personnelles) relu par le référent scientifique, rejoué à
chaque changement de modèle ou d'invite ; (f) refus des conseils médicaux individuels ; (g) option : pré-générer par
lots (−50 %) quelques dizaines de visites « spontanées », les faire relire, et ne laisser le modèle que choisir.

### 4.3 Dépendance au fournisseur et à la connexion — gravité moyenne, probabilité forte

Les modèles sont retirés régulièrement, les prix bougent (dans les deux sens : Haiku 4.5 → 5.5 = ÷ 10), une panne
arrive. Les musées et les écoles ont souvent un Wi-Fi filtré ou absent.

Parades : (a) le hors ligne reste le produit de base ; bascule automatique et silencieuse au moindre échec ;
(b) le relais porte la clé, le choix du modèle et les invites → changement de fournisseur sans mise à jour de
l'application ; (c) format de sortie neutre, testé sur un second fournisseur (Gemini Flash-Lite a un coût
comparable) ; (d) interrupteur général et plafond de dépense mensuel côté serveur ; (e) mention claire sur la fiche
du store.

### 4.4 Latence perçue en VR — gravité moyenne, probabilité moyenne

Repères (sources d'industrie, base scientifique mince) : < 300–500 ms paraît immédiat, 500 ms–1 s acceptable pour un
agent qui « réfléchit », > 1 s rompt le fil ; au-delà de ≈ 1,5 s la dégradation devient forte
(https://perspectives.nvidia.com/nemotron-speech/task/faq/what-end-to-end-latency-should-i-target-for-a-conversational-voice-agent-to-feel/,
https://arxiv.org/pdf/2601.19922). Chaîne à mesurer : fin de parole → transcription embarquée → réseau → premier
jeton → première phrase synthétisée dans le casque. Nous n'avons **aucune mesure** du temps de premier jeton de
Haiku 5.5 ni de la vitesse de Piper sur le Quest 3.

Parades : réponse en flux, synthèse phrase par phrase ; signe immédiat que le guide a entendu (les particules
« écoutent », son bref) ; commandes simples traitées **localement** par le moteur de compréhension existant, sans
aller au serveur ; délai maximal de 4 s puis réponse hors ligne. En VR contemplative, une seconde de silence habité
est mieux tolérée qu'au téléphone [E].

### 4.5 Modération et détournement — gravité moyenne, probabilité moyenne

Propos déplacés d'utilisateurs, tentatives de faire dire n'importe quoi au guide, captures d'écran embarrassantes,
utilisation du relais comme modèle gratuit.

Parades : périmètre strict (« je suis le guide du corps galaxie ») ; filtrage d'entrée et de sortie au relais ;
réponses courtes (plafond de jetons) ; authentification par preuve de possession de l'application (jeton vérifié
côté serveur), limite de débit et quota par compte ; jamais de clé dans l'APK ; campagne d'essais adverses (300
invites, dont profils « enfant ») avant la bêta. Les refus du modèle doivent être gérés (pas de repli automatique
côté serveur sur Haiku 5.5, d'après la documentation du fournisseur).

### 4.6 Obligation d'information « IA » (cadre européen) — gravité moyenne, probabilité forte (c'est une obligation)

- Règlement européen sur l'IA, article 50 : les obligations de transparence s'appliquent depuis le **2 août 2026**.
  L'article 50(1) (informer la personne qu'elle interagit avec une IA, sauf évidence) n'a pas été reporté par
  l'« omnibus numérique ». Seul le marquage lisible par machine des contenus générés (article 50(2)) a reçu un délai
  jusqu'au **2 décembre 2026** pour les systèmes déjà sur le marché. Amendes jusqu'à 15 M€ ou 3 % du chiffre
  d'affaires mondial. Sources : https://www.ropesgray.com/en/insights/viewpoints/2026/08/102nfqm/you-talkin-to-me-operationalising-the-eu-ai-acts-transparency-obligations,
  https://www.morganlewis.com/ru/blogs/sourcingatmorganlewis/2026/08/eu-ai-acts-transparency-rules-what-went-into-effect-on-2-august,
  https://datamatters.sidley.com/2026/06/24/eu-ai-act-transparency-obligations-preparing-for-compliance-by-2-august-2026/.
  Une source (Goodwin) évoque un report à décembre 2027 ; elle est isolée et contradictoire avec les autres — à
  trancher sur le texte du règlement.
- Le règlement s'applique dès que le produit est proposé dans l'UE, même depuis la Suisse [E, lecture usuelle].
- Qualification exacte (fournisseur ou déployeur, portée du marquage pour une voix de synthèse générée dans le
  casque) : à faire confirmer par un juriste.

Parade : annonce à l'activation et rappel permanent discret (« guide IA »), mention sur la fiche du store et dans la
politique de confidentialité ; distinguer visuellement contenu validé et contenu généré ; suivre les lignes
directrices de la Commission sur le marquage. Cette obligation recoupe celle du fournisseur du modèle (4.1) et sert
aussi la rigueur (4.2) : coût quasi nul, bénéfice triple.

### 4.7 Synthèse

| Risque | Gravité | Probabilité | Parade principale |
|---|---|---|---|
| Exactitude scientifique | Forte | Forte sans garde-fous | Réponses ancrées dans les fiches, visites = sélection d'objets validés, jeu d'évaluation |
| Enfants et données | Forte | Moyenne | Reconnaissance embarquée, IA réservée aux 13+, activation explicite, pas de journal de contenu |
| Dépendance et connexion | Moyenne | Forte | Hors ligne garanti, relais interchangeable, interrupteur général |
| Voix en ligne (coût) | Forte | Certaine si retenue | Synthèse embarquée |
| Latence | Moyenne | Moyenne | Flux, accusé de réception immédiat, commandes locales |
| Modération / détournement | Moyenne | Moyenne | Périmètre strict, authentification, quota |
| Information « IA » | Moyenne | Certaine (obligation) | Mention à l'activation et en continu |

---

## 5. Valeur perçue et positionnement

### 5.1 Ce que font les concurrents

- **Human Anatomy VR** (Quest) : 12,99 $, pas d'IA annoncée ; lot « Anatomy XR » à 49,99 $ ; « Anatomy Learning
  Labs: Complete Set » à 119,99 $ ; un autre « Human Anatomy » à 5,99 $ avec narration [lu sur les fiches du store
  en résultats de recherche].
- **Ebers Anatomy** (Quest) : questions médicales en temps réel par IA ; note de 2,4 sur 9 avis — signe qu'une IA
  greffée sur un contenu médiocre ne vend pas.
- **3D Organon** : « AI Study Assistant » intégré, vendu en licences annuelles par appareil à plus de 600
  institutions, prix sur devis (https://3dorganon.com/licensing-features).
- **Meta AI** sur Quest : assistant du système, en anglais, États-Unis et Canada seulement
  (https://www.meta.com/help/quest/172903867975450/) : pas de concurrence en français pour l'instant.
- Applications « compagnon IA » sur Quest (Soulmate, Xiora, AI Roommate, Ovation) : toutes en abonnement — l'IA y
  est le produit, pas un supplément.
- Aucune expérience « musée » ou contemplative en VR avec guide conversationnel n'est ressortie de nos recherches :
  **le créneau « œuvre artistico-scientifique à qui l'on peut parler » semble libre** [constat de recherche, non
  exhaustif].

### 5.2 Ce qui se vend à chaque public

| Public | Ce qui fait acheter | Effet du guide en ligne |
|---|---|---|
| Enfants (acheteur = parent) | Émerveillement, sécurité, « sans écran douteux », hors ligne | Neutre à négatif s'il est mal encadré ; **le hors ligne et l'absence de données sont l'argument**. Le guide en ligne doit être coupé pour eux. |
| Curieux d'art et de sciences | Beauté, voyage du corps aux quarks, sentiment de comprendre | **Fort** : poser sa propre question, demander « montre-moi le lien entre le cœur et les étoiles », recevoir une visite sur mesure. C'est le public cible de la fonction. |
| Scientifiques | Rigueur, sources, exactitude des ordres de grandeur | Positif **seulement** si les réponses sont sourcées et si l'IA sait dire « je ne sais pas » ; sinon destructeur. |
| Institutions | Fiabilité, mode kiosque, hors ligne, durée de séance maîtrisée, prix prévisible, conformité | Faible en exposition (bruit, file d'attente, Wi-Fi) ; intéressant en médiation accompagnée et en classe, à condition d'être désactivable et couvert par un accord de données. |

### 5.3 Le guide justifie-t-il 19,99 $ ?

- Le guide conversationnel ne « vaut » pas 5 $ de coût (il en coûte 0,04), mais il change la nature du produit : de
  « visite narrée » à « œuvre avec laquelle on converse ». C'est un argument de bande-annonce et de presse.
- Les comparables grand public restent entre 5,99 et 14,99 $ ; 19,99 $ est le haut de la catégorie et correspond à
  la cible du commanditaire (17–22 CHF, selon le taux de change [M]).
- **Notre avis** : 19,99 $ est défendable **si** la bêta confirme l'usage et la satisfaction (indicateurs 5 et 6
  ci-dessous), avec une remise de lancement de 20–25 % (≈ 14,99–15,99 $ les premières semaines). Sinon, rester à
  14,99 $ et présenter le guide en ligne comme un bonus « bêta ».
- **Pas au-delà de 19,99 $** en achat unique : au-dessus, les acheteurs comparent avec des jeux complets. La valeur
  supérieure se capte auprès des institutions (licence annuelle), pas du grand public.

---

## 6. Recommandation

### 6.1 Décision : GO SOUS CONDITIONS

Conditions non négociables :

1. **Voix et reconnaissance vocale embarquées** (aucun son ne sort du casque, coût nul).
2. **Le hors ligne reste le produit complet** ; bascule automatique ; interrupteur général côté serveur.
3. **Réponses ancrées dans les fiches validées**, commandes dans une liste fermée, signalétique « IA ».
4. **13 ans et plus**, activation explicite, pas de journal de contenu en production, avis juridique avant la bêta
   publique.
5. **Quota et authentification** au relais ; plafond de dépense mensuel et alerte.
6. **Jeu d'évaluation scientifique** rejoué à chaque changement.

### 6.2 Modèle économique, prix, quota

- **Grand public** : achat unique, guide en ligne **inclus** (libellé « Guide en direct — bêta »), sans abonnement
  ni crédits. Garantie affichée du service en ligne : 24 mois après l'achat, reconductible.
- **Prix** : 19,99 $ si les seuils de la bêta sont atteints (remise de lancement −20 à −25 %) ; sinon 14,99 $.
- **Modèle** : Claude Haiku 5.5 (0,10 / 0,50 $), réflexion réduite, préfixe en cache. Sonnet 5.5 seulement si
  l'évaluation montre un écart de qualité net sur les visites improvisées, et alors limité à ces visites.
- **Quota** : 40 échanges par jour, 400 par mois, 3 visites improvisées par jour ; au-delà, guide hors ligne.
  Coût maximal par compte : ≈ 0,22 $ par mois.
- **Institutions** : licence annuelle par appareil vendue hors plateforme (autorisé pour les ventes en gros aux
  professionnels), mode kiosque, IA en option désactivable. Fourchette de travail : 150 à 300 CHF par appareil et
  par an [E, à tester auprès de trois ou quatre institutions ; les concurrents ne publient pas leurs prix].
- **Écartés** : abonnement grand public, crédits, « apportez votre clé », voix de synthèse en ligne.

### 6.3 Indicateurs de la phase de test et seuils de décision

| # | Indicateur | Seuil « go » | Seuil « stop / revoir » |
|---|---|---|---|
| 1 | Coût IA par utilisateur actif et par mois (moyenne, p95, p99) et projection sur la vie | moyenne projetée ≤ 3 % du revenu net (≈ 0,30 $) ; p95 ≤ 0,15 $/mois | > 10 % du revenu net |
| 2 | Taux d'erreur factuelle (jeu d'évaluation + échantillon relu de la bêta) | ≤ 1 % d'erreurs majeures, 0 réponse dangereuse | > 3 % ou une réponse dangereuse non bloquée |
| 3 | Latence fin de parole → premier son | médiane ≤ 1,5 s ; p95 ≤ 3 s ; échecs et délais dépassés < 2 % | médiane > 2,5 s |
| 4 | Validité des commandes (filtres, animations, visites) | ≥ 97 % exécutables ; ≥ 90 % jugées pertinentes | < 90 % exécutables |
| 5 | Adoption : part des testeurs qui posent des questions libres sur au moins 2 séances ; durée de séance par rapport au hors ligne | ≥ 40 % ; durée + 20 % | < 20 % (la fonction ne crée pas de valeur) |
| 6 | Satisfaction et prix : note du guide ; part jugeant 19,99 $ justifié | ≥ 70 % de notes ≥ 4/5 ; ≥ 50 % | < 50 % de notes ≥ 4/5 |
| 7 | Sécurité : essais adverses (300 invites, profils enfant inclus) | 0 réponse inappropriée ; refus corrects ≥ 99 % | toute réponse inappropriée non corrigeable |
| 8 | Taux de lecture en cache du préfixe et part des jetons de réflexion dans la sortie | ≥ 90 % ; réflexion ≤ 30 % de la sortie | < 70 % (invalidation silencieuse à corriger) |

### 6.4 Plan en trois étapes

1. **Test interne (2 à 4 semaines, 5 à 10 personnes)** — mesurer le nombre réel de jetons des fiches, la latence de
   bout en bout sur le casque, la synthèse embarquée en direct ; construire le jeu d'évaluation ; plafond de dépense
   de 20 $. Décision sur les indicateurs 2, 3, 4, 8.
2. **Bêta fermée (4 à 6 semaines, 50 à 150 testeurs adultes, canal de diffusion privé du store)** — consentement
   explicite à la relecture des échanges pendant la bêta ; essais adverses ; entretiens avec deux ou trois
   institutions ; avis juridique (RGPD, COPPA, article 50, conditions du fournisseur). Décision sur les indicateurs
   1, 5, 6, 7 et sur le prix.
3. **Lancement** — guide en ligne en option « bêta », 13+, quota actif, interrupteur général, alerte budgétaire,
   revue mensuelle des coûts et des erreurs signalées ; offre institutionnelle en parallèle ; réévaluation à 3 mois
   (prix, modèle, extension éventuelle aux langues prévues).

---

## 7. Ce que nous n'avons pas pu vérifier

- Nombre réel de jetons des fiches avec le tokeniseur actuel ; part de la réflexion dans la sortie de Haiku 5.5.
- Partage effectif du cache entre utilisateurs finaux (inféré de la documentation, non mesuré).
- Temps de premier jeton de Haiku 5.5 et vitesse de la synthèse Piper en direct sur Quest 3.
- Rétention et nombre de séances des applications VR éducatives : aucune donnée publique fiable.
- Assiette exacte de la commission Meta (hors taxe supposé), taux appliqué aux achats intégrés et abonnements,
  taux de remboursement et part des ventes en promotion.
- Taux de TVA (Suisse, UE), âges du consentement numérique par pays, droit suisse des mineurs : de mémoire.
- Prix Azure Speech (page illisible) et grille complète Google Cloud Text-to-Speech (seul Chirp 3 HD confirmé) ;
  équivalence jetons audio → minutes pour les voix Gemini.
- Prix officiels de Duolingo Max (sources tierces) et prix institutionnels de 3D Organon (sur devis).
- Arrêt de la vente des crédits Meta (lu en résultat de recherche, page non ouverte).
- Règles de contenu du store sur l'IA générative (document séparé non lu) ; statut d'un mode « apportez votre clé ».
- Durée de conservation des requêtes chez le fournisseur du modèle et disponibilité d'une rétention nulle.
- Portée exacte de l'article 50 pour notre cas (fournisseur ou déployeur, marquage d'une voix générée localement) ;
  une source isolée évoque un report à 2027.
- Cours USD/CHF du jour.

## 8. Sources

Prix des modèles et du cache
- https://platform.claude.com/docs/en/about-claude/pricing
- https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- https://aistudio.google.com/docs/pricing
- https://developers.openai.com/api/docs/pricing

Voix
- https://elevenlabs.io/pricing/api
- https://cloud.google.com/text-to-speech/pricing
- https://azure.microsoft.com/en-us/pricing/details/cognitive-services/speech-services/ (prix non affichés)
- https://www.meta.com/help/quest/463323051789865/ et https://developers.meta.com/horizon/documentation/unity/voice-sdk-overview/

Meta Horizon Store
- https://developers.meta.com/horizon/resources/publish-account-management-bank-tax/
- https://developers.meta.com/horizon/faqs/financial-faq/
- https://developers.meta.com/horizon/policy/app-policies
- https://developers.meta.com/horizon/resources/monetization/
- https://developers.meta.com/horizon/resources/subscriptions/
- https://developers.meta.com/horizon/resources/age-groups/
- https://developers.meta.com/horizon/resources/publish-user-engagement/
- https://developers.meta.com/horizon/blog/build-faster-earn-more-developers-guide-to-engagement-and-retention-meta-quest/
- https://www.meta.com/help/quest/1543535462925767/
- https://www.meta.com/help/quest/172903867975450/

Enfants, données, cadre légal
- https://support.claude.com/en/articles/9307344-responsible-use-of-anthropic-s-models-guidelines-for-organizations-serving-minors
- https://www.anthropic.com/aup
- https://www.federalregister.gov/documents/2025/04/22/2025-05904/childrens-online-privacy-protection-rule
- https://www.hunton.com/privacy-and-cybersecurity-law-blog/coppa-rule-amendment-compliance-deadline-approaches
- https://www.ropesgray.com/en/insights/viewpoints/2026/08/102nfqm/you-talkin-to-me-operationalising-the-eu-ai-acts-transparency-obligations
- https://www.morganlewis.com/ru/blogs/sourcingatmorganlewis/2026/08/eu-ai-acts-transparency-rules-what-went-into-effect-on-2-august
- https://datamatters.sidley.com/2026/06/24/eu-ai-act-transparency-obligations-preparing-for-compliance-by-2-august-2026/
- https://www.goodwinlaw.com/en/insights/publications/2026/08/alerts-technology-dpc-eu-ai-act-transparency-obligations-now-in-force (source divergente)
- https://cms.law/en/esp/legal-updates/eu-ai-act-developments-key-political-agreement-on-the-digital-omnibus-on-ai-implementation-timeline-and-transparency-consultation

Concurrents et précédents
- https://www.meta.com/experiences/human-anatomy-vr-learning/6527658207255000/
- https://www.meta.com/experiences/ebers-anatomy/5572994846061763/
- https://www.meta.com/en-gb/experiences/anatomy-xr-bundle/2352048235252501/
- https://3dorganon.com/licensing-features
- https://www.meta.com/experiences/ovation/4510688418969375/
- https://www.meta.com/experiences/soulmate-ai-companion/9027195737340524/
- https://xiora.com/
- https://khanmigo.ai/pricing et https://www.kidsaitools.com/en/articles/khanmigo-review-2026
- https://lingoly.io/duoling-max-cost/ (Duolingo Max, source tierce)
- https://app.cinevva.com/guides/ai-npcs-dialogue ; https://mistscale.com/pricing ; https://www.madxr.io/ai-powered-npcs-vr-training

Rétention et latence
- https://patentpc.com/blog/user-retention-in-ar-vr-apps-how-long-do-they-stay (faible)
- https://jorgetereso.github.io/eggscape/retention-mechanics.html (faible)
- https://perspectives.nvidia.com/nemotron-speech/task/faq/what-end-to-end-latency-should-i-target-for-a-conversational-voice-agent-to-feel/
- https://arxiv.org/pdf/2601.19922
