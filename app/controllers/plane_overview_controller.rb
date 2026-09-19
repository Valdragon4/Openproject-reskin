# frozen_string_literal: true

# Aperçu projet — page reconstruite, facon Plane.
#
# L'aperçu d'OpenProject est une grille de widgets configurables : puissante,
# mais elle ne repond a aucune question precise. On y trouve une description,
# un statut, une frise, des reunions, des sous-elements — cote a cote, au
# meme poids visuel.
#
# Cette page repond a une question unique : OU EN EST CE PROJET ?
#   une ligne de chiffres qui se lit en deux secondes
#   une barre d'avancement reelle, calculee sur les lots fermes
#   ce qui est en retard, mis en avant parce que c'est ce qui appelle une action
#   la repartition par statut, en proportions
#   l'equipe, parce qu'un projet est fait de gens
#
# SQUELETTE D'UN CONTROLEUR DE PAGE GREFFEE (quatre conventions OpenProject,
# chacune obligatoire, aucune evidente) :
#   include Layout                              -> sinon menu global au lieu du menu projet
#   authorization_checked! :action              -> sinon refus du framework, erreur 500
#   render locals: { menu_name: ... }           -> idem, choix du menu
#   entree de menu avec if: ->(project) { ... } -> sinon la page d'accueil globale casse
class PlaneOverviewController < ApplicationController
  include Layout

  menu_item :plane_overview

  before_action :load_project
  before_action :authorize_view

  authorization_checked! :index

  def index
    work_packages = WorkPackage
                      .visible(current_user)
                      .where(project_id: @project.id)
                      .includes(:status, :type, :assigned_to)
                      .to_a

    @total = work_packages.size
    @closed = work_packages.count { |wp| wp.status&.is_closed? }
    @open = @total - @closed
    @overdue = work_packages.count do |wp|
      wp.due_date.present? && wp.due_date < Date.current && !wp.status&.is_closed?
    end

    @progress = @total.zero? ? 0 : ((@closed.to_f / @total) * 100).round

    # Repartition par statut, ouverts d'abord, la plus grosse part en tete.
    @by_status = work_packages
                   .group_by(&:status)
                   .map { |status, items| [status, items.size] }
                   .sort_by { |status, count| [status&.is_closed? ? 1 : 0, -count] }

    # Les retards sont ce qui appelle une action : on les sort en clair.
    @late = work_packages
              .select { |wp| wp.due_date.present? && wp.due_date < Date.current && !wp.status&.is_closed? }
              .sort_by(&:due_date)
              .first(6)

    @members = @project.users.limit(12).to_a

    render locals: { menu_name: project_or_global_menu }
  end

  private

  def load_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize_view
    return if current_user.allowed_in_project?(:view_project, @project)

    render_403
  end
end
