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

require 'resources/pulp'

class SyncManagementController < ApplicationController
  include TranslationHelper
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::NumberHelper

  before_filter :require_user
  respond_to :html, :json

  @@status_values = { Glue::Pulp::Repo::SYNC_STATE_WAITING => _("Queued."),
                     Glue::Pulp::Repo::SYNC_STATE_FINISHED => _("Sync complete."),
                     Glue::Pulp::Repo::SYNC_STATE_ERROR => _("Error syncing!"),
                     Glue::Pulp::Repo::SYNC_STATE_RUNNING => _("Running."),
                     Glue::Pulp::Repo::SYNC_STATE_NOT_SYNCED => _("Not synced.")}

  def section_id
    'contents'
  end

  def index
    # TODO: We need to switch to using an Org's ID vs the display name.  See BZ 701406
    @organization = current_organization
    rproducts = @organization.locker.products.reject { |p| p.repos(p.organization.locker).empty? }
    @products = rproducts.sort { |p1,p2| p1.name <=> p2.name }
    @product_status = Hash.new
    @product_size = Hash.new
    @repo_status = Hash.new
    for p in @products
      pstatus = p.sync_status
      @product_status[p.id] = format_sync_progress(pstatus)
      @product_size[p.id] = number_to_human_size(p.sync_size)
      for r in p.repos(p.organization.locker)
        repo_status = r.sync_status
        @repo_status[r.id] = format_sync_progress(repo_status)
      end
    end
  end

  def sync
    ids = sync_repos(params[:repo]) || {}
    respond_with (ids) do |format|
      format.js { render :json => ids.to_json, :status => :ok }
    end
  end
 
  def status
    sync_status = Glue::Pulp::Repo.new(:id => params[:repo_id]).sync_status
    progress = format_sync_progress(sync_status)
    progress[:repo_id] = params['repo_id']

    respond_with (progress) do |format|
      format.js { render :json => progress.to_json, :status => :ok }
    end
  end

  def product_status
    product = Product.first(:conditions => {:id => params['product_id']})
    repo_stat = Glue::Pulp::Repo.new(:id => params[:repo_id]).sync_status
    status = product.sync_status 
    send_notification(product, repo_stat) if status.state == Glue::Pulp::Repo::SYNC_STATE_FINISHED
    report_error(product) if status.state == Glue::Pulp::Repo::SYNC_STATE_ERROR

    progress = format_sync_progress(status)
    progress[:product_id] = params['product_id']
    progress[:size] = number_to_human_size(product.sync_size)

    respond_with (progress) do |format|
      format.js { render :json => progress.to_json, :status => :ok }
    end
  end

  def destroy
    retval = Pulp::Repository.cancel(params['repo_id'], params[:id])
    cancel =  {:sync_id => retval[:id], :state => retval[:state] }
    respond_with (cancel) do |format|
      format.js { render :json => cancel.to_json, :status => :ok }
    end
  end

private

  def format_sync_progress(sync_status)
    progress = {:progress => calc_progress(sync_status)}
    progress[:sync_id] = sync_status.sync_id
    progress[:state] = format_state(sync_status.state)
    progress[:start_time] = format_date(sync_status.start_time)
    progress[:finish_time] = format_date(sync_status.finish_time)
    progress[:packages] = sync_status.total_count
    progress[:size] = number_to_human_size(sync_status.total_size)
    progress
  end

  def format_state(state)
    @@status_values[state]
  end

  def format_date(check_date)
    retval = nil
    if !check_date.nil?
      retval = relative_time_in_words(check_date)
    end
    retval
  end

  # loop through checkbox list of products and sync
  def sync_repos(repos)
   
    data = {} # sync throttle data
    data[:limit] = AppConfig.pulp.sync_KBlimit if AppConfig.pulp.sync_KBlimit # set bandwidth limit
    data[:threads] = AppConfig.pulp.sync_threads if AppConfig.pulp.sync_threads # set threads per sync
    repos.keys.inject([]) do |collected,id|
      product_id = repos[id]
      begin
        resp = Pulp::Repository.sync(id, data)
      rescue RestClient::Conflict => e
        errors N_("There is already an active sync process for the '#{id}' repository. Please try again later")
        next
      end
      collected.push({:repo_id => id, :sync_id => resp[:id], :state => resp[:state], :product_id => product_id})
    end
  end

  # calculate the % complete of ongoing sync from pulp
  def calc_progress(val)
    completed = val.total_size - val.size_left
    progress = if val.state =~ /error/i then -1
               elsif val.total_size == 0 then 0
               else completed.to_f / val.total_size.to_f * 100
               end
    retval = {:count => val.total_count,
              :left => val.items_left,
              :progress => progress
             }
  end

  def send_notification(product, status)
    if status.error_details.size > 0 then
      notice product.name + ' ' + _("product was synced successfully with errors. See log for details"),
                                  {:details => status.error_details.join("\n"),:synchronous_request => false}
      status.error_details.each { |d| Rails.logger.error("Sync error:" +  d[:error]) }
    else
      notice product.name + ' ' + _("product was synced successfully")
    end
  end

  def report_error(product)
    errors product.name + ' ' + _("sync did not complete successfully"), {:synchronous_request => false}
    Rails.logger.error product.name + " sync did not complete successfully"
  end

end
