#
# Copyright © 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
#
# Red Hat trademarks are not licensed under GPLv2. No permission is
# granted to use or replicate Red Hat trademarks that are incorporated
# in this software or its documentation.

class RepositoriesController < ApplicationController
  respond_to :html, :js

  before_filter :find_provider, :only => [:show, :edit, :update, :destroy, :index, :new, :create]
  before_filter :find_product, :only => [:show, :edit, :update, :destroy, :index, :new, :create]
  before_filter :find_repository, :only => [:edit, :update, :destroy]

  def section_id
    'contents'
  end

  def new
    render :partial => "new"
  end

  def edit
    render :partial => "edit"
  end

  def create
    begin
      repo_params = params[:repo]
      # Bundle these into one call, perhaps move to Provider
      # Also fix the hard coded yum
      @product.add_new_content(repo_params[:name], repo_params[:feed], 'yum')
      @product.save

    rescue Exception => error
      Rails.logger.error error.to_s
      errors error 
      render :text=> error.to_s, :status=>:bad_request and return
    end
    notice _("Repository '#{repo_params[:name]}' created.")
    render :json => ""
  end

  def update
  end

  def destroy
    @product.delete_repo(params[:id])
    notice _("Repository '#{params[:id]}' removed.")
    render :json => ""
  end

  protected

  def find_provider
    @provider = Provider.find(params[:provider_id])
    errors _("Couldn't find provider '#{params[:provider_id]}'") if @provider.nil?
    redirect_to(:controller => :providers, :action => :index, :organization_id => current_organization.cp_key) and return if @provider.nil?
  end

  def find_product
    @product = Product.find(params[:product_id])
    errors _("Couldn't find product '#{params[:product_id]}'") if @product.nil?
    redirect_to(:controller => :providers, :action => :index, :organization_id => current_organization.cp_key) and return if @product.nil?
  end

  def find_repository
    @repository = Pulp::Repository.find @product.repo_id(params[:id])
    errors _("Couldn't find repository '#{params[:id]}'") if @repository.nil?
    redirect_to(:controller => :providers, :action => :index, :organization_id => current_organization.cp_key) and return if @repository.nil?
  end
end
