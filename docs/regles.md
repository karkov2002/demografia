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
| Type de carte | **Continents** par défaut | fenêtre « Nouvelle partie » | Îles, Continents, Lacs ou Méditerranée (voir « Types de carte »). |
| `columns` × `rows` | **10 × 10** par défaut, jusqu'à 20 par côté | fenêtre « Nouvelle partie » | Taille de la carte ; le minimum dépend du type de carte et du nombre de joueurs. |
| `mountain_count` | **6** | `GameRules` | Montagnes pour 100 cases de terre, multiplié au hasard par 0,8 à 1,8 (`mountain_spread`). |
| `forest_count`, `hill_count`, `marsh_count` | **14**, **9**, **6** | `GameRules` | Forêts, collines et marais pour 100 cases de terre, posés en petits massifs. |
| `water_count` | **15** | `GameRules` | Carte « Lacs » : cases d'eau pour 100 cases, en grandes étendues. |
| `islands_land_ratio`, `continents_land_ratio` | **45 %**, **50 %** | `GameRules` | Part de terre des cartes « Îles » et « Continents ». |
| `mediterranean_sea_ratio` | **35 %** | `GameRules` | Part de la carte « Méditerranée » occupée par la mer centrale. |
| `map_reference_cells` | **100** | `GameRules` | Taille de carte (en cases) pour laquelle les nombres ci-dessus sont réglés. |
| `capacity` | voir « Terrains » | `GameRules` | Règle d'or : population maximale d'une case selon son terrain. |
| `village_capacity` | **256** | `GameRules` | Population maximale d'un village (voir « Villages et villes »). |
| `city_growth_factor` | **0,5** | `GameRules` | Multiplie l'accroissement par cycle d'une ville : elle grandit plus lentement qu'un village. |
| `megapolis_threshold` | **2/3** | `GameRules` | Remplissage (habitants ÷ capacité du terrain) à partir duquel une ville est une mégapole. |
| `megapolis_defense` | **×1,5** | `GameRules` | Remparts : multiplie la force de la garnison d'une mégapole. |
| `starting_population` | **2 workers**, 0 scientist, 0 garnison | `GameRules` | Population posée sur la case de départ. |
| Joueurs | **2 à 4** | fenêtre « Nouvelle partie » | Le joueur 1 est l'humain, les autres des IA pacifistes, normales ou agressives (normale par défaut). |

**Règle d'or.** Les habitants d'une case ne dépassent jamais sa capacité. Ils comprennent tous les
rôles et les colons en attente, mais **pas l'armée** (depuis le 03/10) : elle a sa propre place, en plus,
jusqu'à `max_army` (1024), dans un village comme dans une ville. Il y a une seule exception, les
batailles (voir §8). La
capacité d'un **village** est plafonnée à 256 (`village_capacity`) ; celle d'une **ville** est celle
de son terrain (1024 en prairie, 256 en montagne).

**Villages et villes (depuis le 03/10).** Toute case peuplée est d'abord un **village**. Sa population
grandit selon la même courbe en S qu'avant (freinée par la capacité du terrain, voir §3), mais
**s'arrête net à 256**. Une fois le village plein, le bouton **« Progress to city »** apparaît dans le
zoom, à la place des scientists, et une petite **flèche « up »** dorée sautille sur la case, sur la
carte. Un clic sur le bouton fait passer la case en **ville** : sa population reprend sa progression
jusqu'à 1024, deux fois plus lentement qu'un village (`city_growth_factor`). Les deux statuts se
complètent :

| | Village | Ville |
|---|---|---|
| Habitants au maximum | 256 | capacité du terrain (1024 en prairie) |
| Croissance | courbe en S normale | accroissement ×0,5 |
| Food | ses workers en produisent (3 chacun) ; chacun mange 1 | **aucune production** ; chaque citadin mange **3** : elle doit être nourrie par ses voisines |
| Or par worker | +2 | **+3** |
| Scientists | **aucun** (le « + » des scientists n'existe pas) | oui, c'est là que se fait la science |
| Défense | normale | mégapole (≥ 2/3 de la capacité du terrain) : **remparts**, garnison ×1,5 |

On obtient ainsi une civilisation réaliste : des zones agricoles (villages) entourent des zones
urbaines denses (villes) qui concentrent la science, l'or et la population. **Un village plein en
plaine nourrit 1/4 d'une ville** : il en faut 4 pour une ville de 1024 (6 en forêt ; voir §4). Les autres règles
(garnison, armée, colons, Boost, batailles) sont les mêmes dans les deux cas.

- **Downgrade to village.** Dans le zoom d'une ville en paix, un gros bouton « Downgrade to village »
  (sous Boost) la fait redevenir village, après confirmation (le jeu continue pendant la question). Ses
  scientists redeviennent workers, puis les habitants sont ramenés à 256 **en proportion** : workers,
  garnison et colons gardent leurs parts (une ville de 600 workers et 200 fighters donne un village
  d'environ 190 workers et 63 fighters). Le village peut ainsi nourrir sa garnison comme la ville
  le faisait, sans dépendre de ses voisines. L'armée, qui a sa propre place, reste entière. Sur un village, la place du bouton reste vide pour que
  les autres boutons ne bougent pas.
- **Famine.** Une ville affamée dont les habitants retombent à **256 ou moins** sous l'effet de la
  famine redevient automatiquement un village (ses scientists restants redeviennent workers). Ses
  workers produisent de nouveau de la food, ce qui arrête la famine. Pour la refaire ville, il faut
  recliquer sur « Progress to city ». Une ville qui descend sous 256 autrement (bataille) reste une
  ville. Conséquence : une ville fondée sans voisines pour la nourrir (256 citadins mangent 768 et elle
  ne produit rien) redevient village au premier mort de faim, soit environ 1,1 s plus tard. Il faut au
  moins 2 villages pleins autour pour qu'une ville tienne (§4).
- **Ville prise.** Le statut de ville reste attaché à la case : une ville conquise reste une ville
  pour son vainqueur. Elle ne redevient libre (et village à la prochaine colonisation) que si la
  bataille la laisse vide.
- **Montagne.** Sa capacité (256) est déjà celle d'un village ; la courbe en S n'y atteint jamais 256
  toute seule, il faut quelques clics de Boost pour remplir le village. Passée en ville, elle ne grandit
  pas plus, mais peut accueillir des scientists.
- **Commandes.** Le passage en ville (`FoundCityCommand`) et le retour au village
  (`DowngradeCityCommand`) sont des commandes, comme les autres actions, pour l'humain comme pour
  l'IA. Le premier n'est possible que sur un village plein, en paix ; le second sur une ville en paix.

**Terrains (depuis le 03/10).**

| Terrain | Capacité | Food par worker de village | Or par worker | Défense | Tuile |
|---|---|---|---|---|---|
| Plaine | 1024 | **4** | 2 | ×1 | herbe et fleurs |
| Forêt | 768 | 3 | 2 | ×1 | frondaisons rondes |
| Colline | 768 | 2,5 | 2 | **×1,5** | croupes herbeuses |
| Marais | 512 | 2 | 2 | ×1 | mares, roseaux et massettes |
| Montagne | 256 | 3 | **3** | **×2** | pics enneigés |
| Eau | 0 (inhabitable) | — | — | — | vagues |

La food est `food_per_worker`, l'or de montagne `mountain_gold_per_worker`, la défense
`terrain_defense` (tous dans `GameRules`). En ville, un worker ne produit pas de food et rapporte 3
d'or quel que soit le terrain. Les tuiles sont générées par `tools/generate_tiles.gd`.

**Types de carte** (`MapGenerator`, choisi dans la fenêtre « Nouvelle partie ») :
- **Îles** : de l'eau partout, et **deux fois plus d'îles que de joueurs**, compactes et séparées par
  l'eau, loin des bords. Chaque joueur démarre seul sur une île.
- **Continents** : **deux continents** entourés d'océan, côte à côte dans le sens de la plus grande
  dimension de la carte. Les joueurs sont répartis en alternance : au moins un par continent.
- **Lacs** : une grande plaine semée de quelques grandes étendues d'eau (environ 15 % de la carte).
- **Méditerranée** : une grande mer centrale à la côte découpée (35 % de la carte), entourée de terres
  jusqu'aux bords.

Sur les terres, les montagnes sont semées au hasard, en nombre variable d'une partie à l'autre
(×0,8 à ×1,8). Forêts, collines et marais forment de petits massifs (de 1 à 4 cases), les marais au
bord de l'eau quand c'est possible. Ces quantités suivent la surface des terres.

**Taille minimale** (largeur et hauteur), pour que les contraintes tiennent :

| Type | 2 joueurs | 3 joueurs | 4 joueurs |
|---|---|---|---|
| Îles | 8 | 9 | 11 |
| Continents | 7 | 8 | 8 |
| Lacs | 4 | 5 | 6 |
| Méditerranée | 6 | 6 | 7 |

La fenêtre « Nouvelle partie » relève la largeur et la hauteur si besoin.

**Départ (depuis le 03/10).** On ne choisit plus sa case de départ : comme pour les IA, elle est tirée
au hasard pour chaque joueur, humain compris, toujours en **plaine**, la plus éloignée possible des
autres départs (avec un peu de hasard) et de préférence loin de l'eau. Les voisines d'une case de départ
ne sont jamais des montagnes. La partie commence aussitôt, la case de départ du joueur sélectionnée.
Si une carte trop petite ne permet pas une île ou un continent par joueur après 30 essais, les départs
sont simplement répartis sur les terres les plus éloignées.

**Traverser l'eau.** Il n'existe pas encore de moyen de traverser l'eau. La navigation viendra plus tard, à rechercher
dans l'arbre technologique. Sur la carte « Îles », chaque
joueur reste donc seul sur son île, et deux continents ne peuvent pas s'atteindre (voir §11).

**Brouillard de guerre.** Toute la carte est d'abord dans le brouillard, **eau comprise** (depuis le
03/10). Un joueur voit ses cases et leurs voisines, et se
souvient du terrain déjà découvert. Une case ennemie en vue porte un voile à la couleur de son
propriétaire et affiche sa population totale, sans le détail. La composition n'est révélée qu'aux
joueurs engagés dans une bataille sur la case.

**Agglomérations et population sur la carte.** Chaque case occupée et en vue, celles du joueur comme
les cases ennemies, montre son agglomération, dessinée sur la tuile, et sa population totale en
dessous. Le type d'agglomération dépend du statut de la case et, pour une ville, de son remplissage
(population totale ÷ capacité du terrain) :

| Statut et remplissage | Agglomération (antiquité) | Prairie (1024) | Montagne (256) |
|---|---|---|---|
| village | **village** : trois huttes au toit de chaume | ≤ 256 | ≤ 256 |
| ville, jusqu'aux deux tiers | **ville** : temple grec entouré de maisons | < 683 | < 171 |
| ville, au-delà | **mégapole** : cité ceinte d'un rempart, avec grand temple, tour de guet et maisons serrées | ≥ 683 | ≥ 171 |

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

    opacité = 0,8 × population totale ÷ capacité du terrain de la case (celle d'une ville)

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
- **Ville fondée.** Quand le joueur fait passer un village en ville, l'icône de la ville, à sa couleur,
  surgit avec le titre « VILLE FONDÉE » sur des feux d'artifice.
- **Retour au village.** Quand une ville du joueur redevient village, l'icône du village, à sa
  couleur, surgit sur une pluie de braises avec le titre « RETOUR AU VILLAGE », ou « VILLE AFFAMÉE »
  si c'est la famine.
- **Flèche « up ».** Sur chaque village plein du joueur qui peut passer en ville, une petite flèche
  dorée sautille et luit en haut à droite de la case.

**Sélection.** Un clic gauche sur une case la sélectionne et l'affiche dans le zoom (ou, sur une case
cible, y envoie les colons et l'armée de la case sélectionnée). Un **clic droit** sur la carte
désélectionne la case : le zoom revient à « Cliquez sur une case ».
- **Flash de conquête.** Toute case en vue qui change de main par la guerre s'illumine d'un éclair
  blanc, avec une onde à la couleur de son nouveau propriétaire (rouge si elle devient libre).
- **Onde sur la frontière.** Quand le territoire du joueur s'agrandit, par colonisation ou conquête,
  un front lumineux blanc part de la nouvelle case et parcourt toute sa frontière comme un cercle qui
  grandit, en s'estompant. Les réglages sont `WAVE_SPEED` (7 rayons de case par seconde),
  `WAVE_WIDTH` et `WAVE_STEPS`, dans `scripts/view/hex_map.gd`.
- **Boost.** Chaque clic réussi fait s'envoler un « +1 » de la case et du bouton Boost.
- **Découverte.** Une case qui vient d'être découverte sort du brouillard en fondu, en 0,8 s
  (`REVEAL_TIME`), avec un léger éclat.
- **Sacs de grain.** Chaque flux de food entre deux cases du joueur (§4) est montré par un sac de
  grain qui glisse en boucle, avec un petit cahot, de la case qui exporte vers celle qui reçoit, en
  1,6 s (`FOOD_FLOW_PERIOD`), avec un fondu aux deux bouts. Le sac est plus gros quand le flux est fort
  (de 0,32 à 0,48 rayon de case, plein à 512 par cycle). Chaque flux a son propre décalage, pour que
  les sacs ne partent pas ensemble. Seuls les flux du joueur sont montrés : rien n'est révélé de
  l'économie ennemie.
- **Champs.** Chaque village en vue est entouré de parcelles de blé doré et de jeunes pousses, en pixel
  art, sous ses huttes. Il y en a de plus en plus à mesure qu'il grandit : une parcelle par sixième de
  sa capacité atteint, de 1 (village naissant) à 6 (village plein de 256)
  (`assets/settlements/antiquity_fields_1.png` à `_6.png`, générées par `tools/generate_settlements.gd`).
  Les villes n'en ont pas : on voit d'un coup d'œil les zones agricoles autour des villes.
- **Fortifications.** Chaque case du joueur qui a une **garnison** est fortifiée le long de ses
  frontières : une **palissade** de pieux appointés, puis un **mur de pierre** crénelé à partir de
  100 fighters en garnison (`WALL_STONE_GARRISON`). Comme les frontières, il n'y a pas de mur entre
  deux cases du joueur : les fortifications forment une grande muraille autour de sa civilisation, et
  une case sans garnison y fait un **trou** bien visible, qui montre la zone non protégée. Seules les
  cases du joueur sont fortifiées à l'écran (la garnison ennemie reste cachée). Réglages dans
  `scripts/view/hex_map.gd`.
- **Armée prête.** Un petit soldat qui marche sur place, sur un disque clair, en haut à gauche d'une
  case du joueur, signale qu'une armée y attend, prête à partir. Les armées ennemies restent cachées
  (on n'en voit que la population totale de la case).

Ces effets sont purement visuels. Ils suivent les signaux `World.owner_changed`, émis quand une case
change de propriétaire, `World.city_founded`, émis quand un village passe en ville, et
`World.city_lost`, émis quand une ville redevient village. Sacs de grain et champs suivent les
échanges de food à chaque image.

**Sons** (`scripts/view/sound_fx.gd`, sons CC0 de Kenney et OpenGameArt, crédits dans
`assets/sounds/CREDITS.md`). Chaque bruitage mêle plusieurs sons, avec des instants, volumes et
hauteurs un peu tirés au hasard, pour ne jamais sonner pareil :
- **Bataille** : quand le joueur clique sur une case en guerre en vue, une lame est tirée puis quatre
  chocs de fer résonnent en 1,2 s environ.
- **Chariot** : quand ses colons partent, un grincement puis les cahots des roues pendant le trajet.
- **Victoire** : quand il gagne une case par la guerre, une clameur de foule de 2,6 s, prise à un endroit
  différent de l'enregistrement à chaque fois.
- **Ville fondée** : une clameur de foule plus légère et plus aiguë que celle de la victoire.
- **Défaite** : quand il perd une case par la guerre, un choc sourd, puis la même foule plus grave et
  plus lente, comme consternée. Le même son accompagne une ville du joueur qui redevient village
  à cause de la famine.
- **Clic** : un petit clic sur tous les boutons. Ce sont les boutons du menu, des fenêtres et du jeu,
  accrochés automatiquement, ainsi que les boutons dessinés du zoom : « + », « − », Settler, Army,
  raccourcis, « Progress to city » et « Downgrade to village ».
- **Boost** : un petit tir laser à chaque clic réussi, un peu plus aigu ou grave à chaque fois.

**Musique de fond** (`scripts/view/background_music.gd`, musiques CC0, crédits dans
`assets/music/CREDITS.md`). C'est une musique discrète, de style antique, dans le menu et en jeu. Deux
morceaux s'enchaînent en boucle, en commençant par l'un des deux au hasard :
- *Greek instruments* de Spring Spring (1 min 41), joué avec des instruments grecs ;
- *Ancient Mysteries* de Sperry Lion (2 min).

Chaque morceau démarre par un fondu de 3 s. Le volume est bas (−20 dB, `VOLUME_DB`) pour rester sous
les bruitages.

**Bouton son.** Un petit haut-parleur en bas à droite de l'écran coupe tous les sons d'un clic
(bruitages et musique) : il est alors barré d'une croix rouge. Un autre clic remet le son. C'est le bus
audio principal qui est rendu muet, donc le réglage tient au retour au menu et dans les parties
suivantes.

**Menu.** Un bouton « Menu », au bout de la barre des ressources en haut du panneau de droite, propose
pour l'instant un seul choix, « Quitter ». Il demande « Do you really want to quit ? » (Yes / No) et le
jeu est en pause pendant la question ; Yes **abandonne** la partie et ouvre la fenêtre de fin (§10). La touche Échap fait la même
chose. En fin de partie, Quitter et Échap ramènent directement au menu.

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

Le frein compte tous les habitants de la case, colons compris. Une montagne (256) freine
donc quatre fois plus tôt qu'une prairie. Le frein utilise toujours la capacité du **terrain** : dans un village,
la croissance garde la vitesse de cette courbe, puis s'arrête net à 256 (`village_capacity`).
Passée en ville, la case reprend la courbe là où elle en était, à mi-vitesse. L'armée ne compte pas
dans le frein (elle a sa propre place). La croissance est continue (effectifs flottants), mais un
rôle ne grandit que s'il compte au moins **un individu entier**.

Valeurs *(calculé, vérifié en simulation)* : un worker seul sur une prairie, sans Boost. Ce tableau
décrit la courbe en S seule. Dans le jeu, un village s'arrête à 256 (3 min 43 depuis 2 workers) ;
passée en ville aussitôt, la case met encore **4 min 46** pour atteindre 90 % (922), car une ville
grandit deux fois moins vite (`city_growth_factor` = 0,5 sur l'accroissement).

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
et les scientists, ou entre les workers et la garnison. Dans un village, la ligne des scientists est remplacée
par « Village : population / 256 », puis par le bouton « Progress to city » quand il est plein. Les boutons Settler et Army font de même avec
les colons et l'armée (clic gauche pour remplir, clic droit pour vider). Maintenir un bouton accélère :
un individu de plus au bout de **0,4 s** (`hold_delay`), puis 0,4/2 s, 0,4/3 s, etc., jusqu'à **500 par
seconde** (`max_hold_rate`), deux réglages de `GameRules` : c'est la vitesse à laquelle un humain peut
mobiliser sa population. *(Calculé)* :
on atteint 10 par seconde en ≈ 0,8 s et 500 par seconde en ≈ 2,4 s. Aucune commande n'est possible sur une case en guerre.

---

## 4. Nourriture (food)

| Variable | Valeur | Rôle |
|---|---|---|
| `food_per_worker` | **4** en plaine, 3 en forêt et en montagne, 2,5 en colline, 2 en marais | Food produite par worker **d'un village** et par cycle, selon le terrain (0 dans une ville). |
| `food_per_individual` | **1** | Food mangée par worker, scientist ou fighter de garnison, par cycle, dans un village. |
| `city_food_per_individual` | **3** | Idem dans une ville : un citadin mange 3. |
| `army_food` | **0,5** | Ration mangée par chaque fighter de l'armée d'une case, par cycle. |
| `starvation_grace` | **1 s** | Délai de grâce avant la première mort. |
| `starvation_interval` | **0,1 s** | Délai entre deux morts tant que la famine dure. |

Formules :

    solde d'un village = F × workers − 1 × (workers + garnison) − 0,5 × armée
                      (F = food par worker du terrain : 4 en plaine, 3 en forêt…)
    solde d'une ville   = − 3 × (workers + scientists + garnison) − 0,5 × armée

- **Surplus d'un village plein** (256 workers) : **768** en plaine (un worker y nourrit 3 fighters de
  garnison), 512 en forêt et en montagne, 384 en colline, 256 en marais.
- **Une ville ne produit rien** et chaque citadin, workers compris, mange **3** par cycle. Une ville
  pleine (1024) a besoin de **3072 food** par cycle : le surplus de 4 villages de plaine pleins, ou de
  6 villages de forêt.
- **Partage prioritaire (depuis le 03/10).** Le surplus d'une case va **uniquement aux voisines du même
  joueur qui manquent de food** (solde négatif), en proportion de leur manque, sans le dépasser. Ce
  qui reste est perdu (pas de stock). Le partage ne se fait qu'entre voisines directes, pas au-delà.
  Les cases en guerre, figées, n'envoient ni ne reçoivent rien.
- **Taille d'une ville selon ses villages** *(calculé et vérifié en simulation, villages de plaine
  pleins sans garnison, qui ne nourrissent qu'elle)* : chaque village de plaine plein nourrit
  768 ÷ 3 = 256 citadins (forêt ou montagne : 171, colline : 128, marais : 85).

  | Villages de plaine pleins autour | 1 | 2 | 3 | 4 |
  |---|---|---|---|---|
  | Taille maximale de la ville | ≈ 256 (à la limite) | ≈ 512 | 768 | **1024** |

  Le seuil est juste : une garnison dans les villages, ou un village partagé entre deux villes, et la
  ville plafonne plus bas (4 villages avec 20 fighters de garnison chacun : 918).
- **Armée.** L'armée d'une case mange sa ration (0,5 par fighter) sur la food de sa case, **avant** que
  le surplus ne soit exporté. Une armée complète (1024) mange 512 : exactement le surplus d'un village
  plein en forêt ou en montagne, qui n'exporte alors plus rien (un village de plaine en garde 256 à
  exporter). Si la case n'y suffit pas, elle reçoit de ses voisines comme
  toute case dans le besoin.
- Les colons en attente, l'armée en route et les fighters engagés dans une bataille **ne mangent pas**.
- **Famine.** Une case dont la food disponible (son solde plus ce qu'elle reçoit) est négative
  bénéficie de 1 s de grâce. Ensuite, elle perd **un individu toutes les 0,1 s** (10 par seconde) :
  un fighter de son armée d'abord, puis un scientist, puis un fighter de garnison, puis un worker,
  jusqu'à retrouver l'équilibre.
  Une ville que la famine ramène à 256 habitants ou moins redevient un village (§2).
- Une case assiégée est figée : pas de famine.

---

## 5. Or

| Variable | Valeur | Rôle |
|---|---|---|
| `gold_per_role["worker"]` | **+2** | Or rapporté par worker et par cycle, dans un village. |
| `city_gold_per_worker` | **+3** | Or rapporté par worker d'une ville, par cycle. |
| `gold_per_role["scientist"]` | **−1** | Or coûté par scientist et par cycle. |
| `gold_per_role["fighter"]` | **−1** | Or coûté par fighter de garnison et par cycle. |
| `conversions_per_cycle` | **1** | Reconversions par cycle quand l'or est épuisé. |

Formule :

    revenu d'un village = 2 × workers − garnison
    revenu d'une ville   = 3 × workers − scientists − garnison

- **Un worker de village paie 2 fighters de garnison**, le même ratio que pour la food. **Un worker
  de ville en paie 3** : les villes sont riches, mais dépendent de leurs voisines pour manger.
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

Les scientists ne vivent que dans les **villes** : un village n'en accueille aucun (§2, « Villages et
villes »). La science demande donc de fonder des villes, et de les nourrir.

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
| `max_army` | **1024** | Taille maximale de l'armée d'une case : c'est sa place, en plus de la capacité de la case. |

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
  déplacements fluides. La seule limite est `max_army` pour l'armée de la case (sa place, en plus
  des habitants : un village plein peut accueillir une armée complète). Le reste attend dans la case
  de départ ;
- **une case à soi assiégée** : renforts de la garnison, **sans limite**. La case est figée, donc son
  armée ne pourrait pas repartir, et en garnison les fighters défendent mieux (force 3 au lieu de 2) ;
- **une case ennemie, ou toute case en guerre** (même entre deux autres joueurs) : elle rejoint la
  bataille, **sans limite**.

**Trajet de l'armée.** Comme les colons, l'armée quitte aussitôt sa case et n'arrive qu'au bout de
`travel_time` (1 s). Une attaque ne commence donc qu'à l'arrivée.
- **Place réservée** seulement vers une case à soi en paix : la limite `max_army` y est réservée
  pendant le trajet.
- **À l'arrivée**, on regarde ce qu'est devenue la case :
  - à soi en paix : l'armée y reste une armée ;
  - à soi assiégée : elle renforce la garnison ;
  - ennemie ou en guerre : elle livre bataille ;
  - devenue libre et en paix, ou sans place : elle rentre dans sa case de départ comme armée, dans la
    limite de `max_army`. Ce qui ne peut pas rentrer est perdu.
- Les fighters en route comptent dans la population du joueur (élimination, §10).
- **Animation.** Un petit soldat qui marche, tourné vers sa destination, fait le même trajet en fondu
  que le chariot des colons.
- **IA.** Elle tient compte de ses troupes et colons en route : elle ne renvoie pas de renforts déjà
  en chemin, ne relance pas une attaque déjà en route, et ne colonise pas deux fois la même case.

Les colons en attente comptent dans la capacité de la case ; **l'armée non** : elle a sa propre place,
jusqu'à `max_army`, mais elle mange sa ration (0,5 par fighter, §4). Quand des fighters quittent
l'armée (vers la garnison ou en redevenant workers), ils redeviennent des habitants : il leur faut de
la place libre dans la case. Si la case est attaquée, son armée la défend aussi, une fois la garnison
tombée. Les colons, eux, ne la défendent pas.

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
| `terrain_defense` | **×2** en montagne, **×1,5** en colline | Multiplie la force d'un défenseur selon son terrain. |
| `megapolis_defense` | **×1,5** | Remparts : multiplie la force de la garnison d'une mégapole (cumulable avec la montagne). |
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

    force du défenseur = (3 × garnison × 1,5 si mégapole + 2 × armée + 0,25 × workers) × 2 en montagne, × 1,5 en colline
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
(`starvation_interval`), jusqu'à revenir à sa capacité. L'armée (qui a sa propre place), les workers
et les scientists sont épargnés. Ces morts s'ajoutent à celles de la famine et de la faillite.

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
| `settle_fill_ratio` | **22 %** | **20 %** | **15 %** | Remplissage d'une case, rapporté à la capacité de son **terrain** (225, 205 et 154 en prairie : moins qu'un village plein), à partir duquel elle envoie des colons. |
| `settlers_per_wave` | **32** | **16** | **12** | Colons envoyés à chaque vague. |
| `city_food_margin` | **×1,2** | **×1,2** | **×1,2** | Un village plein ne passe en ville que si ses voisines peuvent nourrir la ville qu'il deviendrait, avec cette marge. |
| `science_ratio` | **40 %** | **15 %** | **5 %** | Part de la population de chaque **ville** en scientists. |
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
3. **Villes.** Chaque village plein, en paix, passe en ville si ses voisines pourraient la nourrir :
   elle estime ce que chacune lui enverrait selon le partage prioritaire (§4), en tenant compte de
   leurs autres voisines dans le besoin, et exige 1,2 fois la consommation de la ville à 256 citadins
   (`city_food_margin`). En pratique, il lui faut au moins 2 villages pleins autour. Comme la garnison et la science, c'est un simple bouton du
   zoom, pas une action sur la carte. Elle ne rétrograde jamais une ville volontairement.
   Une ville que la famine a refait village sera refondée une fois le village de nouveau plein.
4. **Scientists et garnison.** Dans chaque case en paix, elle ajuste ses scientists (dans ses villes
   seulement) puis sa garnison aux cibles du profil, en convertissant des workers dans un sens ou dans
   l'autre. Les deux restent dans un budget qui garde l'or et la food positifs, avec 10 % de marge
   (`budget_share`) :

       scientists + garnison ≤ 1,8 × workers   (soit au plus ≈ 64 % de la population de la case)

   Dans une ville, seul l'or compte (ses voisines la nourrissent, quel que soit le rôle de ses
   habitants) : un worker de ville paie 3 non-workers, la limite est donc plus haute. La science est servie
   d'abord, la garnison prend le reste du budget.
5. **Colonisation**, s'il est temps d'agir (voir plus haut). Parmi ses cases en paix remplies
   au-delà de `settle_fill_ratio`, la plus remplie envoie une vague de colons vers sa meilleure case
   libre voisine. Elle préfère la prairie à la montagne, et une case qui touche le plus de terres
   libres. Une seule vague à la fois.
6. **Boost.** Pendant une rafale, chaque clic va à sa case en paix la moins remplie.

Une case garde toujours au moins **2 workers** (`keep_workers`) pour continuer à grandir.

---

## 10. Fin de partie

La partie se termine quand le joueur humain est éliminé, ou quand il ne reste qu'un seul joueur en
lice. Un joueur est éliminé quand il n'a plus personne, nulle part : cases, colons (en route compris), armées en attente
et fighters engagés dans des batailles compris. Le joueur peut aussi **abandonner** (Menu > Quitter ou
Échap, puis Yes).

La fenêtre de fin annonce le résultat avec une illustration en pixel art : trophée et « Victoire ! »,
épée brisée et « Défaite… », ou drapeau blanc et « Vous avez abandonné ». Elle montre ensuite
l'évolution de la population, de la science et de la food de chaque joueur, **un graphique par
onglet** (Population, Science, Food / cycle) pour bien voir chacun ; le réticule de survol garde le même
instant d'un onglet à l'autre. Le bouton « Menu principal » ramène au menu.

---

## 11. Points d'attention pour l'équilibrage

Ce sont des constats sur les règles actuelles, pas des bugs.

- **Pas de traversée de l'eau.** Sur la carte « Îles », chaque joueur reste seul sur son île : pas de
  guerre possible, et la partie ne peut pas se terminer. De même, deux continents ne peuvent pas
  s'atteindre : la partie ne peut se terminer que si tous les survivants sont sur le même continent. Prévu : la navigation, à rechercher dans l'arbre technologique, et d'autres conditions de victoire.
- **Garnison ou armée.** L'armée en attente ne coûte pas d'or et ne mange qu'une demi-ration ; les
  fighters engagés en bataille ne coûtent rien. La garnison coûte de l'or et une ration entière, mais
  défend deux fois mieux (et derrière les remparts d'une mégapole). Le choix entre garnison (chère,
  solide) et armée (bon marché, mobile, fragile) dépend donc de `army_per_garrison`, de `army_food`
  et du coût en or et en food des fighters.
- **Ratio 2:1 identique pour l'or et la food, dans les villages.** Un village équilibré en food l'est
  aussi en or. Les villes cassent ce lien : elles rapportent plus d'or (3 par worker) mais mangent la
  food de leurs voisines.
- **Seuil juste pour les villes.** 4 villages de plaine pleins nourrissent exactement une ville de 1024. Une
  garnison dans ces villages, ou un village partagé entre deux villes, et la ville plafonne plus bas.
  Levier : `city_food_per_individual` (2,9 donne une petite marge).
- **Montagne et ville.** En montagne, la ville ne gagne pas de place (capacité 256 dans les deux cas),
  seulement le droit d'accueillir des scientists.
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
| `map=` | `continents` | Type de carte : `islands`, `continents`, `lakes` ou `mediterranean`. |
| `minutes=` | 30 | Durée maximale d'une partie. |
| `seed=` | 1 | Graine de la première partie (les suivantes : +1, +2…). Même graine, même partie. |
| `rules.<réglage>=` | — | Change un réglage de `GameRules`, par exemple `rules.army_per_garrison=3`. |
| `<niveau>.<réglage>=` | — | Change un réglage d'un profil, par exemple `aggressive.attack_margin=1.5`. |
| `report=` | — | Écrit aussi le rapport dans ce fichier. |

Une partie de 30 minutes à 4 IA prend de 30 s à 1 min de calcul.
