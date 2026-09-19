# OpenProject — refonte UI/UX

Fork d'OpenProject 17.8 dont l'interface a été reconstruite, dans l'esprit de
Plane CE.

La contrainte tenue d'un bout à l'autre : **aucune fonctionnalité retirée**.
Les pages d'origine ne sont pas supprimées, elles sont rangées — chaque
navigation reconstruite garde une section « Vues classiques » repliée qui y
mène. Tout ce qui est disponible sans licence Enterprise reste accessible.

## Ce qui a été reconstruit

Quinze écrans, chacun servi par un contrôleur et une vue propres, et non par
un restylage de l'existant.

| Page | Portée transverse | Portée projet |
| --- | --- | --- |
| Accueil | `/plane/home` | — |
| Mon travail | `/plane/my` | — |
| Mon temps | `/plane/time` | — |
| Projets | `/plane/projects` | — |
| Travail | `/plane/work` | `/projects/:id/plane` |
| Frise (Gantt) | `/plane/gantt` | `/projects/:id/plane-gantt` |
| Tableaux | `/plane/boards` | — |
| Réunions | `/plane/meetings` | — |
| Actualités | `/plane/news` | — |
| Wiki | `/plane/wiki` | — |
| Temps et coûts | `/plane/costs` | — |
| Aperçu | — | `/projects/:id` |

L'URL racine d'un projet sert désormais l'aperçu reconstruit : c'est là
qu'arrivent le sélecteur de projet, la recherche et les fils d'Ariane.
L'aperçu d'origine reste servi à `/projects/:id/apercu-origine`.

## Ce qui n'a pas été reconstruit, et pourquoi

- **Le canevas des tableaux** (colonnes, glisser-déposer, mise à jour en
  direct) reste celui d'OpenProject : composant Angular avec de l'état temps
  réel, le réécrire à moitié ferait perdre des fonctions. Seul l'index a été
  refait.
- **Le générateur de rapports de coûts** reste d'origine, pour la même
  raison : groupements libres, colonnes, export. La page reconstruite donne
  la réponse immédiate et renvoie vers lui.
- **`beforeunload`** reste la boîte native du navigateur. Les navigateurs
  l'imposent délibérément pour empêcher un site de retenir l'internaute ;
  aucun site ne peut la remplacer. Toutes les navigations internes passent en
  revanche par une modale maison.

## Points d'entrée du code

```
app/controllers/plane_*.rb            les onze contrôleurs reconstruits
app/controllers/concerns/plane_scope.rb   portée projet ou transverse
app/views/plane_*/                    les vues
app/views/layouts/_plane_*.html.erb   coquille, navigation, menu de création
app/helpers/plane_*.rb                regroupement des menus, chemins
frontend/src/global_styles/layout/_plane_*.sass   thème et pages
frontend/src/turbo/plane-confirm.ts   modale de confirmation
config/initializers/plane_routes.rb   reprise de la racine d'un projet
```

Les commentaires du code expliquent le *pourquoi* et documentent les pièges
rencontrés — cascade CSS contre Primer, géométrie de la frise, conventions
non documentées d'OpenProject pour greffer une page.

## Lancer

```bash
cp .env.example .env    # puis ajuster PORT, DEV_UID, DEV_GID
docker compose up -d
```

L'application répond sur le `PORT` du fichier `.env` (8081 par défaut dans
cette configuration).

Le compose amont lance le serveur Angular avec 8 Go de tas Node. Sur une
machine de développement ordinaire, le noyau tue le conteneur sous la charge
d'une recompilation — et la page devient blanche sans la moindre erreur
applicative, ce qui rend la panne difficile à diagnostiquer.

`docker-compose.override.yml.example` ramène ce plafond à 3 Go, ce qui suffit
très largement. Copiez-le sans le suffixe et ajustez `mem_limit` à votre
machine ; le nom sans suffixe est ignoré par git, volontairement, parce que
ces plafonds ne se partagent pas.

```bash
cp docker-compose.override.yml.example docker-compose.override.yml
```

## Où placer les sources

Elles sont montées dans les conteneurs par un *bind mount*. Sous Windows,
gardez-les sur `C:` : Docker Desktop y partage nativement.

Un emplacement dans une distribution WSL demande en revanche que
l'intégration WSL soit activée pour cette distribution précise
(Docker Desktop → Settings → Resources → WSL Integration). Sans elle, le
démon reste joignable mais **ne partage aucun fichier** : les conteneurs
montent un dossier vide et échouent sur `Could not locate Gemfile`, sans que
rien n'indique la cause réelle.
