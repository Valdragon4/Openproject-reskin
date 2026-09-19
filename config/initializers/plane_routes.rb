# frozen_string_literal: true

# Racine d'un projet : /projects/:id
#
# C'est l'adresse ou menent le selecteur de projet, la recherche, les fils
# d'Ariane et les notifications — la majorite des chemins vers un projet.
# Le module overviews la revendique (`resource :overview, path: "/"`) :
# tant qu'on ne la reprend pas, on retombe sur l'Apercu d'origine quelle
# que soit la laterale affichee. C'est ce qui donnait une navigation
# reconstruite posee au-dessus d'une page d'origine.
#
# POURQUOI ICI ET PAS DANS config/routes.rb
# Les modules d'OpenProject dessinent leurs routes AVANT le fichier de
# l'application : une declaration placee la-bas, meme en premiere ligne,
# arrive trop tard et perd face au module. `routes.prepend` place au
# contraire le bloc en tete du jeu de routes final, quelle que soit
# l'ordre de chargement.
#
# L'Apercu d'origine n'est pas perdu : il garde une adresse explicite, vers
# laquelle pointe l'entree « Vues classiques » (voir PlaneNavHelper#plane_node_url).
Rails.application.routes.prepend do
  constraints(Constraints::ProjectIdentifier) do
    scope "projects/:project_id", as: "project" do
      get "/", to: "plane_overview#index", as: :plane_home
      get "apercu-origine", to: "overviews/overviews#show", as: :classic_overview
    end
  end
end
