# frozen_string_literal: true

# Coquille applicative facon Plane.
#
# Plane n'a pas de bandeau superieur : tout vit dans la barre laterale, et le
# contenu occupe la surface restante. On applique cette logique a OpenProject
# sans rien supprimer — chaque element du bandeau est reloge :
#
#   gaufre (modules) + logo + utilisateur  -> en-tete de la laterale
#   recherche globale + ajout rapide (+)   -> bloc d'actions, sous l'en-tete
#   notifications + aide                   -> pied de la laterale
#
# Sur mobile, un bandeau compact subsiste : il porte le declencheur
# d'ouverture du menu, sans lequel la navigation serait inaccessible.
#
# Les methodes appelees ici (render_module_top_menu_node, render_quick_add_menu,
# render_notification_top_menu_node...) viennent de
# Redmine::MenuManager::TopMenuHelper. Certaines y sont privees, mais tous les
# helpers sont melanges dans le meme contexte de vue : l'appel a recepteur
# implicite fonctionne.
module PlaneShellHelper
  # Bandeau compact, mobile uniquement : bascule du menu + logo.
  def render_plane_mobile_bar
    tag.div(class: "op-plane-mobile-bar") do
      safe_join(
        [
          render(OpenProject::Common::MainMenuToggleComponent.new(expanded: false)),
          render_logo_icon
        ]
      )
    end
  end

  # En-tete de la laterale : gaufre des modules et logo.
  #
  # L'avatar n'est plus ici : il vit en haut a droite de l'ecran
  # (render_plane_user_corner). C'est la convention que tout le monde
  # connait pour les actions de compte, et la laterale y gagne de la place
  # pour ce qui releve vraiment de la navigation.
  def render_plane_sidebar_brand
    tag.div(class: "op-plane-sidebar--brand") do
      safe_join(
        [
          tag.div(render_module_top_menu_node, class: "op-plane-sidebar--brand-modules"),
          tag.div(render_logo, class: "op-plane-sidebar--brand-logo")
        ]
      )
    end
  end

  # Avatar et menu de compte, ancres en haut a droite de la fenetre.
  # Rendu une seule fois, hors de la laterale et hors du contenu, pour que
  # sa position ne depende d'aucune des deux.
  def render_plane_user_corner
    tag.div(render_user_top_menu_node, class: "op-plane-user-corner")
  end

  # Bloc d'actions : recherche globale, puis ajout rapide.
  # Ordre voulu — on cherche plus souvent qu'on ne cree.
  def render_plane_sidebar_actions
    tag.div(class: "op-plane-sidebar--actions") do
      safe_join(
        [
          tag.div(render_top_menu_search, class: "op-plane-sidebar--search"),
          tag.div(render_plane_quick_add, class: "op-plane-sidebar--quick-add")
        ].compact
      )
    end
  end

  # Menu « + » reconstruit. Voir layouts/_plane_quick_add pour la raison de
  # ne pas reutiliser Primer::Alpha::ActionMenu. On reprend en revanche ses
  # SOURCES : les memes items de menu et la meme liste de types de lots, donc
  # les memes destinations et les memes conditions d'affichage.
  def render_plane_quick_add
    return unless show_quick_add_menu?

    render partial: "layouts/plane_quick_add",
           locals: {
             items: first_level_menu_items_for(:quick_add_menu, @project),
             wp_items: work_package_quick_add_items || []
           }
  end

  # Pied de la laterale : notifications et aide. Acces moins frequents, donc
  # releges en bas — mais toujours a un clic, jamais masques derriere un menu.
  def render_plane_sidebar_footer
    tag.div(class: "op-plane-sidebar--footer") do
      safe_join(
        [
          render_notification_top_menu_node,
          render_help_top_menu_node,
          render_top_menu_teaser
        ].compact
      )
    end
  end
end
