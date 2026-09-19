# frozen_string_literal: true

# « Actualités » — page reconstruite.
#
# La liste d'origine affiche le titre et le resume, sans jamais dire de quel
# projet vient l'annonce tant qu'on n'a pas clique. Sur une instance a sept
# projets, c'est l'information la plus utile.
#
# Cette page groupe par mois — une annonce se situe d'abord dans le temps —
# et porte la provenance sur chaque ligne.
class PlaneNewsController < ApplicationController
  include Layout

  menu_item :plane_news

  before_action :require_login

  authorization_checked! :index

  LIMITE = 60

  def index
    news = News
             .visible(current_user)
             .includes(:project, :author)
             .order(created_at: :desc)
             .limit(LIMITE)
             .to_a

    @total = news.size
    @by_month = news.group_by { |item| item.created_at.to_date.beginning_of_month }
                    .sort_by { |month, _| month }
                    .reverse

    render locals: { menu_name: :global_menu }
  end
end
