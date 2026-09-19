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

module Users::Invitation
  class FormModel < ApplicationRecord
    include Tableless

    belongs_to :project
    attribute :project_id, :integer, default: nil
    attribute :role_id, :integer, default: nil
    attribute :principal_type, :text, default: nil
    # Volontairement SANS TYPE : le champ accepte desormais plusieurs
    # destinataires et recoit donc un tableau. Declare en :text, il serait
    # converti en la chaine « ["12", "a@b.fr"] » et l'invitation partirait
    # vers un destinataire inexistant.
    attribute :id_or_email, default: nil
    # Collage d'une liste d'adresses. L'auto-completion cherche un terme a la
    # fois : elle ne sait pas recevoir « a@x.fr, b@x.fr, c@x.fr » d'un coup,
    # ce qui est pourtant la facon normale d'inviter une promotion ou une
    # equipe. Ce champ la complete, il ne la remplace pas.
    attribute :bulk_emails, :text, default: nil
    attribute :message, :text, default: nil

    validates :project_id, presence: true, on: :project_step
    validates :principal_type,
              inclusion: { in: ->(*) { available_principal_types } },
              on: :project_step

    validate :at_least_one_invitee, on: :principal_step
    validates :role_id, presence: true, on: :principal_step

    # Separateurs acceptes dans une liste collee : virgule, point-virgule,
    # retour a la ligne, tabulation, espace. Un copier-coller depuis un
    # tableur, un courriel ou un annuaire passe par l'un des cinq.
    SEPARATEURS = /[,;\s]+/

    # Liste normalisee des destinataires, quelle que soit leur provenance :
    # identifiants choisis dans l'auto-completion, adresses collees, ou les
    # deux. Le decoupage s'applique aussi aux valeurs de l'auto-completion :
    # un collage dans ce champ-la doit produire le meme resultat.
    def invitees
      brut = Array.wrap(id_or_email) + [bulk_emails]

      brut.flat_map { |value| value.to_s.split(SEPARATEURS) }
          .map(&:strip)
          .reject(&:blank?)
          .uniq
    end

    # Ce qui ressemble a une adresse sans en etre une. On le signale plutot
    # que d'envoyer silencieusement quatre invitations sur cinq.
    def invalid_invitees
      # ::EmailValidator et non EmailValidator : dans un modele ActiveRecord,
      # le nom court se resout vers ActiveModel::Validations::EmailValidator,
      # qui n'a pas de methode de classe valid?.
      invitees.reject { |value| ::EmailValidator.valid?(value) || value.match?(/\A\d+\z/) }
    end

    def multiple_invitees?
      invitees.size > 1
    end

    # L'erreur reste portee par :id_or_email pour que le formulaire la
    # signale sur le bon champ.
    def at_least_one_invitee
      return errors.add(:id_or_email, :blank) if invitees.empty?

      mauvaises = invalid_invitees
      return if mauvaises.empty?

      errors.add(:bulk_emails,
                 I18n.t("users.invite_user_modal.plane_bulk.invalid", list: mauvaises.join(", ")))
    end

    def self.available_principal_types
      if EnterpriseToken.allows_to?(:placeholder_users)
        %w[User PlaceholderUser Group]
      else
        %w[User Group]
      end
    end

    def project_name
      project&.name || project_id
    end

    def to_h
      {
        project_id:,
        role_id:,
        principal_type:,
        id_or_email:,
        # Sans cette ligne, la liste collee serait perdue au passage d'une
        # etape a l'autre du formulaire.
        bulk_emails:,
        message:
      }
    end
  end
end
