# frozen_string_literal: true

# « Tableaux » — index reconstruit.
#
# PORTEE, ANNONCEE FRANCHEMENT
# Le tableau lui-meme — colonnes, glisser-deposer, mise a jour en direct —
# reste celui d'OpenProject. C'est un composant Angular avec de l'etat
# temps reel ; le reecrire serait un projet en soi, et le faire a moitie
# ferait perdre des fonctions. Cette page ne reconstruit donc que l'INDEX :
# la ou l'entree « Tableaux » du menu global ouvrait une liste par projet,
# elle ouvre maintenant la vue d'ensemble de tous les tableaux visibles,
# groupes par projet, avec leur type.
class PlaneBoardsController < ApplicationController
  include Layout

  menu_item :plane_boards

  before_action :require_login

  authorization_checked! :index

  def index
    projects = Project
                 .visible(current_user)
                 .has_module(:board_view)
                 .select { |project| current_user.allowed_in_project?(:show_board_views, project) }

    boards = Boards::Grid.where(project_id: projects.map(&:id)).includes(:project).order(:name).to_a

    @groups = boards.group_by(&:project).sort_by { |project, _| project.name.to_s }
    @total = boards.size

    render locals: { menu_name: :global_menu }
  end
end
