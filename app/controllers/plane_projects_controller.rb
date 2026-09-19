# frozen_string_literal: true

# « Projets » — page reconstruite, portee globale.
#
# La liste d'origine est un tableau de requete : colonnes configurables,
# filtres, tri, export. C'est un outil d'analyse, et il reste disponible
# (« Vues classiques » dans la navigation). Mais ce n'est pas ce qu'on
# cherche neuf fois sur dix en cliquant « Projets » : on cherche a ENTRER
# dans un projet.
#
#   tableau d'origine              cette page
#   ---------------------------    ----------------------------------------
#   lignes et colonnes             cartes, une par projet
#   identifiant, colonnes techn.   nom, description, avancement, equipe
#   tri unique sur une colonne     favoris d'abord, puis ordre hierarchique
#   etat du projet = une colonne   etat = une pastille sur la carte
#
# Aucune capacite n'est retiree : la page expose un lien direct vers la
# liste filtrable pour tout ce qui releve de l'analyse.
class PlaneProjectsController < ApplicationController
  include Layout

  menu_item :plane_projects

  before_action :require_login

  authorization_checked! :index

  def index
    visible = Project
                .visible(current_user)
                .order(Arel.sql("lft"))
                .to_a

    favorite_ids = Favorite.where(user: current_user, favorited_type: "Project").pluck(:favorited_id).to_set
    @counts = open_work_package_counts(visible.map(&:id))

    @favorites, @others = visible.partition { |project| favorite_ids.include?(project.id) }
    @total = visible.size

    # Les projets archives restent joignables : ils ne sont pas dans
    # Project.visible, et sans ce bloc la page aurait fait disparaitre du
    # contenu que la liste d'origine montrait.
    @archived = Project.archived.select { |project| current_user.allowed_in_project?(:view_project, project) }

    render locals: { menu_name: :global_menu }
  end

  private

  # Un compte par projet en une requete : boucler sur les projets aurait
  # produit une requete par carte.
  def open_work_package_counts(project_ids)
    WorkPackage
      .visible(current_user)
      .where(project_id: project_ids)
      .joins(:status)
      .where(statuses: { is_closed: false })
      .group(:project_id)
      .count
  end
end
