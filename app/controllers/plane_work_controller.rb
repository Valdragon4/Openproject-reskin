# frozen_string_literal: true

# Vue « Travail » — page reconstruite, facon Plane.
#
# Ce n'est pas un restylage de la table des lots de travaux : c'est une autre
# page, avec une autre organisation de l'information.
#
#   table OpenProject            cette page
#   ------------------           -------------------------------------------
#   colonnes fixes               pas de colonnes : une ligne = un element
#   tri global unique            regroupement par statut, sections repliables
#   en-tete de colonnes          en-tete de section avec compteur
#   creation en haut de page     creation au pied de chaque groupe
#   densite d'un tableur         densite d'une liste, lisible en diagonale
#
# Deux portees, une seule page : dans un projet, et hors projet (tous les
# projets visibles) — voir PlaneScope. La table d'origine reste accessible et
# inchangee : cette vue s'ajoute, elle ne remplace rien.
class PlaneWorkController < ApplicationController
  # Sans ce module et sans menu_name ci-dessous, la coquille rend le menu
  # GLOBAL au lieu du menu projet : la page s'affichait avec « Accueil / Ma
  # page / Projets » dans la laterale, et l'entree Travail restait invisible.
  include Layout
  include PlaneScope

  menu_item :plane_work

  # OpenProject refuse toute action dont l'autorisation n'est pas declaree
  # par son propre framework. Le controle est bien fait par PlaneScope ; on
  # l'affirme explicitement.
  authorization_checked! :index

  def index
    work_packages = plane_work_packages.to_a
    @total = work_packages.size

    # Les statuts ouverts d'abord, dans l'ordre defini par l'instance ; les
    # statuts fermes ferment la marche. Ce qui reste a faire se lit en haut.
    @groups = work_packages
                .group_by(&:status)
                .sort_by { |status, _| [status&.is_closed? ? 1 : 0, status&.position || 0, status&.name.to_s] }

    render locals: { menu_name: project_or_global_menu }
  end
end
