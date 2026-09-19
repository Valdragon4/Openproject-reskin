# frozen_string_literal: true

# Portee d'une page reconstruite : un projet, ou tous.
#
# Les pages Travail et Frise n'existaient que sous /projects/:id. Le menu
# global continuait donc de pointer vers les vues d'origine, et la refonte
# s'arretait a la frontiere du projet.
#
# Or une page reconstruite n'a pas besoin d'un projet : elle a besoin d'un
# ENSEMBLE de lots de travaux. Ce module fournit cet ensemble dans les deux
# cas et laisse la vue s'adapter — hors projet, chaque ligne porte le nom de
# son projet, puisque c'est l'information qui manque alors pour se reperer.
module PlaneScope
  extend ActiveSupport::Concern

  included do
    before_action :load_plane_project
    before_action :authorize_plane_view

    helper_method :plane_global?
  end

  # Hors projet, la vue affiche la provenance de chaque lot.
  def plane_global?
    @project.nil?
  end

  private

  # params[:project_id] absent = portee globale. Un identifiant present mais
  # inconnu reste une erreur : on ne bascule pas silencieusement sur « tous
  # les projets » parce qu'une URL est fausse.
  def load_plane_project
    return @project = nil if params[:project_id].blank?

    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # .visible(current_user) filtre deja projet par projet : hors projet, on
  # obtient exactement les lots des projets ou l'utilisateur a le droit de
  # les voir, sans avoir a lister ces projets nous-memes.
  def plane_work_packages
    scope = WorkPackage
              .visible(current_user)
              .includes(:status, :type, :assigned_to, :priority, :project)

    @project ? scope.where(project_id: @project.id) : scope
  end

  def authorize_plane_view
    allowed = if @project
                current_user.allowed_in_project?(:view_work_packages, @project)
              else
                current_user.allowed_in_any_project?(:view_work_packages)
              end

    render_403 unless allowed
  end
end
