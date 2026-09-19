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

import * as Turbo from '@hotwired/turbo';

interface PlaneConfirmLabels {
  title:string;
  danger_title:string;
  confirm:string;
  danger_confirm:string;
  cancel:string;
}

export interface PlaneConfirmOptions {
  message:string;
  title?:string;
  confirmLabel?:string;
  cancelLabel?:string;
  danger?:boolean;
}

// Repli en dur : si le serveur n'a pas pose les libelles (page servie par un
// cache ancien, ou body remplace par du code tiers), la modale doit quand
// meme s'afficher plutot que de laisser l'action passer sans confirmation.
const FALLBACK:PlaneConfirmLabels = {
  title: 'Confirmation',
  danger_title: 'Confirmation',
  confirm: 'Confirm',
  danger_confirm: 'Confirm',
  cancel: 'Cancel',
};

function labels():PlaneConfirmLabels {
  // Les traductions viennent du serveur (application_helper#body_data_attributes)
  // et non de I18n cote frontend : les cles js.* exigeraient de regenerer
  // frontend/src/locales/*.json, un artefact construit qu'on ne veut pas
  // modifier a la main.
  const raw = document.body?.dataset?.planeConfirm;
  if (!raw) {
    return FALLBACK;
  }

  try {
    return { ...FALLBACK, ...JSON.parse(raw) as Partial<PlaneConfirmLabels> };
  } catch {
    return FALLBACK;
  }
}

let counter = 0;

export function planeConfirm(options:PlaneConfirmOptions):Promise<boolean> {
  const text = labels();
  const danger = options.danger === true;
  counter += 1;
  const titleId = `op-plane-confirm--title-${counter}`;
  const messageId = `op-plane-confirm--message-${counter}`;

  const dialog = document.createElement('dialog');
  dialog.className = danger ? 'op-plane-confirm -danger' : 'op-plane-confirm';
  dialog.setAttribute('aria-labelledby', titleId);
  dialog.setAttribute('aria-describedby', messageId);

  // method="dialog" : le navigateur ferme la modale et reporte le value du
  // bouton presse dans returnValue. Pas de gestionnaire de clic a ecrire, et
  // la touche Entree se comporte comme la soumission d'un formulaire.
  const form = document.createElement('form');
  form.method = 'dialog';
  form.className = 'op-plane-confirm--form';

  const title = document.createElement('h2');
  title.className = 'op-plane-confirm--title';
  title.id = titleId;
  title.textContent = options.title ?? (danger ? text.danger_title : text.title);

  const message = document.createElement('p');
  message.className = 'op-plane-confirm--message';
  message.id = messageId;
  // textContent, jamais innerHTML : le message peut venir d'un nom d'objet
  // saisi par un utilisateur.
  message.textContent = options.message;

  const actions = document.createElement('div');
  actions.className = 'op-plane-confirm--actions';

  const cancel = document.createElement('button');
  cancel.type = 'submit';
  cancel.value = 'cancel';
  cancel.className = 'op-plane-confirm--button -cancel';
  cancel.textContent = options.cancelLabel ?? text.cancel;
  // Focus initial sur le bouton le MOINS destructeur : une validation
  // reflexe a la touche Entree ne doit rien detruire.
  cancel.autofocus = true;

  const accept = document.createElement('button');
  accept.type = 'submit';
  accept.value = 'confirm';
  accept.className = danger
    ? 'op-plane-confirm--button -confirm -danger'
    : 'op-plane-confirm--button -confirm';
  accept.textContent = options.confirmLabel ?? (danger ? text.danger_confirm : text.confirm);

  actions.appendChild(cancel);
  actions.appendChild(accept);
  form.appendChild(title);
  form.appendChild(message);
  form.appendChild(actions);
  dialog.appendChild(form);
  document.body.appendChild(dialog);

  return new Promise<boolean>((resolve) => {
    // « close » couvre les trois sorties : les deux boutons et la touche
    // Echap (qui laisse returnValue vide, donc false).
    dialog.addEventListener('close', () => {
      const confirmed = dialog.returnValue === 'confirm';
      dialog.remove();
      resolve(confirmed);
    }, { once: true });

    // Un clic sur le ::backdrop atteint le <dialog> lui-meme, jamais le
    // formulaire : c'est le test qui distingue « a cote » de « dedans ».
    dialog.addEventListener('click', (evt) => {
      if (evt.target === dialog) {
        dialog.close('cancel');
      }
    });

    dialog.showModal();
    // Safari n'honore autofocus que si l'element est deja dans le document
    // au moment du showModal ; on le repose explicitement par securite.
    cancel.focus();
  });
}

// Une action est consideree destructrice si elle passe par DELETE, ou si le
// declencheur porte deja l'habillage « danger » de Primer. On ne devine rien
// a partir du texte du message : il est traduit, donc impossible a analyser.
function isDangerous(element?:Element|null, submitter?:Element|null):boolean {
  const candidates = [submitter, element].filter((el):el is Element => !!el);

  return candidates.some((el) => {
    // Un <form> Rails annonce toujours method="post" : le verbe reel vit
    // dans le champ cache _method. C'est le piege a ne pas manquer, sinon
    // aucune suppression ne recoit la variante rouge.
    const override = el instanceof HTMLFormElement
      ? el.querySelector<HTMLInputElement>('input[name="_method"]')?.value
      : null;

    const method = (el as HTMLElement).dataset?.turboMethod
      ?? el.getAttribute('formmethod')
      ?? override
      ?? (el instanceof HTMLFormElement ? el.getAttribute('method') : null);

    if (method?.toLowerCase() === 'delete') {
      return true;
    }

    return el.classList.contains('Button--danger')
      || el.classList.contains('color-fg-danger')
      || el.querySelector('.Button--danger') !== null;
  });
}

export function registerPlaneConfirm():void {
  // Turbo.config.forms.confirm, et non setConfirmMethod() : ce dernier est
  // deprecie depuis la 8.x et ses typages n'existent que sur l'objet Turbo
  // global, pas sur le module importe.
  Turbo.config.forms.confirm = (
    message:string,
    element:HTMLFormElement,
    submitter:HTMLElement|null,
  ) => planeConfirm({
    message,
    danger: isDangerous(element, submitter),
  });
}
