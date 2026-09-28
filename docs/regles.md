# Règles du jeu et paramètres d'équilibrage

État des règles au 28/09/2026.

**Où sont les paramètres d'équilibrage.** Tous sont regroupés dans deux ressources, réglables dans
l'inspecteur de Godot :
- **`GameRules`** (`scripts/model/game_rules.gd`, fichier `data/game_rules.tres`) : carte, capacité des
  terrains, croissance, économie, food, famine, combat, colons, trajets, Boost, et vitesse des boutons
  maintenus ;
- **`AIProfile`** (`scripts/model/ai_profile.gd`, un fichier par niveau dans `data/ai/`) : tout le
  comportement des IA, dont leur handicap de croissance (voir §9).

Les valeurs de référence sont les valeurs par défaut des scripts. Godot n'enregistre dans un `.tres` que
ce qui en diffère : une valeur modifiée dans l'inspecteur s'y inscrit et prend le dessus. Le code des
règles (`World`, `AIController`) ne contient pas d'autre nombre qui pèse sur l'équilibre.

**Mesurer un réglage** : l'outil `tools/balance_sim.gd` joue des parties entre IA et en fait un rapport
(voir §12).

Les valeurs marquées *(calculé)* ne se règlent pas directement : elles découlent des autres.

---

## 1. Temps

| Variable | Valeur | Rôle |
|---|---|---|
| `cycle_duration` | **1 s** | Durée d'un cycle : croissance, or, science et batailles avancent une fois par cycle. |
| `starvation_interval` | **0,1 s** | Pas de l'horloge rapide : famine et surpeuplement. |

Ordre d'un cycle :
1. les batailles font leurs pertes ;
2. pour chaque joueur, la science est produite ;
3. l'or est encaissé, avec des reconversions s'il manque ;
4. la population grandit.

La famine et le surpeuplement tournent sur leur propre horloge, toutes les 0,1 s.

---

## 2. Carte et départ

| Variable | Valeur | Où | Rôle |
|---|---|---|---|
| `columns` × `rows` | **10 × 10** par défaut, de 2 à 20 par côté | fenêtre « Nouvelle partie » | Taille de la carte. |
| `mountain_count` | **5** | `GameRules` | Montagnes pour 100 cases, proportionnel à la taille de la carte. |
| `water_count` | **5** | `GameRules` | Cases d'eau pour 100 cases, proportionnel à la taille de la carte. |
| `map_reference_cells` | **100** | `GameRules` | Taille de carte (en cases) pour laquelle `mountain_count` et `water_count` sont réglés. |
| `capacity[PRAIRIE]` | **1024** | `GameRules` | Règle d'or : population maximale d'une case. |
| `capacity[MOUNTAIN]` | **256** | `GameRules` | Idem. |
| `capacity[WATER]` | **0** | `GameRules` | Inhabitable. |
| `starting_population` | **2 workers**, 0 scientist, 0 garnison | `GameRules` | Population posée sur la case de départ. |
| Joueurs | **2 à 4** | fenêtre « Nouvelle partie » | Le joueur 1 est l'humain, les autres des IA pacifistes, normales ou agressives (normale par défaut). |

**Règle d'or.** La population totale d'une case ne dépasse jamais sa capacité. Ce total compte tous
les rôles, les colons en attente et l'armée. Il y a une seule exception, les batailles (voir §8).

**Départ.** Le joueur humain choisit sa case de départ (jamais sur l'eau). Chaque IA tire ensuite la
sienne au hasard parmi les cases libres hors de l'eau. La génération de la carte garde toujours au
moins une case hors de l'eau par joueur.

**Brouillard de guerre.** L'eau est toujours connue. Un joueur voit ses cases et leurs voisines, et se
souvient du terrain déjà découvert. Une case ennemie en vue porte un voile à la couleur de son
propriétaire et affiche sa population totale, sans le détail. La composition n'est révélée qu'aux
joueurs engagés dans une bataille sur la case.

**Agglomérations et population sur la carte.** Chaque case occupée et en vue, celles du joueur comme
les cases ennemies, montre son agglomération, dessinée sur la tuile, et sa population totale en
dessous. Le type d'agglomération dépend du remplissage (population totale ÷ capacité) :

| Remplissage | Agglomération (antiquité) | Prairie (1024) | Montagne (256) |
|---|---|---|---|
| moins d'un tiers | **village** : trois huttes au toit de chaume | < 341 | < 85 |
| d'un tiers aux deux tiers | **ville** : temple grec entouré de maisons | 341 à 682 | 85 à 170 |
| au-delà | **mégapole** : cité ceinte d'un rempart, avec grand temple, tour de guet et maisons serrées | ≥ 683 | ≥ 171 |

- **Intégration au décor.** Les agglomérations sont en pixel art vu de trois quarts, au format des
  tuiles (42×48), donc à la même échelle de pixels que le terrain. La lumière vient d'en haut à gauche
  et les ombres sont portées sur le sol. Les couleurs sont naturelles (pierre, torchis, chaume,
  terre cuite), sans contour noir.
- **Couleur du joueur.** Seuls les toits et les bannières prennent la couleur du propriétaire, posée
  à 80 % (`ROOF_TINT`) pour garder leur matière.
- **Époques.** Le style suit l'époque, pour l'instant l'antiquité. Chaque époque, qui avancera avec la
  science, aura ses trois agglomérations (`CellBackground.SETTLEMENTS`, générées par
  `tools/generate_settlements.gd`).
- **Autres affichages.** Dans le zoom d'une case, l'agglomération n'est pas dessinée, pour que les
  rôles restent lisibles. Les lignes d'information (zoom d'une case ennemie, belligérants) gardent
  une petite icône de l'agglomération (`Icons.SETTLEMENTS`).
- Une case en guerre affiche ses belligérants à la place de sa population (§8).

**Couleur des cases.** Chaque case occupée et en vue porte un voile uni à la couleur de son
propriétaire, quelle que soit sa composition. Son opacité suit le remplissage de la case :

    opacité = 0,8 × population totale ÷ capacité de la case

Une case pleine est donc bien colorée, une case qui vient d'être fondée à peine teintée. Une montagne
de 128 habitants (capacité 256) est aussi colorée qu'une prairie de 512. La règle vaut pour les cases
ennemies, dont la population totale est de toute façon affichée. Le maximum 0,8 est `MAX_ALPHA`, dans
`scripts/view/cell_background.gd`.

**Effets sur la carte** (`scripts/view/map_effects.gd`, pictos générés par `tools/generate_icons.gd`) :
- **Victoire.** Quand le joueur conquiert une case par la guerre, un trophée doré surgit de la case
  avec un petit rebond, monte et s'efface en fondu, avec le titre « VICTOIRE ! ». Des rayons dorés
  tournent derrière lui, et des feux d'artifice multicolores éclatent autour.
- **Défaite.** Quand une case du joueur tombe par la guerre, une épée brisée surgit en vacillant, avec
  le titre « DÉFAITE », sur une pluie de braises et une fumée sombre.
- **Terre conquise.** Quand ses colons fondent une nouvelle case, un drapeau planté surgit avec le
  titre « TERRE CONQUISE », une onde à la couleur du joueur et des étincelles vertes et dorées.
- **Flash de conquête.** Toute case en vue qui change de main par la guerre s'illumine d'un éclair
  blanc, avec une onde à la couleur de son nouveau propriétaire (rouge si elle devient libre).
- **Onde sur la frontière.** Quand le territoire du joueur s'agrandit, par colonisation ou conquête,
  un front lumineux blanc part de la nouvelle case et parcourt toute sa frontière comme un cercle qui
  grandit, en s'estompant. Les réglages sont `WAVE_SPEED` (7 rayons de case par seconde),
  `WAVE_WIDTH` et `WAVE_STEPS`, dans `scripts/view/hex_map.gd`.
- **Boost.** Chaque clic réussi fait s'envoler un « +1 » de la case et du bouton Boost.
- **Découverte.** Une case qui vient d'être découverte sort du brouillard en fondu, en 0,8 s
  (`REVEAL_TIME`), avec un léger éclat.

Ces effets sont purement visuels. Ils suivent le signal `World.owner_changed`, émis quand une case
change de propriétaire.

**Sons** (`scripts/view/sound_fx.gd`, sons CC0 de Kenney et OpenGameArt, crédits dans
`assets/sounds/CREDITS.md`). Chaque bruitage mêle plusieurs sons, avec des instants, volumes et
hauteurs un peu tirés au hasard, pour ne jamais sonner pareil :
- **Bataille** : quand le joueur clique sur une case en guerre en vue, une lame est tirée puis quatre
  chocs de fer résonnent en 1,2 s environ.
- **Chariot** : quand ses colons partent, un grincement puis les cahots des roues pendant le trajet.
- **Victoire** : quand il gagne une case par la guerre, une clameur de foule de 2,6 s, prise à un endroit
  différent de l'enregistrement à chaque fois.
- **Défaite** : quand il perd une case par la guerre, un choc sourd, puis la même foule plus grave et
  plus lente, comme consternée.
- **Clic** : un petit clic sur tous les boutons. Ce sont les boutons du menu, des fenêtres et du jeu,
  accrochés automatiquement, ainsi que les boutons dessinés du zoom : « + », « − », Settler, Army et
  raccourcis.
- **Boost** : un petit tir laser à chaque clic réussi, un peu plus aigu ou grave à chaque fois.

**Musique de fond** (`scripts/view/background_music.gd`, musiques CC0, crédits dans
`assets/music/CREDITS.md`). C'est une musique discrète, de style antique, dans le menu et en jeu. Deux
morceaux s'enchaînent en boucle, en commençant par l'un des deux au hasard :
- *Greek instruments* de Spring Spring (1 min 41), joué avec des instruments grecs ;
- *Ancient Mysteries* de Sperry Lion (2 min).

Chaque morceau démarre par un fondu de 3 s. Le volume est bas (−20 dB, `VOLUME_DB`) pour rester sous
les bruitages.

**Frontières.** Le territoire de chaque joueur en vue est entouré d'une frontière à sa couleur, au
néon : un trait avec un cœur plus clair et un léger halo lumineux qui pulse. Il n'y a pas de frontière
entre deux cases d'un même joueur. Du côté d'une case que le joueur ne voit pas, la frontière est
toujours tracée, pour ne rien révéler. Deux territoires voisins montrent leurs deux frontières côte à
côte. Les réglages `FRONTIER_WIDTH`, `NEON_GLOW_LAYERS` et `NEON_PULSE_RATE` sont dans
`scripts/view/hex_map.gd`.

**Joueurs IA.** Une IA joue avec les mêmes commandes et les mêmes règles qu'un humain : elle colonise,
défend, attaque et clique sur Boost selon son niveau (voir §9). Sa croissance est ralentie par le
`growth_factor` de son profil (voir §3).

---

## 3. Population et croissance

| Variable | Valeur | Rôle |
|---|---|---|
| `time_to_half["worker"]` | **300 s** (5 min) | Temps pour passer de 1 worker à la moitié d'une prairie (512). |
| `time_to_half["scientist"]` | **1200 s** (20 min) | Idem pour les scientists. |
| `time_to_half["fighter"]` | **0** | Les fighters (garnison et armée) ne se reproduisent jamais. |
| `FULL_POPULATION` | **1024** | Constante de référence de ces durées. |
| `growth_factor` (profil d'IA) | **0,8** pour les trois niveaux | Handicap : multiplie l'accroissement par cycle de l'IA. Réglable par niveau. |

**Courbe en S (logistique, depuis le 28/09).** La croissance est lente au début, quand il y a peu
d'individus, puis elle accélère. Elle ralentit ensuite à l'approche de la capacité de la case, qu'elle
n'atteint qu'en un temps infini. À chaque cycle, l'accroissement de chaque rôle est freiné par la place
déjà prise :

    taux = (1024 − 1) ^ (cycle_duration / time_to_half)      taux dans une case vide
    taux IA = 1 + (taux − 1) × growth_factor
    frein = 1 − population totale de la case ÷ capacité      1 case vide, 0 case pleine
    effectif ← effectif × (1 + (taux − 1) × frein)

Le frein compte toute la population de la case, colons et armée compris. Une montagne (256) freine
donc quatre fois plus tôt qu'une prairie. La croissance est continue (effectifs flottants), mais un
rôle ne grandit que s'il compte au moins **un individu entier**.

Valeurs *(calculé, vérifié en simulation)* : un worker seul sur une prairie, sans Boost.

| Population | Depuis 1 worker | Depuis 2 workers (départ) |
|---|---|---|
| 100 | 3 min 24 | 2 min 54 |
| 256 (25 %) | 4 min 13 | 3 min 43 |
| 512 (50 %) | 5 min 00 | 4 min 30 |
| 768 (75 %) | 5 min 47 | 5 min 17 |
| 922 (90 %) | 6 min 34 | 6 min 03 |
| 1014 (99 %) | 8 min 16 | 7 min 46 |
| 1023 | 9 min 54 | 9 min 24 |

Pour une IA (`growth_factor` 0,8), tous ces temps sont allongés d'environ 25 %.

**Boost.**

| Variable | Valeur | Rôle |
|---|---|---|
| `boost_workers` | **1** | Workers ajoutés à chaque clic sur Boost, sur une case du joueur en paix, dans la limite de la place libre. |

Cliquer frénétiquement fait partie du jeu. L'IA utilise Boost aussi, à un rythme humain qui dépend de
son niveau (voir §9).

**Changements de rôle.** Les boutons « + » et « − » du zoom échangent un individu entre les workers
et les scientists, ou entre les workers et la garnison. Les boutons Settler et Army font de même avec
les colons et l'armée (clic gauche pour remplir, clic droit pour vider). Maintenir un bouton accélère :
un individu de plus au bout de **0,4 s** (`hold_delay`), puis 0,4/2 s, 0,4/3 s, etc., jusqu'à **500 par
seconde** (`max_hold_rate`), deux réglages de `GameRules` : c'est la vitesse à laquelle un humain peut
mobiliser sa population. *(Calculé)* :
on atteint 10 par seconde en ≈ 0,8 s et 500 par seconde en ≈ 2,4 s. Aucune commande n'est possible sur une case en guerre.

---

## 4. Nourriture (food)

| Variable | Valeur | Rôle |
|---|---|---|
| `food_per_worker` | **3** | Food produite par worker et par cycle. |
| `food_per_individual` | **1** | Food mangée par worker, scientist ou fighter de garnison, par cycle. |
| `starvation_grace` | **1 s** | Délai de grâce avant la première mort. |
| `starvation_interval` | **0,1 s** | Délai entre deux morts tant que la famine dure. |

Formules :

    solde de la case = 3 × workers − 1 × (workers + scientists + garnison)
                     = 2 × workers − scientists − garnison

- **Un worker nourrit 2 non-workers** (scientists ou fighters de garnison).
- Les colons en attente, l'armée et les fighters engagés dans une bataille **ne mangent pas**.
- **Partage.** Le surplus d'une case est partagé à parts égales entre ses voisines du même joueur.
  Le partage ne se fait qu'entre voisines directes, pas au-delà.
- **Famine.** Une case dont la food disponible (son solde plus ce qu'elle reçoit) est négative
  bénéficie de 1 s de grâce. Ensuite, elle perd **un individu toutes les 0,1 s** (10 par seconde) :
  un scientist d'abord, puis un fighter de garnison, puis un worker, jusqu'à retrouver l'équilibre.
- Une case assiégée est figée : pas de famine.

---

## 5. Or

| Variable | Valeur | Rôle |
|---|---|---|
| `gold_per_role["worker"]` | **+2** | Or rapporté par worker et par cycle. |
| `gold_per_role["scientist"]` | **−1** | Or coûté par scientist et par cycle. |
| `gold_per_role["fighter"]` | **−1** | Or coûté par fighter de garnison et par cycle. |
| `conversions_per_cycle` | **1** | Reconversions par cycle quand l'or est épuisé. |

Formule :

    revenu du joueur = Σ (2 × workers − scientists − garnison) sur toutes ses cases

- **Un worker paie 2 non-workers.** C'est le même ratio que pour la food : une case de W workers
  entretient au plus 2W scientists et fighters de garnison, en or comme en food.
- Les colons, l'armée et les fighters engagés dans une bataille **ne coûtent rien**.
- **Faillite.** L'or ne descend jamais sous 0. S'il le devrait, **1 scientist ou fighter de
  garnison par cycle** redevient worker. La conversion se fait dans la case qui en compte le plus,
  en prenant le rôle le plus nombreux des deux. Les cases en guerre et l'armée ne sont pas
  reconverties.
- L'or n'a pas d'autre usage pour l'instant.

---

## 6. Science

| Variable | Valeur | Rôle |
|---|---|---|
| `science_per_scientist` | **0,1** | Points de science par scientist et par cycle. |

    science par cycle = 0,1 × scientists (hors cases en guerre)

La science s'accumule mais n'a **pas encore d'effet**. Il est prévu qu'elle accélère la croissance,
relève la capacité des cases et modifie les batailles, via un système de technologies.

---

## 7. Colons, garnison et armée

Les fighters d'une case forment deux groupes :
- la **garnison** (« garrison » dans le zoom) : les fighters qui restent dans la case. Elle ne se
  déplace pas, et elle défend mieux (voir §8) ;
- l'**armée** (bouton **Army**) : les fighters prêts à partir vers une case voisine.

| Variable | Valeur | Rôle |
|---|---|---|
| `max_settlers` | **32** | Colons en attente au maximum sur une case. |
| `max_army` | **1024** | Taille maximale de l'armée d'une case. |

**Colons.** Des workers mis de côté. Ils partent vers une case voisine en prairie ou en montagne,
libre ou au joueur, qui n'est pas en guerre, dans la limite de sa place libre ; le reste attend.

| Variable | Valeur | Rôle |
|---|---|---|
| `travel_time` | **1 s** | Durée du trajet des colons, et des armées (voir plus bas), jusqu'à la case voisine. |

- **Trajet.** Les colons quittent aussitôt leur case et voyagent pendant `travel_time`. Ils
  ne deviennent workers de la case d'arrivée, et ne la prennent si elle était libre, qu'à
  l'arrivée. Le trajet avance au pas de l'horloge rapide (0,1 s).
- **Place réservée.** Pendant le trajet, ils réservent leur place dans la case d'arrivée : elle compte
  dans la règle d'or, et personne d'autre ne peut la prendre.
- **Arrivée impossible.** Si la case d'arrivée a été prise par un autre joueur ou est entrée en guerre
  pendant le trajet, les colons rentrent dans leur case de départ comme colons. Ils sont limités par
  la place libre de la case et par `max_settlers`. Ceux qui ne peuvent pas rentrer, par exemple
  parce que la case de départ est assiégée, sont perdus.
- Les colons en route comptent dans la population du joueur (élimination, §10).
- **Animation.** Sur la carte, un petit chariot apparaît en fondu sur la case de départ, glisse vers
  la case d'arrivée en 1 s, roues tournantes, et disparaît en fondu. Il est visible si l'une des deux
  cases est en vue. Les réglages sont `CONVOY_SIZE`, `CONVOY_FADE` et `CONVOY_FPS`, dans
  `scripts/view/hex_map.gd`, et les images sont générées par `tools/generate_icons.gd`.

**Garnison.** Les boutons « + » et « − » échangent des workers contre des fighters de garnison.

**Raccourcis armée ↔ garnison** (un clic, dans une case en paix) :
- le bouton **tour**, à droite d'Army, fait passer **toute l'armée** de la case en garnison ;
- le bouton **épée**, à droite des « − » et « + » de la garnison, fait passer **toute la garnison**
  dans l'armée, dans la limite de `max_army`.

Ces raccourcis ne font que déplacer des fighters déjà formés, au sein de la case. Enrôler des workers
dans l'armée ou en garnison reste progressif, en maintenant le bouton.

**Armée.** Le bouton **Army** prend d'abord les fighters de la garnison, puis enrôle des workers qui
deviennent fighters. Le clic droit renvoie un fighter de l'armée en worker. L'armée part vers une
case voisine :
- **une case à soi en paix** : elle y **reste une armée**, prête à repartir aussitôt, ce qui rend les
  déplacements fluides. Deux limites s'appliquent : la place libre de la case (règle d'or : c'est là
  qu'on prépare les armées) et `max_army` pour l'armée de la case. Le reste attend dans la case de
  départ ;
- **une case à soi assiégée** : renforts de la garnison, **sans limite**. La case est figée, donc son
  armée ne pourrait pas repartir, et en garnison les fighters défendent mieux (force 3 au lieu de 2) ;
- **une case ennemie, ou toute case en guerre** (même entre deux autres joueurs) : elle rejoint la
  bataille, **sans limite**.

**Trajet de l'armée.** Comme les colons, l'armée quitte aussitôt sa case et n'arrive qu'au bout de
`travel_time` (1 s). Une attaque ne commence donc qu'à l'arrivée.
- **Place réservée** seulement vers une case à soi en paix : la place et la limite `max_army` y sont
  réservées pendant le trajet.
- **À l'arrivée**, on regarde ce qu'est devenue la case :
  - à soi en paix : l'armée y reste une armée ;
  - à soi assiégée : elle renforce la garnison ;
  - ennemie ou en guerre : elle livre bataille ;
  - devenue libre et en paix, ou sans place : elle rentre dans sa case de départ comme armée, dans la
    limite de sa place et de `max_army`. Ce qui ne peut pas rentrer est perdu.
- Les fighters en route comptent dans la population du joueur (élimination, §10).
- **Animation.** Un petit soldat qui marche, tourné vers sa destination, fait le même trajet en fondu
  que le chariot des colons.
- **IA.** Elle tient compte de ses troupes et colons en route : elle ne renvoie pas de renforts déjà
  en chemin, ne relance pas une attaque déjà en route, et ne colonise pas deux fois la même case.

Les colons et l'armée en attente comptent dans la capacité de la case. Si la case est attaquée, son
armée la défend aussi, une fois la garnison tombée. Les colons, eux, ne la défendent pas.

---

## 8. Batailles

| Variable | Valeur | Rôle |
|---|---|---|
| `army_per_garrison` | **2** | Fighters que perd l'attaquant pour tuer 1 fighter de garnison. |
| `workers_per_fighter` | **10** | Workers tués par un échange quand le défenseur n'a plus de fighter. |
| `scientists_per_fighter` | **20** | Scientists tués par un échange quand il n'a plus ni fighter ni worker. |
| `garrison_strength` | **3** | Force d'un fighter de garnison dans le rapport des forces. |
| `army_strength` | **2** | Force d'un fighter d'armée (armée du défenseur ou fighters d'un attaquant). |
| `worker_strength` | **0,25** | Force d'un worker : quatre civils valent un soldat, ils pèsent peu face à une armée. |
| `mountain_defense` | **×2** | Multiplie la force d'un défenseur en montagne. |
| `force_ratio_exponent` | **1,5** | Exposant du rapport des forces : plus il est grand, plus une nette supériorité écrase vite l'adversaire (1 = rapport simple). |

**Mêlée générale.** Les camps sont le défenseur (le propriétaire, avec toute sa population) et
chaque attaquant (avec son armée engagée). À chaque cycle, chaque camp fait **un échange avec chacun
des autres camps**, et les pertes sont simultanées. Les pertes habituelles d'un échange avec le
défenseur sont, dans cet ordre de priorité :

| Le défenseur perd | L'attaquant perd |
|---|---|
| 1 fighter de sa **garnison** | **2** fighters (`army_per_garrison`) |
| sinon 1 fighter de son **armée** | 1 fighter |
| sinon **10 workers** | 1 fighter |
| sinon **20 scientists** | 1 fighter |

Entre deux attaquants, les pertes habituelles sont de 1 fighter chacun par échange.

**Rapport des forces.** Au début de chaque cycle, on calcule la force de chaque camp :

    force du défenseur = (3 × garnison + 2 × armée + 0,25 × workers) × 2 s'il est en montagne
    force d'un attaquant = 2 × ses fighters engagés

Les scientists et les colons ne comptent pas. Une force inférieure à 1 compte pour 1. Dans chaque
échange :
- le camp **le plus faible** subit ses pertes habituelles **× (force adverse ÷ sa force) ^ 1,5**
  (`force_ratio_exponent`). Au-dessus de 1, l'exposant fait écraser plus vite l'adversaire en cas de
  nette supériorité, sans changer grand-chose aux combats serrés. Par exemple, un rapport de 1,2 donne
  ×1,3, un rapport de 2 donne ×2,8, et un rapport de 10 donne ×32 ;
- le camp **le plus fort** subit ses pertes habituelles, sans changement.

Quand le multiplicateur dépasse ce qui reste d'une catégorie, le reste des pertes passe à la
suivante : garnison, puis armée, puis workers, puis scientists. Les pertes fractionnaires
s'accumulent d'un cycle à l'autre : un fighter tombe chaque fois que ses pertes cumulées atteignent 1.

La garnison est ainsi favorisée deux fois : elle compte triple dans le rapport des forces, et chaque
fighter de garnison tué coûte 2 fighters à l'attaquant. Attaquer demande donc une nette supériorité.
La science devra plus tard rendre les attaques plus efficaces.

Déroulement :
- **Une case assiégée est figée.** Elle n'a ni croissance, ni science, ni or, ni food, ni famine, ni
  reconversion, et n'accepte aucune commande. Seuls la bataille et les renforts la modifient.
- Un camp sans combattant quitte la bataille.
- **Défenseur tombé.** Quand il n'a plus ni garnison, ni armée, ni worker, ni scientist, ses colons
  en attente sont perdus avec la case. S'il reste plusieurs attaquants, la case n'appartient plus à
  personne et ils continuent de se battre entre eux. L'ancien propriétaire peut revenir, mais comme
  attaquant.
- **Fin de la bataille.** Quand il ne reste qu'un camp, le défenseur garde sa case, ou le dernier
  attaquant la prend : ses survivants y forment la garnison. Si tous les camps tombent, la case
  redevient libre.

**Affichage d'une case en guerre** (`scripts/view/battle_view.gd`), pour la repérer d'un coup d'œil :
- sur la carte, un contour rouge qui pulse, de petites explosions en fond, et deux épées qui
  s'entrechoquent sur un halo lumineux qui pulse ;
- en dessous, les **belligérants**, chacun à la couleur de son joueur. Sur une première ligne, le
  défenseur : sa garnison (tour), son armée (épée) et ses civils, workers et scientists (buste). Sur une seconde ligne, chaque attaquant et ses
  fighters engagés (épée) ;
- le brouillard de guerre s'applique : un joueur qui n'est pas engagé dans la bataille ne voit que la
  population totale du défenseur ;
- dans le zoom, la même information tient sur une ligne : défenseur, épées animées, attaquants.

**Surpeuplement.** Après une bataille, une case peut dépasser sa capacité. Elle bénéficie alors de
**1 s de grâce** (`starvation_grace`), puis perd **un fighter de garnison toutes les 0,1 s**
(`starvation_interval`), ou à défaut un fighter de son armée, jusqu'à revenir à sa capacité. Les
workers et les scientists sont épargnés. Ces morts s'ajoutent à celles de la famine et de la faillite.

**Exemples *(vérifiés en simulation, un seul attaquant, prairie)*.** Avec l'exposant 1,5, comparé à
l'exposant 1 (la règle d'avant le 28/09) :

| Combat | Forces | Exposant 1 | Exposant 1,5 |
|---|---|---|---|
| 1000 fighters contre 100 en garnison | 2000 contre 300 | l'attaquant gagne en 9 s | **en 4 s** |
| 500 fighters contre 50 en garnison | 1000 contre 150 | en 5 s | **en 2 s** |
| 300 fighters contre 100 en garnison | 600 contre 300 | en 29 s | **en 17 s** |
| 100 fighters contre 50 en garnison | 200 contre 150 | en 26 s | **en 19 s** |
| 100 fighters contre 100 en garnison | 200 contre 300 | la garnison tient (20 s) | **la garnison tient** (14 s) |

**Civils** (règle du 28/09 : un worker pèse 0,25 dans la force, et chaque unité de pertes tue 10 workers
ou 20 scientists). Une armée écrasante massacre vite des civils, même mal défendus par une petite
garnison. Une case sans vraie garnison tombe vite :

| Combat | Avant | Maintenant |
|---|---|---|
| 2000 fighters contre 10 en garnison + 900 workers | 11 s | **2 s** |
| 500 fighters contre 300 workers | 6 s | **1 s** |
| 100 fighters contre 300 workers | — | **4 s** |
| 100 contre 50 en garnison + 400 workers | — | la défense tient (19 s) |

Plus petite armée qui vainc une garnison de T fighters, sans renforts : environ **1,68 × T** en
prairie et **2,56 × T** en montagne. Par exemple 168 fighters contre 100 en prairie, 256 en montagne.
Une case pleine (1024) demande plus que la taille maximale d'une armée (`max_army` = 1024) partie d'une
seule case.

---

## 9. Intelligence artificielle

Le niveau de chaque IA se choisit dans la fenêtre « Nouvelle partie ». Chaque niveau est un fichier
`AIProfile` (`scripts/model/ai_profile.gd`) modifiable dans l'inspecteur : `data/ai/pacifist.tres`,
`data/ai/normal.tres` et `data/ai/aggressive.tres`.

- **Pacifiste** : isolationniste. Elle s'étend un peu, privilégie la science et la défense, et
  n'attaque jamais.
- **Normale** : expansion standard, équilibre entre science, défense et attaque.
- **Agressive** : clics frénétiques, expansionniste, attaque dès qu'elle a l'avantage.

**Équité.** L'IA ne voit que ce que verrait un humain à sa place (brouillard de guerre, §2) : ses
cases, leurs voisines, et seulement la population totale des cases ennemies. Elle agit uniquement par
les commandes d'un joueur humain, avec les mêmes limites.

| Variable | Pacifiste | Normale | Agressive | Rôle |
|---|---|---|---|---|
| `growth_factor` | **0,8** | **0,8** | **0,8** | Handicap de croissance (voir §3). |
| `boost_clicks_per_second` | **2** | **2,5** | **4** | Clics par seconde pendant une rafale sur Boost. |
| `boost_burst_seconds` | **2 s** | **4 s** | **3 s** | Durée moyenne d'une rafale. |
| `boost_pause_seconds` | **8 s** | **8,5 s** | **5 s** | Durée moyenne d'une pause entre deux rafales. |
| Boost moyen *(calculé)* | ≈ **0,4 clic/s** | ≈ **0,8 clic/s** | ≈ **1,5 clic/s** | |
| `settle_fill_ratio` | **30 %** | **20 %** | **15 %** | Remplissage d'une case à partir duquel elle envoie des colons. |
| `settlers_per_wave` | **32** | **16** | **12** | Colons envoyés à chaque vague. |
| `science_ratio` | **40 %** | **15 %** | **5 %** | Part de la population de chaque case en scientists. |
| `garrison_ratio` | **75 %** | **40 %** | **25 %** | Garnison d'une case frontalière, en part de la plus grosse population ennemie voisine. |
| `attack_margin` | **0** (jamais) | **×2** | **×1,3** | Marge au-dessus de la plus petite armée qui vaincrait le pire cas. |
| `attack_delay` | — | **60 s** | **20 s** | Temps de réaction : durée minimale pendant laquelle une case ennemie doit être en vue avant d'être attaquée. |
| `army_commit` | **80 %** | **60 %** | **80 %** | Part des workers d'une case que l'IA accepte d'enrôler pour attaquer ou secourir. |
| `action_delay` | **5 s** | **4 s** | **3 s** | Temps minimal entre deux actions sur la carte (attaque, renforts ou vague de colons) : le temps qu'il faut à un humain pour choisir une case, former ses troupes ou ses colons et cliquer sur la cible. |
| `budget_share` | **90 %** | **90 %** | **90 %** | Part du budget d'une case (ce que ses workers nourrissent et paient) consacrée aux scientists et à la garnison. |
| `keep_workers` | **2** | **2** | **2** | Workers qu'une case garde toujours pour continuer à grandir. |

Parts de hasard, identiques pour les trois niveaux : ±30 % sur le délai entre deux actions
(`action_delay_jitter`) et sur le nombre de clics (`boost_click_jitter`), ±50 % sur les durées de
rafale et de pause (`boost_phase_jitter`).

**Ce que fait l'IA à chaque cycle**, après le tick, par ordre de priorité. Une case engagée dans une
étape (secours, attaque) est laissée tranquille par les suivantes jusqu'au cycle d'après.

1. **Secours.** Pour chacune de ses cases assiégées, elle vise une garnison dont la force égale à
   elle seule celle des attaquants, plus 1 fighter : 2 × attaquants ÷ (3 × bonus de montagne) + 1.
   Ce sont alors les attaquants qui subissent le rapport des forces. La voisine en paix qui peut
   fournir le plus d'armée l'y envoie pour combler l'écart.
2. **Attaque.** Elle ne vise qu'une case ennemie voisine, pas déjà en guerre, en vue depuis au moins
   `attack_delay` secondes. Si la case change de propriétaire, le compteur repart de zéro. Cela laisse
   au joueur qui vient de s'installer le temps d'y monter une garnison. Pour chaque cible, elle estime
   le pire cas : toute la population en garnison, montagne comprise. Elle simule l'assaut selon les
   règles du §8 pour trouver la plus petite armée qui l'emporterait.

       coût = plus petite armée gagnante × attack_margin

   Elle choisit la cible la moins chère qu'elle peut atteindre. Elle part de la case voisine qui peut
   réunir la plus grosse armée (armée prête, garnison, puis `army_commit` de ses workers), si cette
   armée atteint le coût.

   **Une action sur la carte à la fois.** Secours, attaque et colonisation sont des actions sur la
   carte. L'IA n'en mène qu'une, un seul envoi d'armée ou de colons, puis attend `action_delay` (± son
   aléa) avant la suivante. Quand elle peut agir, l'ordre de priorité est : secours, puis attaque, puis
   colonisation. Comme un humain, elle ne peut ni envoyer des renforts de plusieurs cases à la fois,
   ni coloniser plusieurs cases en même temps.
3. **Scientists et garnison.** Dans chaque case en paix, elle ajuste ses scientists puis sa garnison
   aux cibles du profil, en convertissant des workers dans un sens ou dans l'autre. Les deux restent
   dans un budget qui garde l'or et la food positifs, avec 10 % de marge (`budget_share`) :

       scientists + garnison ≤ 1,8 × workers   (soit au plus ≈ 64 % de la population de la case)

   La science est servie d'abord, la garnison prend le reste du budget.
4. **Colonisation**, s'il est temps d'agir (voir plus haut). Parmi ses cases en paix remplies
   au-delà de `settle_fill_ratio`, la plus remplie envoie une vague de colons vers sa meilleure case
   libre voisine. Elle préfère la prairie à la montagne, et une case qui touche le plus de terres
   libres. Une seule vague à la fois.
5. **Boost.** Pendant une rafale, chaque clic va à sa case en paix la moins remplie.

Une case garde toujours au moins **2 workers** (`keep_workers`) pour continuer à grandir.

---

## 10. Fin de partie

La partie se termine quand le joueur humain est éliminé, ou quand il ne reste qu'un seul joueur en
lice. Un joueur est éliminé quand il n'a plus personne, nulle part : cases, colons (en route compris), armées en attente
et fighters engagés dans des batailles compris. Une fenêtre affiche alors l'évolution de la population, de la science et de la food de chaque
joueur.

---

## 11. Points d'attention pour l'équilibrage

Ce sont des constats sur les règles actuelles, pas des bugs.

- **Garnison ou armée.** L'armée en attente et les fighters engagés en bataille ne coûtent ni or ni
  food ; seule la garnison coûte. En échange, la garnison défend deux fois mieux. Le choix entre
  garnison (chère, solide) et armée (gratuite, mobile, fragile) dépend donc de `army_per_garrison`
  et du coût en or et en food des fighters.
- **Ratio 2:1 identique pour l'or et la food.** Une case équilibrée en food l'est aussi en or. Pour
  créer de vrais choix, il suffirait de modifier l'un des deux.
- **Démarrage exponentiel.** Avec 2 workers, les premières minutes sont lentes, et Boost y pèse
  énormément : à 2 workers, un clic (+50 %) vaut environ 17 s de croissance naturelle. C'est
  pourquoi le rythme de clics est l'un des principaux réglages de difficulté des IA.
- **Batailles longues entre forces égales.** Quand les forces sont proches, le rapport des forces
  change peu de chose : on reste à environ un échange par seconde, et une bataille de plusieurs
  centaines de fighters, dont la défense est renforcée à chaque cycle, dure encore plusieurs minutes.
- **Course aux terres.** En simulation (4 IA, carte 10 × 10, 20 min), l'IA agressive prend le plus
  de cases. La pacifiste reste souvent petite, parfois bloquée à 1 case si ses voisines sont prises
  avant qu'elle soit prête à s'étendre, mais elle produit le plus de science par habitant. Premier
  réglage (28/09) jugé trop fort en partie réelle : l'IA normale s'étendait très vite et attaquait
  aussitôt une case voisine fondée. D'où la baisse d'un cran du Boost et de l'expansion, et l'ajout
  du temps de réaction.
- **Case pleine inattaquable.** Pour l'IA, vaincre une case pleine (1024) demande au pire cas environ
  1,68 × 1024 ≈ 1720 fighters, plus qu'une seule case ne peut réunir. Pour l'instant, l'IA n'attaque
  qu'à partir d'une seule case source et n'attaque donc jamais une case pleine.
- **Batailles plus décisives (28/09).** Avec le rapport des forces, une nette supériorité écrase vite
  l'adversaire. En simulation (4 IA, 20 min), on compte 50 à 160 attaques par partie, et une IA
  normale a pu être éliminée.
- **Or sans usage.** L'or s'accumule, surtout chez les IA qui gardent leur budget positif. Il n'a pas
  encore d'usage.
- **Conquête coûteuse à entretenir.** Des fighters conquérants sans workers ne produisent ni food ni
  or. Ils meurent vite, par famine, faillite et surpeuplement, si on ne les convertit pas en workers.

---

## 12. Outil de simulation d'équilibrage

`tools/balance_sim.gd` joue des parties entre IA, sans affichage et en accéléré. Le déroulement
reproduit celui du jeu. L'outil écrit ensuite un rapport en Markdown :
- chaque partie, avec son vainqueur, sa durée, ses batailles et ses conquêtes ;
- par niveau d'IA, les victoires, les éliminations, la survie moyenne, la population finale, le nombre
  de cases et la science.

On peut y changer n'importe quel réglage numérique de `GameRules` ou d'un profil d'IA le temps de la
simulation, sans toucher aux fichiers, pour mesurer son effet.

    godot --headless --path . -s res://tools/balance_sim.gd -- [options]

| Option | Par défaut | Rôle |
|---|---|---|
| `games=` | 10 | Nombre de parties. |
| `players=` | `pacifist,normal,aggressive,normal` | Niveau de chaque IA (2 à 4). |
| `size=` | `10x10` | Taille de la carte. |
| `minutes=` | 30 | Durée maximale d'une partie. |
| `seed=` | 1 | Graine de la première partie (les suivantes : +1, +2…). Même graine, même partie. |
| `rules.<réglage>=` | — | Change un réglage de `GameRules`, par exemple `rules.army_per_garrison=3`. |
| `<niveau>.<réglage>=` | — | Change un réglage d'un profil, par exemple `aggressive.attack_margin=1.5`. |
| `report=` | — | Écrit aussi le rapport dans ce fichier. |

Une partie de 30 minutes à 4 IA prend de 30 s à 1 min de calcul.
