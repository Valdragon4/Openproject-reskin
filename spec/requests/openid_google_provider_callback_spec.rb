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

require "spec_helper"
require "rack/test"

RSpec.describe "OpenID Google provider callback", with_ee: %i[sso_auth_providers] do
  include Rack::Test::Methods
  include API::V3::Utilities::PathHelper

  let(:provider) { create(:oidc_provider_google, limit_self_registration: false) }
  let(:auth_hash) do
    { "state" => "623960f1b4f1020941387659f022497f536ad3c95fa7e53b0f03bdbf36debd59f76320801ea2723df520",
      "code" => "4/0AVHEtk6HMPLH08Uw8OVoSaAbd2oTi7Z6wOlBsMQ99Yj3qgKhhyKAxUQBvQ2MZuRzvueOgQ",
      "scope" => "email profile https://www.googleapis.com/auth/userinfo.email openid https://www.googleapis.com/auth/userinfo.profile",
      "authuser" => "0",
      "prompt" => "none" }
  end
  let(:uri) do
    uri = URI("/auth/#{provider.slug}/callback")
    uri.query = URI.encode_www_form([["code", auth_hash["code"]],
                                     ["state", auth_hash["state"]],
                                     ["scope", auth_hash["scope"]],
                                     ["authuser", auth_hash["authuser"]],
                                     ["prompt", auth_hash["prompt"]]])
    uri
  end

  before do
    stub_request(:post, "https://oauth2.googleapis.com/token").to_return(
      status: 200,
      body: {
        "access_token" =>
        "ya29.EXEMPLE-DE-JETON-D-ACCES-SANS-VALEUR",
        "expires_in" => 3594,
        "scope" =>
        "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile openid",
        "token_type" => "Bearer",
        "id_token" =>
        "eyJhbGciOiJSUzI1NiIsImtpZCI6IjAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJhY2NvdW50cy5nb29nbGUuY29tIiwiYXpwIjoiMDAwMDAwMDAwMDAwLWV4ZW1wbGUuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiIwMDAwMDAwMDAwMDAtZXhlbXBsZS5hcHBzLmdvb2dsZXVzZXJjb250ZW50LmNvbSIsInN1YiI6IjEwNzQwMzUxMTAzNzkyMTM1NTMwNyIsImVtYWlsIjoiZW1haWxAZHVtbXkuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImF0X2hhc2giOiJBQUFBQUFBQUFBQUFBQUFBQUFBQUFBIiwiaWF0IjoxNjgwNjEyMTk0LCJleHAiOjE2ODA2MTU3OTR9.SIGNATURE-FACTICE-JETON-DE-TEST-SANS-VALEUR"
      }.to_json,
      headers: { "content-type" => "application/json; charset=utf-8" }
    )
    stub_request(:get, "https://openidconnect.googleapis.com/v1/userinfo").to_return(
      status: 200,
      body: { "sub" => "107403511037921355307",
              "name" => "Firstname Lastname",
              "given_name" => "Firstname",
              "family_name" => "Lastname",
              "picture" => "https://lh3.googleusercontent.com/a/AGNmyxZtDAl-mgOOCF_DCo-WWEct-LyVp7zGhXkfKR8r=s96-c",
              "email" => "email@dummy.com",
              "email_verified" => true,
              "locale" => "en-GB" }.to_json,
      headers: { "content-type" => "application/json; charset=utf-8" }
    )

    allow_any_instance_of(OmniAuth::Strategies::OpenIDConnect).to receive(:session) {
      {
        "omniauth.state" => auth_hash["state"]
      }
    }
  end

  it "redirects user without errors", :webmock do
    response = get(uri.to_s)
    expect(response).to have_http_status(:found)
    expect(response.location).to eq("http://#{Setting.host_name}/two_factor_authentication/request")
  end
end
