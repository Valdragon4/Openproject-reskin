# frozen_string_literal: true

# « Wiki » — index transverse reconstruit.
#
# L'entree globale d'origine ouvre une liste de requete sur les pages de
# wiki : des lignes, un filtre, aucune structure. Or un wiki EST une
# structure — des pages racines, et ce qui pend dessous.
#
# Cette page rend donc, par projet, l'arbre des pages, replie au dela du
# premier niveau. La liste filtrable d'origine reste accessible : elle sert
# la recherche, pas la navigation.
class PlaneWikiController < ApplicationController
  include Layout

  menu_item :plane_wiki

  before_action :require_login

  authorization_checked! :index

  def index
    pages = WikiPage
              .visible(current_user)
              .includes(:wiki, :project)
              .order(:title)
              .to_a

    @total = pages.size

    # Un arbre par projet. Les enfants sont indexes par parent_id une fois
    # pour toutes : remonter la hierarchie page par page aurait produit une
    # requete par noeud.
    @trees = pages
               .group_by(&:project)
               .compact
               .sort_by { |project, _| project.name.to_s }
               .map do |project, project_pages|
                 by_parent = project_pages.group_by(&:parent_id)
                 [project, by_parent[nil].to_a.sort_by { |p| p.title.to_s }, by_parent]
               end

    render locals: { menu_name: :global_menu }
  end
end
