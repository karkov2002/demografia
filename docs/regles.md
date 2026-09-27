# Règles du jeu et paramètres d'équilibrage

État des règles au 27/09/2026. Toutes les valeurs réglables sont des variables de `GameRules`
(`scripts/model/game_rules.gd`). Le fichier `data/game_rules.tres` ne les surcharge pas pour l'instant :
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
| Joueurs | **2 à 4** | fenêtre « Nouvelle partie » | Le joueur 1 est l'humain, les autres des IA. |

**Règle d'or.** La population totale d'une case ne dépasse jamais sa capacité. Ce total compte tous
les rôles, les colons en attente et l'armée. Il y a une seule exception, les batailles (voir §8).

**Départ.** Le joueur humain choisit sa case de départ (jamais sur l'eau). Chaque IA tire ensuite la
sienne au hasard parmi les cases libres hors de l'eau. La génération de la carte garde toujours au
moins une case hors de l'eau par joueur.

**Brouillard de guerre.** L'eau est toujours connue. Un joueur voit ses cases et leurs voisines, et se
souvient du terrain déjà découvert. Une case ennemie en vue porte un voile à la couleur de son
propriétaire et affiche sa population totale, sans le détail. La composition n'est révélée qu'aux
joueurs engagés dans une bataille sur la case.

**Joueurs IA.** Pour l'instant, une IA choisit sa case de départ puis ne fait plus rien : elle ne
colonise pas, n'attaque pas et n'utilise pas Boost. Sa croissance est ralentie par
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

Cliquer frénétiquement fait partie du jeu. Pour l'instant, l'IA n'utilise pas Boost : ce sera le cas
de la future IA.

**Changements de rôle.** Les boutons « + » et « − » du zoom échangent un individu entre les workers
et les scientists, ou entre les workers et la garnison. Les boutons Settler et Army font de même avec
les colons et l'armée (clic gauche pour remplir, clic droit pour vider). Maintenir un bouton accélère :
un individu au bout de 1 s, puis 1/2 s, 1/3 s, etc., jusqu'à **500 par seconde** (`MAX_HOLD_RATE`,
dans `scripts/view/hex_preview.gd`). Aucune commande n'est possible sur une case en guerre.

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

**Armée.** Le bouton **Army** prend d'abord les fighters de la garnison, puis enrôle des workers qui
deviennent fighters. Le clic droit renvoie un fighter de l'armée en worker. L'armée part vers une
case voisine :
- **une case à soi en paix** : ses fighters y rejoignent la garnison, dans la limite de la place
  libre (règle d'or : c'est là qu'on prépare les armées) ;
- **une case à soi assiégée** : renforts de la garnison, **sans limite** ;
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

**Mêlée générale.** Les camps sont le défenseur (le propriétaire, avec toute sa population) et
chaque attaquant (avec son armée engagée). À chaque cycle, chaque camp fait **un échange avec chacun
des autres camps**, et les pertes sont simultanées. Dans un échange avec le défenseur, celui-ci perd,
dans cet ordre de priorité :

| Le défenseur perd | L'attaquant perd |
|---|---|
| 1 fighter de sa **garnison** | **2** fighters (`army_per_garrison`) |
| sinon 1 fighter de son **armée** | 1 fighter |
| sinon **5 workers** | 1 fighter |
| sinon **10 scientists** | 1 fighter |

Entre deux attaquants, chacun perd 1 fighter par échange.

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

**Ordres de grandeur *(calculé)*.** En défense, 1 fighter de garnison vaut 2 fighters d'armée,
10 workers ou 20 scientists. Avec un seul attaquant (un échange par seconde) : 100 attaquants contre
une garnison de 50 fighters s'annulent en 50 s ; contre une case sans fighter, ils tuent 500 workers
en 100 s.

---

## 9. Fin de partie

La partie se termine quand le joueur humain est éliminé, ou quand il ne reste qu'un seul joueur en
lice. Un joueur est éliminé quand il n'a plus personne, nulle part : cases, colons, armées en attente
et fighters engagés dans des batailles compris. Une fenêtre affiche alors l'évolution de la population, de la science et de la food de chaque
joueur.

---

## 10. Points d'attention pour l'équilibrage

Ce sont des constats sur les règles actuelles, pas des bugs.

- **Garnison ou armée.** L'armée en attente et les fighters engagés en bataille ne coûtent ni or ni
  food ; seule la garnison coûte. En échange, la garnison défend deux fois mieux. Le choix entre
  garnison (chère, solide) et armée (gratuite, mobile, fragile) dépend donc de `army_per_garrison`
  et du coût en or et en food des fighters.
- **Ratio 2:1 identique pour l'or et la food.** Une case équilibrée en food l'est aussi en or. Pour
  créer de vrais choix, il suffirait de modifier l'un des deux.
- **Démarrage exponentiel.** Avec 2 workers, les premières minutes sont lentes, et Boost y pèse
  énormément : à 2 workers, un clic (+50 %) vaut environ 17 s de croissance naturelle. L'IA
  n'utilise pas encore Boost.
- **Conquête coûteuse à entretenir.** Des fighters conquérants sans workers ne produisent ni food ni
  or. Ils meurent vite, par famine, faillite et surpeuplement, si on ne les convertit pas en workers.
