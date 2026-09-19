# frozen_string_literal: true

# « Mon temps » — reconstruction du suivi du temps personnel.
#
# La page d'origine affiche un jour a la fois. Or on ne saisit pas son temps
# au jour le jour : on le complete en fin de semaine, et la question posee
# est « ou sont mes trous ? ». Une vue jour ne peut pas y repondre.
#
# Cette page affiche donc la SEMAINE, jour par jour, avec le total de chaque
# jour et les jours vides rendus visibles. La saisie et l'edition restent
# celles d'OpenProject : on ne reimplemente pas un formulaire de temps, on
# change la facon de lire.
class PlaneTimeController < ApplicationController
  include Layout

  menu_item :plane_time

  before_action :require_login

  authorization_checked! :index

  def index
    @week_start = parse_week
    @week_end = @week_start + 6

    entries = TimeEntry
                .where(user_id: current_user.id, spent_on: @week_start..@week_end)
                .includes(:project, :activity, :entity)
                .order(:spent_on, :created_at)
                .to_a

    grouped = entries.group_by(&:spent_on)

    # Un jour sans saisie doit apparaitre : c'est precisement ce qu'on vient
    # chercher. Construire la semaine complete plutot que d'iterer sur les
    # entrees existantes.
    @days = (@week_start..@week_end).map do |day|
      day_entries = grouped[day] || []
      { date: day, entries: day_entries, hours: day_entries.sum(&:hours).to_f }
    end

    @total = @days.sum { |d| d[:hours] }
    @by_project = entries.group_by { |e| e.project&.name || "Sans projet" }
                         .transform_values { |list| list.sum(&:hours).to_f }
                         .sort_by { |_, h| -h }

    render locals: { menu_name: :global_menu }
  end

  private

  # Une date quelconque suffit a designer une semaine : on la ramene a son
  # lundi. Une valeur illisible retombe sur la semaine courante plutot que
  # de lever — un parametre d'URL malforme ne doit pas casser la page.
  def parse_week
    brut = params[:semaine].to_s
    return Date.current.beginning_of_week if brut.blank?

    # Date::Error n'est pas rattrape par `rescue ArgumentError` dans ce
    # contexte : la page tombait en 500 sur un parametre vide. On le nomme.
    Date.parse(brut).beginning_of_week
  rescue Date::Error, ArgumentError, TypeError
    Date.current.beginning_of_week
  end
end
