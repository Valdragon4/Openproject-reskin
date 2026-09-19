# frozen_string_literal: true

# Frise (Gantt) — page construite de zero.
#
# Ce n'est pas le composant timeline d'OpenProject restyle : c'est un autre
# rendu, avec un autre modele de mise en page.
#
#   OpenProject                        ici
#   --------------------------------   ------------------------------------
#   deux panneaux a synchroniser       un seul conteneur de defilement
#   barres en position absolue (px)    grille CSS, grid-column: debut / span
#   etiquettes satellites autour       le libelle vit DANS la barre
#   grille d'un trait par jour         bandes de mois, week-ends teintes
#   en-tete a trois rangees egales     mois dominant, jours en retrait
#
# Le calcul de l'echelle se fait ici, cote serveur : la vue ne fait que
# poser des index de colonnes. Aucun JavaScript n'est necessaire pour le
# rendu — seulement pour le confort (defilement jusqu'a aujourd'hui).
class PlaneGanttController < ApplicationController
  include Layout
  include PlaneScope

  menu_item :plane_gantt

  authorization_checked! :index

  # Largeur d'une colonne-jour, en pixels, par niveau de zoom.
  ZOOM = { "jours" => 30, "semaines" => 14, "mois" => 6 }.freeze
  DEFAULT_ZOOM = "semaines"

  # Geometrie du corps. Ces valeurs sont partagees avec la feuille de style :
  # les tracés de dependance sont calcules ici, en pixels, et doivent tomber
  # exactement sur les barres.
  ROW_H = 44
  GROUP_H = 34
  BAR_H = 26

  # Plafond du nombre de colonnes-jour rendues.
  #
  # Rien n'empeche de demander « 1990 -> 2040 » dans les champs de date. Ce
  # sont alors ~18 000 pistes de grille CSS, autant de cellules d'en-tete, et
  # un viewBox SVG de 18 000 unites : le navigateur met plusieurs secondes a
  # poser la page, pour une frise ou une barre mesure un tiers de pixel et
  # n'apprend rien. On tronque la fenetre et on le DIT a l'ecran — tronquer
  # en silence ferait croire que les donnees manquent.
  #
  # Le plafond ne depend pas du zoom : c'est le nombre de PISTES qui coute,
  # pas leur largeur. 1100 jours, soit trois ans, couvrent tous les usages
  # de lecture reels.
  MAX_DAYS = 1100

  def index
    @zoom = ZOOM.key?(params[:zoom]) ? params[:zoom] : DEFAULT_ZOOM
    @day_width = ZOOM.fetch(@zoom)

    read_window

    work_packages = plane_work_packages
                      .to_a
                      .select { |wp| wp.start_date.present? || wp.due_date.present? }

    # Aucune donnee ET aucune fenetre demandee : il n'y a rien a situer dans
    # le temps, on s'arrete avant de fabriquer une echelle vide.
    if work_packages.empty? && !@custom_range
      @groups = []
      return render locals: { menu_name: project_or_global_menu }
    end

    build_range(work_packages)

    # Les lots hors fenetre sont ECARTES, pas seulement rognes.
    # plane_gantt_span borne ses index a [1, @days.size] : un lot situe deux
    # ans plus tot serait donc dessine comme une barre d'un jour collee au
    # bord gauche — une date inventee. Un lot ne s'affiche que s'il recouvre
    # reellement la fenetre.
    visible = work_packages.select { |wp| overlaps_range?(wp) }

    @today_index = @days.index(Date.current)

    # Bandes de mois : une cellule par mois, dont la portee est son nombre
    # de jours DANS la fenetre (les mois de bord sont donc partiels).
    @months = @days.group_by { |d| [d.year, d.month] }.map do |(year, month), days|
      { label: I18n.l(Date.new(year, month, 1), format: "%b %Y"), span: days.size }
    end

    # Regroupement par statut, ouverts d'abord : meme logique que la vue
    # Travail, pour que les deux pages se lisent de la meme facon.
    @groups = visible
                .group_by(&:status)
                .sort_by { |status, _| [status&.is_closed? ? 1 : 0, status&.position || 0, status&.name.to_s] }
                .map { |status, items| [status, items.sort_by { |wp| wp.start_date || wp.due_date }] }

    build_layout
    build_links(visible)

    render locals: { menu_name: project_or_global_menu }
  end

  # Index de colonne (base 1) et portee d'un lot, bornes a la fenetre.
  helper_method :plane_gantt_span
  def plane_gantt_span(work_package)
    from = work_package.start_date || work_package.due_date
    to   = work_package.due_date   || work_package.start_date
    from, to = to, from if from > to

    col  = (from - @range_start).to_i + 1
    span = (to - from).to_i + 1
    [col.clamp(1, @days.size), span.clamp(1, @days.size - col + 1)]
  end

  # Etat temporel : ce qu'on lit vraiment sur une frise.
  helper_method :plane_gantt_state
  def plane_gantt_state(work_package)
    return "closed" if work_package.status&.is_closed?

    due   = work_package.due_date
    start = work_package.start_date
    return "overdue"  if due.present? && due < Date.current
    return "upcoming" if start.present? && start > Date.current

    "active"
  end

  # Options d'URL d'un deplacement dans le temps.
  #
  # Le zoom est TOUJOURS reconduit : sans cela chaque fleche, chaque
  # raccourci et chaque « Aujourd'hui » ramenerait la frise a l'echelle par
  # defaut, et l'utilisateur perdrait son reglage a chaque clic.
  # from et to a nil = pas de parametre = retour a la fenetre deduite.
  helper_method :plane_gantt_window_options
  def plane_gantt_window_options(from: nil, to: nil)
    options = { zoom: @zoom }
    options[:from] = from.strftime("%Y-%m-%d") if from
    options[:to]   = to.strftime("%Y-%m-%d") if to
    options
  end

  private

  # ------------------------------------------------------------ La fenetre
  #
  # CHOIX DE CONCEPTION — le deplacement est fait COTE SERVEUR.
  #
  # Tout le reste de cette page est calcule ici : le nombre de colonnes, la
  # position de chaque barre, et surtout les tracés de dependance, qui sont
  # emis en dur dans le SVG a partir de @pos. Deplacer la fenetre cote
  # client voudrait dire recalculer cette geometrie en JavaScript — soit une
  # seconde implementation de la meme chose, qui derivera.
  #
  # Un defilement cote client ne pourrait de toute facon montrer que ce qui
  # est DEJA rendu : il ne sait pas reveler un lot situe hors de la fenetre.
  # Le seul cas qu'il traiterait mieux (« Aujourd'hui » quand aujourd'hui est
  # deja visible) ne justifie pas d'introduire du JavaScript sur une page qui
  # n'en a aucun.
  #
  # En echange, l'URL porte l'etat complet : une periode se partage, se met
  # en favori, et le bouton Precedent du navigateur remonte l'historique de
  # navigation temporelle. Le defilement natif de .op-gantt--scroll reste
  # disponible pour l'ajustement fin a l'interieur de la fenetre.
  def read_window
    @window_from = plane_gantt_date_param(params[:from])
    @window_to   = plane_gantt_date_param(params[:to])

    # Fin avant debut : on echange les bornes au lieu de rendre une fenetre
    # vide. L'utilisateur a visiblement saisi les deux champs a l'envers ;
    # lui renvoyer une page cassee ne l'aide pas a s'en apercevoir.
    if @window_from && @window_to && @window_to < @window_from
      @window_from, @window_to = @window_to, @window_from
      @window_swapped = true
    end

    @custom_range = @window_from.present? || @window_to.present?
  end

  # Lecture d'une borne de date venue de l'URL.
  #
  # PIEGE — `Date.parse("")` et `Date.iso8601("nimporte quoi")` levent
  # Date::Error. Date::Error descend bien d'ArgumentError, mais on ne se fie
  # pas a cette filiation : on nomme l'exception. Un parametre absurde doit
  # se comporter comme un parametre absent, jamais comme une 500.
  def plane_gantt_date_param(value)
    raw = value.to_s.strip
    return nil if raw.empty?

    Date.iso8601(raw)
  rescue Date::Error, ArgumentError, TypeError, RangeError
    nil
  end

  # Fenetre effective, bandes de navigation comprises.
  def build_range(work_packages)
    starts = work_packages.filter_map { |wp| wp.start_date || wp.due_date }
    ends   = work_packages.filter_map { |wp| wp.due_date || wp.start_date }

    @data_min = starts.min
    @data_max = ends.max

    # Fenetre deduite : bornee sur les donnees, avec une semaine de marge de
    # part et d'autre pour que les barres extremes ne collent pas au bord.
    # Sans donnee du tout (fenetre explicite sur un projet vide), le mois
    # courant sert de repere : une echelle sans reference ne se lit pas.
    auto_start = @data_min ? (@data_min - 7).beginning_of_week : Date.current.beginning_of_month
    auto_end   = @data_max ? (@data_max + 7).end_of_week : Date.current.end_of_month

    @range_start = @window_from || auto_start
    @range_end   = @window_to   || auto_end

    # Une seule borne fournie : l'autre garde sa valeur automatique, qui peut
    # tomber du mauvais cote (un « depuis 2030 » sur des donnees de 2026).
    # On deroule alors 31 jours a partir de la borne donnee plutot que de
    # produire un intervalle vide — ou, pire, inverse.
    # 31 jours et pas beginning_of_month/end_of_month : une borne posee le
    # 1er du mois produirait dans ce dernier cas une fenetre d'UN jour.
    if @range_end < @range_start
      if @window_from
        @range_end = @range_start + 30
      else
        @range_start = @range_end - 30
      end
    end

    @requested_days = (@range_end - @range_start).to_i + 1
    @truncated = @requested_days > MAX_DAYS
    @range_end = @range_start + MAX_DAYS - 1 if @truncated

    @days = (@range_start..@range_end).to_a

    # Pas de la navigation : une fleche deplace d'exactement une fenetre, ce
    # qui rend le parcours previsible et sans recouvrement.
    step = @days.size
    @prev_from = @range_start - step
    @prev_to   = @range_start - 1
    @next_from = @range_end + 1
    @next_to   = @range_end + step

    # « Aujourd'hui » conserve la LARGEUR de la fenetre courante et la centre
    # sur la date du jour : le niveau de detail ne change pas sous les yeux.
    @today_from = Date.current - (step / 2)
    @today_to   = @today_from + step - 1
  end

  # Un lot compte des qu'il recouvre la fenetre, fut-ce d'un jour.
  def overlaps_range?(work_package)
    from = work_package.start_date || work_package.due_date
    to   = work_package.due_date   || work_package.start_date
    from, to = to, from if from > to

    from <= @range_end && to >= @range_start
  end

  # Disposition a plat : on parcourt les groupes dans l'ordre d'affichage et
  # on note, pour chaque lot, sa colonne, sa portee et le centre vertical de
  # sa ligne. Sans cette table, impossible de tracer une dependance : il faut
  # savoir OU se trouve chaque barre, en pixels.
  def build_layout
    @pos = {}
    y = 0

    @groups.each do |_status, items|
      y += GROUP_H
      items.each do |wp|
        col, span = plane_gantt_span(wp)
        @pos[wp.id] = { col:, span:, y: y + (ROW_H / 2) }
        y += ROW_H
      end
    end

    @canvas_height = y
  end

  # Tracés des dependances. On ne retient que les relations qui portent une
  # CONTRAINTE — l'anteriorite et le blocage. « relates » ou « duplicates »
  # sont des liens documentaires : les dessiner sur une frise ajouterait du
  # trait sans ajouter de sens.
  def build_links(work_packages)
    ids = work_packages.map(&:id)
    @links = []
    return if ids.size < 2

    relations = Relation
                  .where(from_id: ids, to_id: ids)
                  .where(relation_type: %w[follows blocks])

    relations.each do |relation|
      # follows : `to` precede `from`. blocks : `from` bloque `to`.
      if relation.relation_type == "follows"
        a = @pos[relation.to_id]
        b = @pos[relation.from_id]
      else
        a = @pos[relation.from_id]
        b = @pos[relation.to_id]
      end
      next if a.nil? || b.nil?

      @links << {
        d: connector_path(a, b),
        blocking: relation.relation_type == "blocks",
        x2: ((b[:col] - 1) * @day_width),
        y2: b[:y]
      }
    end
  end

  # Connecteur orthogonal a angles adoucis, du bord droit du predecesseur au
  # bord gauche du successeur. Quand le successeur commence AVANT la fin du
  # predecesseur — un chevauchement, donc une contrainte non respectee — le
  # trait contourne par-dessous au lieu de revenir en arriere sur lui-meme.
  # L'axe X est exprime en UNITES-JOUR, pas en pixels.
  #
  # Les colonnes de la frise s'etirent pour occuper toute la largeur
  # disponible : leur largeur reelle depend donc de la fenetre. Un tracé en
  # pixels calcule ici serait faux des que l'ecran change de taille.
  # Le SVG porte viewBox="0 0 <jours> <hauteur>" avec preserveAspectRatio
  # "none" : l'horizontale s'etire avec le conteneur, la verticale reste au
  # pixel pres puisque la hauteur du viewBox egale la hauteur reelle.
  def connector_path(from, to)
    x1 = (from[:col] + from[:span] - 1).to_f
    y1 = from[:y]
    x2 = (to[:col] - 1).to_f
    y2 = to[:y]

    gap = 0.8 # en jours

    # CAS NORMAL — le successeur commence apres la fin du predecesseur, ou
    # exactement a sa suite. Le second cas est de loin le plus frequent :
    # deux lots qui s'enchainent bord a bord donnent x2 == x1, la fin de
    # l'un et le debut de l'autre tombant sur la meme frontiere de jour.
    #
    # Le test portait sur `x2 >= x1 + gap` : ces liens jointifs basculaient
    # donc dans le contournement ci-dessous, qui tracait une verticale sur
    # toute la hauteur de la frise. Ramenes ici, ils produisent une simple
    # verticale posee sur la frontiere commune — le trace attendu.
    if x2 >= x1
      mid = [x2 - (gap / 2), x1].max
      "M #{x1} #{y1} H #{mid.round(3)} V #{y2} H #{x2}"
    else
      # VRAI CHEVAUCHEMENT — le successeur commence AVANT la fin du
      # predecesseur : la contrainte n'est pas respectee. Revenir en arriere
      # sur la ligne elle-meme se confondrait avec les barres, on contourne
      # par une voie juste sous la ligne du PREDECESSEUR. Passer sous la
      # plus basse des deux lignes, comme auparavant, faisait descendre le
      # trait sous toute la frise quand les deux lots sont eloignes.
      detour = y1 + (ROW_H / 2) - 6
      "M #{x1} #{y1} H #{(x1 + gap).round(3)} V #{detour} H #{(x2 - gap).round(3)} V #{y2} H #{x2}"
    end
  end
end
