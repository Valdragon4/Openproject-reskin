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

import { vi } from 'vitest';
import { OpenProject } from 'core-app/core/setup/globals/openproject';
import { BeforeunloadController } from './beforeunload.controller';

// La modale maison est asynchrone : on la remplace par une promesse dont on
// controle la reponse, sinon le test attendrait un clic reel.
const planeConfirm = vi.hoisted(() => vi.fn());
const turboVisit = vi.hoisted(() => vi.fn());

vi.mock('core-turbo/plane-confirm', () => ({ planeConfirm }));
vi.mock('@hotwired/turbo', () => ({ visit: turboVisit }));

describe('BeforeunloadController', () => {
  let originalOpenProject:OpenProject;
  let controller:BeforeunloadController;

  beforeEach(() => {
    originalOpenProject = window.OpenProject;
    window.OpenProject = new OpenProject();
    vi.stubGlobal('I18n', { t: vi.fn().mockReturnValue('Leave page?') });
    planeConfirm.mockReset().mockResolvedValue(false);
    turboVisit.mockReset();
    controller = Object.create(BeforeunloadController.prototype) as BeforeunloadController;
  });

  afterEach(() => {
    window.OpenProject = originalOpenProject;
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  function turboBeforeVisit(url = 'http://example.com/projects') {
    return new CustomEvent('turbo:before-visit', {
      detail: { url },
      cancelable: true,
    });
  }

  function handle(event:Event) {
    controller.handleEvent(event);

    return event;
  }

  it('shows the in-app dialog when Angular edit forms have unsaved changes', () => {
    window.OpenProject.editFormsContainUnsavedChanges = () => true;
    const event = handle(turboBeforeVisit());

    expect(planeConfirm).toHaveBeenCalledWith({ message: 'Leave page?', danger: true });
    // La visite est TOUJOURS annulee d'abord : le gestionnaire est synchrone,
    // il ne peut pas attendre la reponse de la modale.
    expect(event.defaultPrevented).toBe(true);
  });

  it('shows the in-app dialog when pageState is edited', () => {
    window.OpenProject.pageState = 'edited';

    const event = handle(turboBeforeVisit());

    expect(planeConfirm).toHaveBeenCalled();
    expect(event.defaultPrevented).toBe(true);
  });

  it('does not show a dialog when nothing is dirty', () => {
    const event = handle(turboBeforeVisit());

    expect(planeConfirm).not.toHaveBeenCalled();
    expect(event.defaultPrevented).toBe(false);
  });

  it('replays the visit when the user confirms', async () => {
    planeConfirm.mockResolvedValue(true);
    window.OpenProject.editFormsContainUnsavedChanges = () => true;

    handle(turboBeforeVisit('http://example.com/roadmap'));
    await vi.waitFor(() => expect(turboVisit).toHaveBeenCalled());

    expect(turboVisit).toHaveBeenCalledWith('http://example.com/roadmap', { action: 'advance' });
  });

  it('lets the replayed visit through without asking again', async () => {
    planeConfirm.mockResolvedValue(true);
    window.OpenProject.editFormsContainUnsavedChanges = () => true;

    handle(turboBeforeVisit('http://example.com/roadmap'));
    await vi.waitFor(() => expect(turboVisit).toHaveBeenCalled());
    planeConfirm.mockClear();

    const replay = handle(turboBeforeVisit('http://example.com/roadmap'));

    expect(planeConfirm).not.toHaveBeenCalled();
    expect(replay.defaultPrevented).toBe(false);
  });

  it('does not ask on native beforeunload, only arms the browser dialog', () => {
    window.OpenProject.editFormsContainUnsavedChanges = () => true;
    const event = new Event('beforeunload', { cancelable: true });

    handle(event);

    // pageWasEdited seul compte ici, et la boite reste celle du navigateur.
    expect(planeConfirm).not.toHaveBeenCalled();
    expect(event.defaultPrevented).toBe(false);
  });

  it('arms the native dialog when the page itself was edited', () => {
    window.OpenProject.pageState = 'edited';
    const event = new Event('beforeunload', { cancelable: true });

    handle(event);

    expect(planeConfirm).not.toHaveBeenCalled();
    expect(event.defaultPrevented).toBe(true);
  });

  it('resets pageState to pristine on turbo:render', () => {
    window.OpenProject.pageState = 'edited';

    handle(new Event('turbo:render'));

    expect(window.OpenProject.pageState).toBe('pristine');
  });

  it('sets pageState to submitted on form submit', () => {
    handle(new Event('submit'));

    expect(window.OpenProject.pageState).toBe('submitted');
  });
});
