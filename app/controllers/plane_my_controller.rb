# frozen_string_literal: true

# « Mon travail » — reconstruction de « Ma page ».
#
# « Ma page » d'origine est une grille de widgets que chacun compose. Sa
# souplesse a un cout : la page est vide tant qu'on ne l'a pas montee, et
# deux utilisateurs n'y voient pas la meme chose.
#
# Cette page repond a une question fixe — « qu'est-ce qui m'attend ? » — et
# y repond immediatement, sans configuration. « Ma page » reste disponible
# pour qui veut composer la sienne : les deux ne s'excluent pas.
class PlaneMyController < ApplicationController
  include Layout

  menu_item :plane_my

  before_action :require_login

  authorization_checked! :index

  def index
    visible = WorkPackage.visible(current_user).includes(:status, :type, :priority, :project)
    ouverts = visible.joins(:status).where(statuses: { is_closed: false })

    @assigned = ouverts.where(assigned_to_id: current_user.id).order(Arel.sql("due_date ASC NULLS LAST")).to_a
    @authored = ouverts.where(author_id: current_user.id).order(updated_at: :desc).limit(20).to_a
    @accountable = ouverts.where(responsible_id: current_user.id).order(Arel.sql("due_date ASC NULLS LAST")).to_a

    @late = @assigned.select { |wp| wp.due_date && wp.due_date < Date.current }

    # Heures posees sur la semaine en cours : le seul chiffre que « Ma page »
    # ne donnait pas et qu'on cherche pourtant tous les vendredis.
    @week_hours = TimeEntry
                    .where(user_id: current_user.id,
                           spent_on: Date.current.beginning_of_week..Date.current.end_of_week)
                    .sum(:hours)

    render locals: { menu_name: :global_menu }
  end
end
