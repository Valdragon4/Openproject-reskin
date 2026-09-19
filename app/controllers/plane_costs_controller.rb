# frozen_string_literal: true

# « Temps et coûts » — synthese reconstruite.
#
# PORTEE, ANNONCEE FRANCHEMENT
# Le generateur de rapports d'origine (groupements libres, colonnes, export,
# rapports enregistres) n'est pas remplace : c'est un outil d'analyse a part
# entiere, et il reste accessible depuis cette page. Ce qu'on reconstruit,
# c'est la REPONSE IMMEDIATE : combien d'heures, ou, par qui, sur la
# periode recente — ce qu'on cherche neuf fois sur dix avant d'ouvrir un
# rapport.
class PlaneCostsController < ApplicationController
  include Layout

  menu_item :plane_costs

  before_action :require_login

  authorization_checked! :index

  PERIODES = { "30" => 30, "90" => 90, "365" => 365 }.freeze
  DEFAUT = "30"

  def index
    @periode = PERIODES.key?(params[:periode]) ? params[:periode] : DEFAUT
    @depuis = Date.current - PERIODES.fetch(@periode)

    entries = TimeEntry
                .where(project_id: visible_project_ids, spent_on: @depuis..Date.current)
                .includes(:project, :user, :activity)
                .to_a

    @total = entries.sum(&:hours).to_f
    @entries_count = entries.size
    @by_project = totaux(entries) { |e| e.project&.name || "Sans projet" }
    @by_user = totaux(entries) { |e| e.user&.name || "Inconnu" }
    @by_activity = totaux(entries) { |e| e.activity&.name || "Sans activité" }

    render locals: { menu_name: :global_menu }
  end

  private

  # On ne s'appuie pas sur une portee « visible » de TimeEntry : le droit de
  # voir les temps est accorde projet par projet, et deux permissions
  # distinctes existent (les siens / ceux de tous). On part donc des projets
  # ou l'utilisateur a explicitement ce droit.
  def visible_project_ids
    Project.visible(current_user)
           .select { |project| current_user.allowed_in_project?(:view_time_entries, project) }
           .map(&:id)
  end

  def totaux(entries)
    entries.group_by { |e| yield(e) }
           .transform_values { |list| list.sum(&:hours).to_f }
           .sort_by { |_, hours| -hours }
           .first(10)
  end
end
