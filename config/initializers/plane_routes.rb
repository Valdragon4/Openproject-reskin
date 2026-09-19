# frozen_string_literal: true

# Les pages reconstruites prennent les adresses CANONIQUES, les pages
# d'origine passent sous /legacy.
#
# POURQUOI CE FICHIER ET PAS config/routes.rb
# Les modules d'OpenProject dessinent leurs routes AVANT le fichier de
# l'application : une declaration placee la-bas, meme en premiere ligne,
# arrive trop tard et perd face au module. `routes.prepend` place au
# contraire le bloc en tete du jeu de routes final, quel que soit l'ordre de
# chargement.

# Faut-il laisser passer la requete vers la page d'ORIGINE ?
#
# /work_packages, /gantt et /projects ne servent pas qu'un index : avec
# ?query_id= ou ?query_props=, ils servent une VUE ENREGISTREE. Ce sont les
# sous-entrees du menu — « Tous les elements ouverts », « En retard »,
# « Mes projets »… Reprendre l'adresse sans regarder ces parametres les
# aurait toutes cassees, en silence : l'utilisateur aurait vu la page
# reconstruite au lieu de sa vue, sans aucune erreur.
#
# La page reconstruite ne repond donc que sur l'adresse NUE. Des qu'un
# parametre de vue est present, la requete continue son chemin jusqu'au
# controleur d'origine.
PLANE_VUE_ENREGISTREE = %w[query_id query_props name work_package_default
                           filters columns sortBy groupBy timelineVisible].freeze

PLANE_ADRESSE_NUE = lambda do |request|
  PLANE_VUE_ENREGISTREE.none? { |cle| request.params.key?(cle) }
end

Rails.application.routes.prepend do
  # ------------------------------------------------------------ PORTEE PROJET
  constraints(Constraints::ProjectIdentifier) do
    scope "projects/:project_id", as: "project" do
      # La racine d'un projet : c'est la qu'arrivent le selecteur de projet,
      # la recherche, les fils d'Ariane et les notifications.
      get "/", to: "plane_overview#index", as: :plane_home

      constraints(PLANE_ADRESSE_NUE) do
        get "work_packages", to: "plane_work#index", as: :plane_work_canonical
        get "gantt", to: "plane_gantt#index", as: :plane_gantt_canonical
      end
    end

    # Les pages d'origine du projet, a une adresse explicite.
    scope "legacy/projects/:project_id", as: "legacy_project" do
      get "/", to: "overviews/overviews#show", as: :overview
      get "work_packages", to: "work_packages#index", as: :work_packages
      get "gantt", to: "gantt/gantt#index", as: :gantt
    end
  end

  # --------------------------------------------------------- PORTEE GLOBALE
  get "/", to: "plane_home#index", as: :plane_accueil

  constraints(PLANE_ADRESSE_NUE) do
    get "work_packages", to: "plane_work#index", as: :plane_work_global
    get "gantt", to: "plane_gantt#index", as: :plane_gantt_global
    get "projects", to: "plane_projects#index", as: :plane_projects_global
    get "boards", to: "plane_boards#index", as: :plane_boards_global
    get "meetings", to: "plane_meetings#index", as: :plane_meetings_global
    get "news", to: "plane_news#index", as: :plane_news_global
    get "wiki_pages", to: "plane_wiki#index", as: :plane_wiki_global
    get "cost_reports", to: "plane_costs#index", as: :plane_costs_global
    get "my/page", to: "plane_my#index", as: :plane_my_global
    get "my/time-tracking", to: "plane_time#index", as: :plane_time_global
  end

  # Les pages d'origine, a une adresse explicite.
  #
  # Ce sont les MEMES controleurs : on ne duplique rien, on ajoute une
  # seconde porte. Leurs liens internes continuent de pointer vers les
  # adresses canoniques — c'est-a-dire vers les pages reconstruites — ce qui
  # est voulu : /legacy sert a consulter une page d'origine, pas a naviguer
  # durablement dans l'ancienne interface.
  scope "legacy", as: "legacy" do
    get "/", to: "homescreen#index", as: :home
    get "work_packages", to: "work_packages#index", as: :work_packages
    get "gantt", to: "gantt/gantt#index", as: :gantt
    get "projects", to: "projects#index", as: :projects
    get "boards", to: "boards/boards#index", as: :boards
    get "meetings", to: "meetings#index", as: :meetings
    get "news", to: "news#index", as: :news
    get "wiki_pages", to: "wikis/wiki_pages#index", as: :wiki_pages
    get "cost_reports", to: "cost_reports#index", as: :cost_reports
    get "my/page", to: "my/page#show", as: :my_page
    get "my/time-tracking", to: "my/time_tracking#index", as: :my_time_tracking
  end
end
