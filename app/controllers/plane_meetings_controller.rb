# frozen_string_literal: true

# « Réunions » — page reconstruite.
#
# La liste d'origine est une table filtrable ou l'on choisit d'abord un
# filtre (a venir, passees, les miennes…) avant de voir quoi que ce soit.
# Une reunion se lit pourtant sur un axe unique : le temps.
#
# Cette page pose donc les reunions a venir en premier, groupees par jour,
# puis les dernieres passees. Aucun filtre a choisir pour voir la semaine.
# La liste filtrable reste a un clic pour tout le reste.
class PlaneMeetingsController < ApplicationController
  include Layout

  menu_item :plane_meetings

  before_action :require_login

  authorization_checked! :index

  PASSEES = 10

  def index
    base = Meeting.visible(current_user).not_templated.includes(:project, :author)

    @upcoming = base.upcoming.order(:start_time).limit(40).to_a
    @past = base.past.order(start_time: :desc).limit(PASSEES).to_a

    # Groupees par jour : c'est l'unite de lecture d'un agenda.
    @by_day = @upcoming.group_by { |meeting| meeting.start_time.to_date }.sort_by(&:first)
    @total = @upcoming.size

    render locals: { menu_name: :global_menu }
  end
end
