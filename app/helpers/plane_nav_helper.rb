# frozen_string_literal: true

# Navigation de projet — reconstruite.
#
# Le menu d'OpenProject est une liste plate d'une vingtaine d'entrees, dans
# l'ordre ou les modules se sont enregistres. Rien ne dit ce qui sert tous
# les jours et ce qui sert deux fois par an, et les pages reconstruites s'y
# perdaient au milieu des anciennes.
#
# PARTI PRIS
# On ne code aucune URL en dur : on reprend les items d'OpenProject et on
# se contente de les REGROUPER et de les REORDONNER. Consequence — chaque
# lien reste valide, les permissions et les modules desactives sont
# respectes sans effort, et une entree ajoutee par un plugin inconnu
# atterrit dans la derniere section plutot que de disparaitre.
#
# Les trois pages reconstruites ouvrent la navigation. Leurs equivalents
# d'origine ne sont pas supprimes : ils descendent dans « Vues classiques »,
# repliee. Rien n'est perdu, l'acces devient simplement indirect.
module PlaneNavHelper
  # Chaque section : [libelle ou nil, [noms d'items, dans l'ordre voulu]]
  PLANE_NAV_SECTIONS = [
    [nil,                %i[plane_overview plane_work plane_gantt]],
    ["Planifier",        %i[boards calendar_view roadmap backlogs meetings team_planner_view]],
    ["Suivre",           %i[activity costs budgets]],
    ["Documenter",       %i[documents news forums]],
    ["Code",             %i[repository ifc_models]],
    ["Équipe",           %i[members resource_management]],
    ["Vues classiques",  %i[overview work_packages gantt]]
  ].freeze

  # Certains items portent un nom GENERE et ne peuvent donc pas figurer dans
  # la liste ci-dessus. Le wiki en est le cas type : ses entrees principales
  # s'appellent "wiki-<slug>", une par page racine — chercher :wiki ne
  # matchait jamais et le wiki tombait silencieusement dans « Autres ».
  # Les stockages externes suivent le meme schema ("storage_<id>").
  PLANE_NAV_PREFIXES = {
    "Documenter" => %w[wiki- storage_]
  }.freeze

  # Toujours en pied de colonne, separe du reste.
  PLANE_NAV_FOOTER = %i[settings].freeze

  # Depuis que /projects/:id sert l'Apercu reconstruit, l'entree d'origine
  # « Apercu » — qui se resout par controleur/action — pointerait elle aussi
  # sur la page reconstruite : « Vues classiques » aurait alors renvoye au
  # meme endroit que l'entree du haut, et la page d'origine serait devenue
  # introuvable. On redirige donc explicitement cette entree vers l'adresse
  # que la route lui a reservee.
  #
  # Le nom de cette route a change avec la bascule des adresses : l'apercu
  # d'origine vivait a /projects/:id/apercu-origine, il vit desormais sous
  # /legacy avec tous ses semblables — et le nom genere a suivi. Oublier de
  # le reporter ici faisait tomber toute page de projet en NoMethodError,
  # puisque la laterale est rendue par le gabarit de base.
  #
  # Meme traitement pour les deux autres entrees de « Vues classiques » :
  # elles se resolvent par controleur/action, donc vers les adresses
  # canoniques — c'est-a-dire vers les pages reconstruites. Sans cette
  # redirection, la section entiere renverrait sur elle-meme.
  # Dans un projet : l'aide prend le projet en argument.
  PLANE_LEGACY_PROJET = {
    overview: :legacy_project_overview_path,
    work_packages: :legacy_project_work_packages_path,
    gantt: :legacy_project_gantt_path
  }.freeze

  # Hors projet : l'aide ne prend rien.
  PLANE_LEGACY_GLOBAL = {
    home: :legacy_home_path,
    my_page: :legacy_my_page_path,
    my_time_tracking: :legacy_my_time_tracking_path,
    projects: :legacy_projects_path,
    work_packages: :legacy_work_packages_path,
    gantt: :legacy_gantt_path,
    boards: :legacy_boards_path,
    meetings: :legacy_meetings_path,
    news: :legacy_news_path,
    wikis: :legacy_wiki_pages_path,
    cost_reports_global: :legacy_cost_reports_path
  }.freeze

  def plane_node_url(node, url)
    if @project&.persisted?
      aide = PLANE_LEGACY_PROJET[node.name]
      aide ? public_send(aide, @project) : url
    else
      aide = PLANE_LEGACY_GLOBAL[node.name]
      aide ? public_send(aide) : url
    end
  end

  # ---------------------------------------------------------------------
  # Menu GLOBAL (hors projet). Meme grammaire que le menu projet, et
  # desormais les memes destinations : Projets, Travail et Frise pointent
  # vers les pages reconstruites en portee globale (PlaneScope), plus vers
  # les vues d'origine.
  #
  # Ces dernieres ne disparaissent pas pour autant. La table des lots et le
  # Gantt d'origine portent des capacites que la refonte n'a pas — filtres
  # sauvegardes, export, colonnes configurables : les retirer serait une
  # perte de fonctionnalite. Elles descendent dans « Vues classiques »,
  # repliee, exactement comme dans le menu projet.
  #
  # Les entrees Enterprise ne sont pas masquees ici, contrairement au menu
  # projet : « Portefeuilles » reste consultable sans licence — seule la
  # creation est bridee — et les masquer rendrait du contenu gratuit
  # introuvable. Elles descendent aussi dans un bloc replie.
  # ---------------------------------------------------------------------
  # Le Calendrier reste en vue directe bien qu'il ne soit pas reconstruit :
  # ce n'est pas le doublon d'une page refaite, c'est une capacite a part
  # entiere et gratuite. Seuls descendent dans « Vues classiques » les
  # ecrans que la refonte remplace effectivement.
  PLANE_GLOBAL_SECTIONS = [
    [nil,               %i[plane_home plane_my plane_time]],
    ["Travailler",      %i[plane_projects plane_work plane_gantt plane_boards calendar_view]],
    ["Collaborer",      %i[plane_meetings plane_news plane_wiki]],
    ["Suivre",          %i[plane_costs activity]],
    ["Vues classiques", %i[home my_page my_time_tracking projects work_packages gantt
                           boards meetings news wikis cost_reports_global]],
    ["Enterprise",      %i[portfolios team_planners]]
  ].freeze

  # Sections rendues repliees : on les garde accessibles sans qu'elles
  # occupent la colonne.
  PLANE_GLOBAL_FOLDED = ["Vues classiques", "Enterprise", "Autres"].freeze

  def plane_global_sections
    nodes = first_level_menu_items_for(:global_menu, nil).index_by(&:name)
    placed = Set.new

    sections = PLANE_GLOBAL_SECTIONS.filter_map do |label, names|
      picked = names.filter_map { |name| nodes[name] }
      picked.each { |n| placed << n.name }
      [label, picked] if picked.any?
    end

    leftovers = nodes.values.reject { |n| placed.include?(n.name) }
    sections << ["Autres", leftovers] if leftovers.any?

    sections
  end

  # Sections rendues repliees dans la colonne de projet.
  PLANE_NAV_FOLDED = ["Vues classiques", "Enterprise", "Autres"].freeze

  # Retourne [[libelle, [noeuds]], ...] pour la colonne principale.
  def plane_nav_sections(project)
    nodes = plane_nav_nodes(project)
    placed = Set.new

    # Les entrees Enterprise non activees sont mises de cote AVANT le
    # rangement thematique : sinon « Planificateur d'equipe » atterrirait
    # dans « Planifier », au milieu des destinations reelles, alors que son
    # seul contenu est une page de vente.
    upsell = nodes.values.select { |n| enterprise_upsell_node?(n) }
    upsell.each { |n| placed << n.name }

    sections = PLANE_NAV_SECTIONS.filter_map do |label, names|
      picked = names.filter_map { |name| nodes[name] }.reject { |n| placed.include?(n.name) }
      picked += plane_nav_by_prefix(nodes, label, placed)
      picked.each { |n| placed << n.name }
      [label, picked] if picked.any?
    end

    # Filet de securite : tout item non prevu ci-dessus reste accessible.
    # Un plugin tiers ne doit jamais disparaitre parce qu'on ne le
    # connaissait pas au moment d'ecrire cette liste.
    leftovers = nodes.values.reject { |n| placed.include?(n.name) || PLANE_NAV_FOOTER.include?(n.name) }
    sections << ["Autres", leftovers] if leftovers.any?

    # Repliee, en bas : hors de la vue directe, mais joignable. Les masquer
    # tout a fait rendait ces pages introuvables depuis un projet.
    sections << ["Enterprise", upsell] if upsell.any?

    sections
  end

  def plane_nav_footer(project)
    nodes = plane_nav_nodes(project)
    PLANE_NAV_FOOTER.filter_map { |name| nodes[name] }
  end

  private

  # Items dont le nom est genere : on les rattache par prefixe.
  def plane_nav_by_prefix(nodes, label, placed)
    prefixes = PLANE_NAV_PREFIXES[label]
    return [] if prefixes.blank?

    nodes.values.select do |node|
      !placed.include?(node.name) && prefixes.any? { |p| node.name.to_s.start_with?(p) }
    end
  end

  # Items visibles pour cet utilisateur et ce projet, indexes par nom.
  # first_level_menu_items_for applique deja les permissions, les conditions
  # et le filtrage des fonctionnalites Enterprise non activees.
  #
  # build_wiki_menus est INDISPENSABLE : les entrees du wiki ne sont pas
  # declarees dans l'initialiseur, elles sont construites a la volee a
  # partir des pages du projet. render_main_menu l'appelle avant de rendre ;
  # en le court-circuitant, on perdait purement et simplement le Wiki.
  def plane_nav_nodes(project)
    @plane_nav_nodes ||= begin
      build_wiki_menus(project) if project&.persisted?
      first_level_menu_items_for(:project_menu, project).index_by(&:name)
    end
  end
end
