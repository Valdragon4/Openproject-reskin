# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++
class Users::InviteController < ApplicationController
  include OpTurbo::ComponentStream
  include MemberHelper

  authorize_with_permission :manage_members, global: true
  before_action :set_project, only: :start_dialog

  def start_dialog
    respond_with_dialog(
      Users::Invitation::DialogComponent.new(form_model, project: @project)
    )
  end

  def step
    if form_model.valid?(validation_context) || params[:step] == "initial"
      respond_with_next_step
    else
      handle_errors_in_step
    end
  end

  private

  def handle_errors_in_step
    case params[:step]
    when "project"
      replace_via_turbo_stream(component: Users::Invitation::ProjectStep::FormComponent.new(form_model))
      respond_with_turbo_streams
    when "principal"
      replace_via_turbo_stream(component: Users::Invitation::PrincipalStep::FormComponent.new(form_model))
      respond_with_turbo_streams
    else
      render_400 message: "Invalid step"
    end
  end

  def respond_with_next_step # rubocop:disable Metrics/AbcSize
    case params[:step]
    when "initial"
      update_dialog_title_via_turbo_stream(Users::Invitation::DialogComponent::DIALOG_ID,
                                           new_title: I18n.t("users.invite_user_modal.title.invite"))
      replace_via_turbo_stream(component: Users::Invitation::ProjectStep::FormComponent.new(form_model))
      replace_via_turbo_stream(component: Users::Invitation::ProjectStep::FooterComponent.new(form_model))
      respond_with_turbo_streams
    when "project"
      update_dialog_title_via_turbo_stream(Users::Invitation::DialogComponent::DIALOG_ID, new_title: dialog_title)
      replace_via_turbo_stream(component: Users::Invitation::PrincipalStep::FormComponent.new(form_model))
      replace_via_turbo_stream(component: Users::Invitation::PrincipalStep::FooterComponent.new(form_model))
      respond_with_turbo_streams
    when "principal"
      create_invitation
    else
      render_400 message: "Invalid step"
    end
  end

  # Le formulaire accepte plusieurs destinataires : on invite chacun, puis on
  # rend compte de l'ENSEMBLE.
  #
  # Un echec n'annule pas les autres — une personne deja membre du projet ne
  # doit pas empecher les cinq suivantes d'entrer. La boite ne se ferme que
  # si tout est passe ; sinon elle reste ouverte, pour qu'on sache reprendre.
  def create_invitation
    calls = form_model.invitees.map { |invitee| create_member_call(invitee) }
    reussies = calls.select { |call| call&.success? }

    render_invitation_flash(reussies.size, calls.size)

    if calls.any? && reussies.size == calls.size
      close_dialog_via_turbo_stream("##{Users::Invitation::DialogComponent::DIALOG_ID}",
                                    additional: { user_id: reussies.first.result.user_id })
    else
      replace_via_turbo_stream(component: Users::Invitation::PrincipalStep::FormComponent.new(form_model))
    end

    respond_with_turbo_streams
  end

  def render_invitation_flash(reussies, total)
    projet = form_model.project.name

    if reussies.zero?
      render_error_flash_message_via_turbo_stream(
        message: I18n.t("users.invite_user_modal.plane_none", project: projet)
      )
    elsif reussies == total && total == 1
      render_success_flash_message_via_turbo_stream(
        message: I18n.t("users.invite_user_modal.success_message.#{form_model.principal_type.underscore}",
                        project: projet)
      )
    elsif reussies == total
      render_success_flash_message_via_turbo_stream(
        message: I18n.t("users.invite_user_modal.plane_all", count: total, project: projet)
      )
    else
      render_error_flash_message_via_turbo_stream(
        message: I18n.t("users.invite_user_modal.plane_partial", count: reussies, total:, project: projet)
      )
    end
  end

  # Une adresse inconnue cree un compte invite, un identifiant existant est
  # repris tel quel. invite_new_user renvoie nil quand ni l'un ni l'autre
  # n'aboutit : on ne cree alors aucune adhesion.
  def create_member_call(invitee)
    principal_id = invite_new_user(invitee, send_notification: true)
    return if principal_id.blank?

    Members::CreateService
      .new(user: current_user)
      .call(
        project_id: form_model.project_id,
        user_id: principal_id,
        role_ids: [form_model.role_id],
        notification_message: form_model.message
      )
  end

  def validation_context
    if params[:step] == "project"
      :project_step
    else
      %i[project_step principal_step]
    end
  end

  def form_model
    @form_model ||= Users::Invitation::FormModel.new(form_model_params).tap do |model|
      model.project = @project if @project && current_user.allowed_in_project?(:manage_members, @project)
    end
  end

  def set_project
    @project = Project.find(params[:project_id]) if params[:project_id].present?
  end

  def dialog_title
    I18n.t("users.invite_user_modal.type.#{form_model.principal_type.underscore}.title",
           project_name: form_model.project_name)
  end

  def form_model_params
    return {} unless params[:user_invitation]

    permitted_params.user_invitation
  end
end
