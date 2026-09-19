# frozen_string_literal: true

# « Accueil » — page d'atterrissage reconstruite.
#
# L'accueil d'origine est une grille de blocs configurables : liens vers la
# documentation, derniers projets, actualites. C'est une page d'accueil de
# produit, pas un point de depart de journee de travail.
#
#   accueil d'origine              cette page
#   ----------------------------   ----------------------------------------
#   blocs de presentation          ce qui m'attend aujourd'hui
#   derniers projets crees         mes projets favoris
#   liens documentaires            mes lots en retard, puis a echeance
#   aucune notion de « moi »       tout est filtre sur l'utilisateur
#
# L'accueil d'origine reste accessible : il porte les blocs personnalisables
# de l'instance, que cette page ne remplace pas.
class PlaneHomeController < ApplicationController
  include Layout

  menu_item :plane_home

  before_action :require_login

  authorization_checked! :index

  # Fenetre de « ce qui arrive » : au-dela, ce n'est plus de l'actualite.
  HORIZON = 14

  def index
    mine = WorkPackage
             .visible(current_user)
             .where(assigned_to_id: current_user.id)
             .joins(:status)
             .where(statuses: { is_closed: false })
             .includes(:status, :type, :priority, :project)

    @late = mine.where(due_date: ...Date.current).order(:due_date).limit(8).to_a
    @soon = mine.where(due_date: Date.current..(Date.current + HORIZON)).order(:due_date).limit(8).to_a
    @open_count = mine.count

    favorite_ids = Favorite.where(user: current_user, favorited_type: "Project").pluck(:favorited_id)
    @favorites = Project.visible(current_user).where(id: favorite_ids).order(:name).to_a

    # Sans favori, la page serait vide au premier usage : on montre alors
    # les projets ou l'utilisateur est membre, ce qui est le plus proche de
    # son intention.
    @favorites = Project.visible(current_user).with_member(current_user).order(:name).limit(6).to_a if @favorites.empty?

    @recent = WorkPackage
                .visible(current_user)
                .includes(:status, :type, :project)
                .order(updated_at: :desc)
                .limit(8)
                .to_a

    render locals: { menu_name: :global_menu }
  end
end
