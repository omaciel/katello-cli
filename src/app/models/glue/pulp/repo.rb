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

module Glue::Pulp::Repo
  def self.included(base)
    base.send :include, LazyAccessor
    base.send :include, InstanceMethods

    base.class_eval do
      before_save :save_repo_orchestration
      before_destroy :destroy_candlepin_orchestration
      lazy_accessor :groupid, :arch, :feed, :feed_cert, :feed_key, :feed_ca,
                :clone_ids, :uri_ref, :last_sync, :relative_path, :preserve_metadata, :content_type,
                :initializer => lambda {
                  debugger
                  if pulp_id
                    Glue::Pulp::Repo.find(pulp_id)
                  end
                }
    end
  end

  def self.repo_id product_name, repo_name, env_name, organization_name
    [organization_name, env_name, product_name, repo_name].compact.join("-").gsub(/[^-\w]/,"_")
  end

  def self.find(id)
    Glue::Pulp::Repo.new(Pulp::Repository.find(id))
  end



  module InstanceMethods
    def save_repo_orchestration
      case orchestration_for
        when :create
          queue.create(:name => "create pulp repo: #{self.name}", :priority => 2, :action => [self, :create_pulp_repo])
      end
    end

    def initialize(attrs = nil)
      if attrs.nil?
        super
      elsif
        type_key = attrs.has_key?('type') ? 'type' : :type
        #rename "type" to "cp_type" (activerecord and candlepin variable name conflict)
        #if attrs.has_key?(type_key) && !(attrs.has_key?(:cp_type) || attrs.has_key?('cp_type'))
        #  attrs[:cp_type] = attrs[type_key]
        #end

        attrs_used_by_model = attrs.reject do |k, v|
          !attributes_from_column_definition.keys.member?(k.to_s) && (!respond_to?(:"#{k.to_s}=") rescue true)
        end
        super(attrs_used_by_model)
      end
    end

  def to_hash
    @params.merge(:sync_state => self.sync_state)
  end

  TYPE_YUM = "yum"
  TYPE_LOCAL = "local"

  def create_pulp_repo
    feed_cert_data = {:ca => self.feed_ca,
        :cert => self.feed_cert,
        :key => self.feed_key
    }
    Pulp::Repository.create({
        :id => self.pulp_id,
        :name => self.name,
        :relative_path => self.relative_path,
        :arch => self.arch,
        :feed => self.feed,
        :feed_cert_data => feed_cert_data,
        :groupid => self.groupid,
        :preserve_metadata => self.preserve_metadata == true,
        :content_types => self.content_type || TYPE_YUM
    })
  end

  def destroy
    Pulp::Repository.destroy(self.pulp_id)
  end

  # TODO: remove after pulp >= 0.0.401 get's released. There is this attribute
  # directly in the repo API
  def uri
    if repo_base_path = AppConfig.pulp.url[/^(.*)api$/,1]
      return "#{repo_base_path}repos/#{self.relative_path}"
    else
      raise "We expect #{AppConfig.pulp.url} to end with 'api' suffix"
    end
  end

  def packages
    if @repo_packages.nil?
      self.packages = Pulp::Repository.packages(self.pulp_id)
    end
    @repo_packages
  end

  def packages=attrs
    @repo_packages = attrs.collect do |package|
        Glue::Pulp::Package.new(package)
    end
    @repo_packages
  end

  def errata
    if @repo_errata.nil?
       self.errata = Pulp::Repository.errata(self.pulp_id)
    end
    @repo_errata
  end

  def errata=attrs
    @repo_errata = attrs.collect do |erratum|
        Glue::Pulp::Errata.new(erratum)
    end
    @repo_errata
  end

  def distributions
    if @repo_distributions.nil?
      self.distributions = Pulp::Repository.distributions(self.pulp_id)
    end
    @repo_distributions
  end

  def distributions=attrs
    @repo_distributions = attrs.collect do |dist|
        Glue::Pulp::Distribution.new(dist)
    end
    @repo_distributions
  end

  def package_groups search_args = {}
    groups = ::Pulp::PackageGroup.all @id
    unless search_args.empty?
      groups.delete_if do |group_id, group_attrs|
        search_args.any?{ |attr,value| group_attrs[attr] != value }
      end
    end
    groups.values
  end

  def package_group_categories search_args = {}
    categories = ::Pulp::PackageGroupCategory.all @id
    unless search_args.empty?
      categories.delete_if do |category_id, category_attrs|
        search_args.any?{ |attr,value| category_attrs[attr] != value }
      end
    end
    categories.values
  end

  def clone_id(environment)
    Glue::Pulp::Repo.repo_id(self.product.name, self.name, environment.name,environment.organization.name)
  end

  #is the repo cloned in the specified environment
  def is_cloned_in? env
    clone_id = self.clone_id(env)
    self.clone_ids.include? clone_id
  end

  def get_clone env
    Glue::Pulp::Repo.find(self.clone_id(env))
  rescue
    nil
  end


  def has_package? id
    self.packages.each {|pkg|
      return true if pkg.id == id
    }
    return false
  end

  def find_packages_by_name name
    Pulp::Repository.packages_by_name id, name
  end

  def find_packages_by_nvre name, version, release, epoch
    Pulp::Repository.packages_by_nvre id, name, version, release, epoch
  end

  def find_latest_packages_by_name name
    Katello::PackageUtils.find_latest_packages(Pulp::Repository.packages_by_name(id, name))
  end

  def has_erratum? id
    self.errata.each {|err|
      return true if err.id == id
    }
    return false
  end

  def sync
    [Pulp::Repository.sync(self.pulp_id)]
  end

  #get last sync status of all repositories in this product
  def latest_sync_statuses
    [self._get_most_recent_sync_status()]
  end

  def sync_status
    self._get_most_recent_sync_status()
  end

  def sync_state
    status = self._get_most_recent_sync_status()
    return ::PulpSyncStatus::Status::NOT_SYNCED if status.nil?
    status.state
  end

  def sync_start
    status = _get_most_recent_sync_status()
    retval = nil
    if status.nil? or status.start_time.nil?
      retval = nil
    else
      retval = status.start_time
      # retval = date.strftime("%H:%M:%S %Y-%m-%d")
    end
    retval
  end

  def cancel_sync
    Rails.logger.info "Cancelling synchronization of repository #{@id}"
    history = Pulp::Repository.sync_history(@id)
    return if (history.nil? or history.empty?)

    Pulp::Repository.cancel(@id.to_s, history[0][:id])
  end

  def add_packages pkg_id_list
    Pulp::Repository.add_packages self.pulp_id,  pkg_id_list
  end

  def add_errata errata_id_list
    Pulp::Repository.add_errata self.pulp_id,  errata_id_list
  end

  def sync_finish
    status = _get_most_recent_sync_status()
    retval = nil
    if status.nil? or status.finish_time.nil?
      retval = nil
    else
      retval = status.finish_time
      # retval = date.strftime("%H:%M:%S %Y-%m-%d")
    end
    retval
  end


  def _get_most_recent_sync_status()
    history = Pulp::Repository.sync_history(pulp_id)
    return ::PulpSyncStatus.new(:state => ::PulpSyncStatus::Status::NOT_SYNCED) if (history.nil? or history.empty?)
    ::PulpSyncStatus.using_pulp_task(history[0])
  end

  def synced?
    sync_history = Pulp::Repository.sync_history pulp_id
    !sync_history.nil? && !sync_history.empty? && successful_sync?(sync_history[0])
  end

  def successful_sync?(sync_history_item)
    sync_history_item['state'] == 'finished'
  end

  def promote(to_environment, product)
    cloned = Glue::Pulp::Repo.new
    cloned.id = self.clone_id(to_environment)
    cloned.relative_path = Glue::Pulp::Repos.clone_repo_path(self, to_environment)
    cloned.arch = arch
    cloned.name = name
    cloned.feed = feed
    cloned.groupid = Glue::Pulp::Repos.groupid(product, to_environment)
    [Pulp::Repository.clone_repo(self, cloned)]
  end

  def organization
    Organization.find((get_groupid_param 'org').to_i)
  end

  def environment
    KTEnvironment.find((get_groupid_param 'env').to_i)
  end

  def product
    Product.find_by_cp_id!(get_groupid_param 'product')
  end

  # Convert array of Repo objects to Ruby Hash in the form of repo.id => repo_object for fast searches.
  #
  # @param array_to_hash array of Repo objects
  # @returns Hash structure
  def self.array_to_hash(array_of_repos)
    Hash[*array_of_repos.collect { |r|
      [r.id, r]
    }.flatten]
  end

  private
  def get_groupid_param name
    idx = self.groupid.index do |s| s.start_with? name+':' end
    if idx >= 0
      return self.groupid[idx].split(':')[1]
    else
      return nil
    end
  end
  end

end
