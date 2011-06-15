#
# Copyright 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

require 'spec_helper'

describe ProvidersController do
  include LoginHelperMethods
  include LocaleHelperMethods

  before(:each) do
    login_user
    setup_current_organization
    set_default_locale
    controller.stub!(:notice)
    controller.stub!(:errors)

    @org = controller.current_organization
    @org.stub!(:providers).and_return([@provider])
  end

  PROVIDER_NAME = "a name"
  ANOTHER_PROVIDER_NAME = "another name"

  let(:to_create) do
    {
      :name => PROVIDER_NAME,
      :description => "a description",
      :repository_url => "https://some.url",
      :provider_type => Provider::REDHAT
    }
  end

  describe "update a provider subscriptions" do
    before(:each) do
      @provider = Provider.create!(to_create)
      Candlepin::Owner.stub!(:import)
      Candlepin::Owner.stub!(:pools).and_return({})
    end

    it "should update a provider subscription" do
      test_export = File.new("#{Rails.root}/spec/controllers/export.zip")
      contents = {:contents => test_export}
      id = @provider.id.to_s
      
      post 'subscriptions', {:id => id, :provider => contents}
    end
  end

end
