//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import { ApplicationController } from 'stimulus-use';
import * as Turbo from '@hotwired/turbo';
import { TurboBeforeVisitEvent } from '@hotwired/turbo';
import { planeConfirm } from 'core-turbo/plane-confirm';

export class BeforeunloadController extends ApplicationController {
  private abortController = new AbortController();

  // Une visite deja confirmee doit traverser le garde sans le redeclencher,
  // sinon la modale se rouvrirait a l'infini : les modifications ne sont pas
  // « enregistrees » par le fait d'avoir clique sur Quitter.
  private approvedVisit:string|null = null;

  connect() {
    super.connect();

    const { signal } = this.abortController;

    window.addEventListener('beforeunload', this, { signal });
    document.addEventListener('turbo:before-visit', this, { signal });
    document.addEventListener('turbo:submit-end', this, { signal });
    document.addEventListener('turbo:load', this, { signal });
    document.addEventListener('turbo:render', this, { signal });
    document.addEventListener('submit', this, { signal });
  }

  disconnect() {
    this.abortController.abort();
  }

  handleEvent(evt:Event) {
    switch (evt.type) {
      case 'beforeunload':
        this.beforeunloadHandler(evt);
        break;
      case 'turbo:before-visit':
        this.beforeVisitHandler(evt as TurboBeforeVisitEvent);
        break;
      case 'turbo:submit-end':
      case 'turbo:load':
      case 'turbo:render':
        this.approvedVisit = null;
        window.OpenProject.pageState = 'pristine';
        break;
      case 'submit':
        window.OpenProject.pageState = 'submitted';
        break;
      default:
        break;
    }
  }

  // Sortie du site (fermeture d'onglet, rechargement, URL saisie a la main).
  //
  // Ce cas N'EST PAS habillable : les navigateurs imposent leur propre boite
  // et leur propre texte pour empecher un site de retenir l'internaute. On se
  // contente donc d'armer l'evenement. Appeler window.confirm() ici — ce que
  // faisait le code precedent — est sans effet : pendant beforeunload les
  // navigateurs ignorent les dialogues script et renvoient false.
  private beforeunloadHandler(evt:BeforeUnloadEvent) {
    if (!window.OpenProject.pageWasEdited) {
      return;
    }

    evt.preventDefault();
    // Chrome exige encore returnValue.
    evt.returnValue = '';
  }

  // Navigation INTERNE (clic sur un lien pilote par Turbo). C'est la quasi-
  // totalite des cas vecus, et la elle nous appartient : on annule la visite,
  // on pose notre modale, puis on rejoue la visite si l'utilisateur confirme.
  //
  // turbo:before-visit n'est pas annulable « en attente » : le gestionnaire
  // est synchrone, donc impossible d'attendre la reponse avant de decider. La
  // seule construction correcte est d'annuler d'abord, toujours, et de
  // relancer ensuite.
  private beforeVisitHandler(evt:TurboBeforeVisitEvent) {
    const { url } = evt.detail;

    if (this.approvedVisit === url) {
      this.approvedVisit = null;
      return;
    }

    if (!window.OpenProject.pageHasUnsavedChanges) {
      return;
    }

    evt.preventDefault();

    void planeConfirm({
      message: I18n.t('js.text_are_you_sure_to_cancel'),
      danger: true,
    }).then((confirmed) => {
      if (!confirmed) {
        return;
      }

      this.approvedVisit = url;
      // action « advance » : on reproduit un clic de lien, pour que l'entree
      // d'historique et le garde de rendu d'Angular (qui distingue les
      // visites de restauration) se comportent comme sans interception.
      Turbo.visit(url, { action: 'advance' });
    });
  }
}
