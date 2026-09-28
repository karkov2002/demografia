# Règles du jeu et paramètres d'équilibrage

État des règles au 28/09/2026. Toutes les valeurs réglables sont des variables de `GameRules`
(`scripts/model/game_rules.gd`), sauf le comportement des IA, réglé dans `AIProfile` (voir §9). Le fichier `data/game_rules.tres` ne les surcharge pas pour l'instant :
ce sont donc les valeurs par défaut du script qui s'appliquent. On peut les modifier dans l'inspecteur
de Godot en ouvrant `data/game_rules.tres`.

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
| Capacité prairie | **1024** | `scripts/model/terrain.gd` | Règle d'or : population maximale d'une case. |
| Capacité montagne | **256** | `scripts/model/terrain.gd` | Idem. |
| Capacité eau | **0** | `scripts/model/terrain.gd` | Inhabitable. |
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

**Joueurs IA.** Une IA joue avec les mêmes commandes et les mêmes règles qu'un humain : elle colonise,
défend, attaque et clique sur Boost selon son niveau (voir §9). Sa croissance est ralentie par
`ai_growth_factor` (voir §3).

---

## 3. Population et croissance

| Variable | Valeur | Rôle |
|---|---|---|
| `time_to_full["worker"]` | **300 s** (5 min) | Temps pour passer de 1 à 1024 workers. |
| `time_to_full["scientist"]` | **1200 s** (20 min) | Temps pour passer de 1 à 1024 scientists. |
| `time_to_full["fighter"]` | **0** | Les fighters (garnison et armée) ne se reproduisent jamais. |
| `FULL_POPULATION` | **1024** | Constante de référence de ces durées. |
| `ai_growth_factor` | **0,8** | Difficulté : multiplie l'accroissement par cycle des IA. |

**Formule.** À chaque cycle, chaque rôle est multiplié par un taux fixe :

    taux = 1024 ^ (cycle_duration / time_to_full)
    taux IA = 1 + (taux − 1) × ai_growth_factor

La croissance est continue (effectifs flottants), mais un rôle ne grandit que s'il compte au moins
**un individu entier**. Quand la case approche de sa capacité, la place restante est partagée entre
les rôles au prorata de leur croissance.

Valeurs *(calculé)* :

| Rôle | Taux / cycle | Doublement | 2 → 1024 | Taux IA | Doublement IA | 2 → 1024 IA |
|---|---|---|---|---|---|---|
| worker | ×1,02337 (+2,34 %) | 30 s | 4 min 30 | ×1,01870 (+1,87 %) | 37,4 s | ≈ 5 min 37 |
| scientist | ×1,00579 (+0,58 %) | 120 s | 18 min | ×1,00463 (+0,46 %) | 150 s | ≈ 22 min 30 |
| fighter (garnison) | ×1 | — | — | ×1 | — | — |

**Boost.**

| Variable | Valeur | Rôle |
|---|---|---|
| `boost_workers` | **1** | Workers ajoutés à chaque clic sur Boost, sur une case du joueur en paix, dans la limite de la place libre. |

Cliquer frénétiquement fait partie du jeu. L'IA utilise Boost aussi, à un rythme humain qui dépend de
son niveau (voir §9).

**Changements de rôle.** Les boutons « + » et « − » du zoom échangent un individu entre les workers
et les scientists, ou entre les workers et la garnison. Les boutons Settler et Army font de même avec
les colons et l'armée (clic gauche pour remplir, clic droit pour vider). Maintenir un bouton accélère :
un individu de plus au bout de **0,4 s** (`HOLD_DELAY`), puis 0,4/2 s, 0,4/3 s, etc., jusqu'à **500 par
seconde** (`MAX_HOLD_RATE`). Ces deux constantes sont dans `scripts/view/hex_preview.gd`. *(Calculé)* :
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
libre ou au joueur, qui n'est pas en guerre. À l'arrivée, ils redeviennent workers, dans la limite de
la place libre ; le reste attend.

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

Les colons et l'armée en attente comptent dans la capacité de la case. Si la case est attaquée, son
armée la défend aussi, une fois la garnison tombée. Les colons, eux, ne la défendent pas.

---

## 8. Batailles

| Variable | Valeur | Rôle |
|---|---|---|
| `army_per_garrison` | **2** | Fighters que perd l'attaquant pour tuer 1 fighter de garnison. |
| `workers_per_fighter` | **5** | Workers tués par un échange quand le défenseur n'a plus de fighter. |
| `scientists_per_fighter` | **10** | Scientists tués par un échange quand il n'a plus ni fighter ni worker. |
| `garrison_strength` | **3** | Force d'un fighter de garnison dans le rapport des forces. |
| `army_strength` | **2** | Force d'un fighter d'armée (armée du défenseur ou fighters d'un attaquant). |
| `worker_strength` | **1** | Force d'un worker. |
| `mountain_defense` | **×2** | Multiplie la force d'un défenseur en montagne. |

**Mêlée générale.** Les camps sont le défenseur (le propriétaire, avec toute sa population) et
chaque attaquant (avec son armée engagée). À chaque cycle, chaque camp fait **un échange avec chacun
des autres camps**, et les pertes sont simultanées. Les pertes habituelles d'un échange avec le
défenseur sont, dans cet ordre de priorité :

| Le défenseur perd | L'attaquant perd |
|---|---|
| 1 fighter de sa **garnison** | **2** fighters (`army_per_garrison`) |
| sinon 1 fighter de son **armée** | 1 fighter |
| sinon **5 workers** | 1 fighter |
| sinon **10 scientists** | 1 fighter |

Entre deux attaquants, les pertes habituelles sont de 1 fighter chacun par échange.

**Rapport des forces.** Au début de chaque cycle, on calcule la force de chaque camp :

    force du défenseur = (3 × garnison + 2 × armée + 1 × workers) × 2 s'il est en montagne
    force d'un attaquant = 2 × ses fighters engagés

Les scientists et les colons ne comptent pas. Une force inférieure à 1 compte pour 1. Dans chaque
échange :
- le camp **le plus faible** subit ses pertes habituelles **× (force adverse ÷ sa force)** ;
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

**Surpeuplement.** Après une bataille, une case peut dépasser sa capacité. Elle bénéficie alors de
**1 s de grâce** (`starvation_grace`), puis perd **un fighter de garnison toutes les 0,1 s**
(`starvation_interval`), ou à défaut un fighter de son armée, jusqu'à revenir à sa capacité. Les
workers et les scientists sont épargnés. Ces morts s'ajoutent à celles de la famine et de la faillite.

**Exemples *(vérifiés en simulation, un seul attaquant)*.**

| Combat | Forces | Déroulement |
|---|---|---|
| 100 fighters contre 20 workers | 200 contre 20 (×10) | Le défenseur perd 50 workers par échange : la case tombe en **1 s**, pour 1 fighter perdu. |
| 100 fighters contre 50 en garnison, prairie | 200 contre 150 | La garnison perd 1,33 fighter/s, l'attaquant 2/s : **l'attaquant gagne en 26 s** avec 47 survivants. |
| Idem en montagne | 200 contre 300 | L'attaquant perd 2 × 1,5 = 3 fighters/s, la garnison 1/s : **la garnison tient**, il lui reste 26 fighters. |
| 100 fighters contre 100 en garnison, prairie | 200 contre 300 | **La garnison tient**, il lui reste 79 fighters. |

Plus petite armée qui vainc une garnison de T fighters, sans renforts : environ **1,73 × T** en
prairie et **2,45 × T** en montagne. Par exemple 173 fighters contre 100 en prairie, 246 en montagne.
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
| `boost_clicks_per_second` | **2** | **3** | **5** | Clics par seconde pendant une rafale sur Boost. |
| `boost_burst_seconds` | **3 s** | **4 s** | **5 s** | Durée moyenne d'une rafale. |
| `boost_pause_seconds` | **7 s** | **6 s** | **5 s** | Durée moyenne d'une pause entre deux rafales. |
| Boost moyen *(calculé)* | ≈ **0,6 clic/s** | ≈ **1,2 clic/s** | ≈ **2,5 clics/s** | |
| `settle_fill_ratio` | **30 %** | **20 %** | **5 %** | Remplissage d'une case à partir duquel elle envoie des colons. |
| `settlers_per_wave` | **32** | **16** | **8** | Colons envoyés à chaque vague. |
| `science_ratio` | **40 %** | **15 %** | **5 %** | Part de la population de chaque case en scientists. |
| `garrison_ratio` | **75 %** | **40 %** | **25 %** | Garnison d'une case frontalière, en part de la plus grosse population ennemie voisine. |
| `attack_margin` | **0** (jamais) | **×2** | **×1,3** | Marge au-dessus de la plus petite armée qui vaincrait le pire cas. |
| `attack_delay` | — | **60 s** | **20 s** | Temps de réaction : durée minimale pendant laquelle une case ennemie doit être en vue avant d'être attaquée. |
| `army_commit` | **80 %** | **60 %** | **80 %** | Part des workers d'une case que l'IA accepte d'enrôler pour attaquer ou secourir. |

Les durées de rafale et de pause varient au hasard de ±50 %, et le nombre de clics de ±30 %.

**Ce que fait l'IA à chaque cycle**, après le tick, par ordre de priorité. Une case engagée dans une
étape (secours, attaque) est laissée tranquille par les suivantes jusqu'au cycle d'après.

1. **Secours.** Pour chacune de ses cases assiégées, elle vise une garnison dont la force égale à
   elle seule celle des attaquants, plus 1 fighter : 2 × attaquants ÷ (3 × bonus de montagne) + 1.
   Ce sont alors les attaquants qui subissent le rapport des forces. Ses cases voisines en paix
   forment une armée et l'y envoient pour combler l'écart.
2. **Attaque.** Elle ne vise qu'une case ennemie voisine, pas déjà en guerre, en vue depuis au moins
   `attack_delay` secondes. Si la case change de propriétaire, le compteur repart de zéro. Cela laisse
   au joueur qui vient de s'installer le temps d'y monter une garnison. Pour chaque cible, elle estime
   le pire cas : toute la population en garnison, montagne comprise. Elle simule l'assaut selon les
   règles du §8 pour trouver la plus petite armée qui l'emporterait.

       coût = plus petite armée gagnante × attack_margin

   Elle attaque les cibles des moins chères aux plus chères. Pour chacune, elle part de la case
   voisine qui peut réunir la plus grosse armée (armée prête, garnison, puis `army_commit` de ses
   workers), si cette armée atteint le coût.
3. **Scientists et garnison.** Dans chaque case en paix, elle ajuste ses scientists puis sa garnison
   aux cibles du profil, en convertissant des workers dans un sens ou dans l'autre. Les deux restent
   dans un budget qui garde l'or et la food positifs, avec 10 % de marge (`BUDGET_SHARE`) :

       scientists + garnison ≤ 1,8 × workers   (soit au plus ≈ 64 % de la population de la case)

   La science est servie d'abord, la garnison prend le reste du budget.
4. **Colonisation.** Une case en paix remplie au-delà de `settle_fill_ratio` envoie une vague de
   colons vers la meilleure case libre voisine. Elle préfère la prairie à la montagne, et une case qui
   touche le plus de terres libres.
5. **Boost.** Pendant une rafale, chaque clic va à sa case en paix la moins remplie.

Une case garde toujours au moins **2 workers** (`KEEP_WORKERS`) pour continuer à grandir. Ces deux
constantes sont dans `scripts/controllers/ai_controller.gd`.

---

## 10. Fin de partie

La partie se termine quand le joueur humain est éliminé, ou quand il ne reste qu'un seul joueur en
lice. Un joueur est éliminé quand il n'a plus personne, nulle part : cases, colons, armées en attente
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
  1,73 × 1024 ≈ 1770 fighters, plus qu'une seule case ne peut réunir. Pour l'instant, l'IA n'attaque
  qu'à partir d'une seule case source et n'attaque donc jamais une case pleine.
- **Batailles plus décisives (28/09).** Avec le rapport des forces, une nette supériorité écrase vite
  l'adversaire. En simulation (4 IA, 20 min), on compte 50 à 160 attaques par partie, et une IA
  normale a pu être éliminée.
- **Or sans usage.** L'or s'accumule, surtout chez les IA qui gardent leur budget positif. Il n'a pas
  encore d'usage.
- **Conquête coûteuse à entretenir.** Des fighters conquérants sans workers ne produisent ni food ni
  or. Ils meurent vite, par famine, faillite et surpeuplement, si on ne les convertit pas en workers.
