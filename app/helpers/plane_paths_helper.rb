# frozen_string_literal: true

# Chaque page reconstruite existe en deux portees : dans un projet
# (/projects/:id/plane…) et hors projet (/plane/…). Les vues sont les memes
# et ne doivent pas se demander laquelle appeler a chaque lien — sans cela,
# un commutateur de vue oublie renvoie a l'ancienne page, ce qui est
# exactement le defaut qu'on corrige.
module PlanePathsHelper
  # plane_page_path(:gantt) -> /projects/x/plane-gantt ou /plane/gantt
  def plane_page_path(page, project = @project, **options)
    if project&.persisted?
      public_send(:"project_plane_#{page}_path", project, **options)
    else
      public_send(:"plane_#{page}_path", **options)
    end
  end

  # Cible de creation d'un lot : dans un projet quand on en a un, sinon le
  # formulaire global (qui demande le projet dans son premier champ).
  def plane_new_work_package_path(project = @project)
    project&.persisted? ? "#{project_work_packages_path(project)}/new" : "#{work_packages_path}/new"
  end

  # Les trois commutateurs de vue etaient dupliques dans les trois pages,
  # avec des libelles et des destinations divergents. Une seule definition :
  # l'Apercu n'a de sens que dans un projet, la liste des projets le
  # remplace hors projet.
  def plane_view_switcher(current)
    entries = if @project&.persisted?
                [[:overview, "Aperçu"], [:work, "Travail"], [:gantt, "Frise"]]
              else
                [[:projects, "Projets"], [:work, "Travail"], [:gantt, "Frise"]]
              end

    entries.map do |page, label|
      [page, label, page == current]
    end
  end
end
