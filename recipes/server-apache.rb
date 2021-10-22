#
# Cookbook:: openstack-identity
# Recipe:: server-apache
#
# Copyright:: 2015-2021, IBM Corp. Inc.
# Copyright:: 2016-2021, Oregon State University
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This recipe installs and configures the OpenStack Identity Service running
# inside of an apache webserver. The recipe is documented in detail with inline
# comments inside the recipe.

# load the methods defined in cookbook-openstack-common libraries
class ::Chef::Recipe
  include ::Openstack
  include Apache2::Cookbook::Helpers
end

# include the logging recipe from openstack-common if syslog usage is enbaled
if node['openstack']['identity']['syslog']['use']
  include_recipe 'openstack-common::logging'
end

platform_options = node['openstack']['identity']['platform']

identity_internal_endpoint = internal_endpoint 'identity'
identity_endpoint = public_endpoint 'identity'

# define the address where the keystone public endpoint will be reachable
ie = identity_endpoint
# define the keystone public endpoint full path
api_endpoint = "#{ie.scheme}://#{ie.host}:#{ie.port}/"

# define the credentials to use for the initial admin user
admin_project = node['openstack']['identity']['admin_project']
admin_user = node['openstack']['identity']['admin_user']
admin_pass = get_password 'user', node['openstack']['identity']['admin_user']
admin_role = node['openstack']['identity']['admin_role']
region = node['openstack']['identity']['region']
keystone_user = node['openstack']['identity']['user']
keystone_group = node['openstack']['identity']['group']

# install the database python adapter packages for the selected database
# service_type
db_type = node['openstack']['db']['identity']['service_type']
unless db_type == 'sqlite'
  node['openstack']['db']['python_packages'][db_type].each do |pkg|
    package "identity cookbook package #{pkg}" do
      package_name pkg
      options platform_options['package_options']
      action :upgrade
    end
  end
end

# install the python memcache adapter packages
platform_options['memcache_python_packages'].each do |pkg|
  package "identity cookbook package #{pkg}" do
    package_name pkg
    options platform_options['package_options']
    action :upgrade
  end
end

# install the keystone packages
platform_options['keystone_packages'].each do |pkg|
  package "identity cookbook package #{pkg}" do
    package_name pkg
    options platform_options['package_options']
    action :upgrade
  end
end

# stop and disable the service keystone itself, since it should be run inside
# of apache
service 'keystone' do
  service_name platform_options['keystone_service']
  action [:stop, :disable]
end

# disable default keystone config file from UCA package
apache2_site platform_options['keystone_apache2_site'] do
  action :disable
  only_if { platform_family?('debian') }
end

# create the keystone config directory and set correct permissions
directory '/etc/keystone' do
  owner keystone_user
  group keystone_group
  mode '700'
end

# create keystone domain config dir if needed
directory node['openstack']['identity']['domain_config_dir'] do
  owner keystone_user
  group keystone_group
  mode '700'
  only_if { node['openstack']['identity']['domain_specific_drivers_enabled'] }
end

# delete the keystone.db sqlite file if another db backend is used
file '/var/lib/keystone/keystone.db' do
  action :delete
  not_if { node['openstack']['db']['identity']['service_type'] == 'sqlite' }
end

# include the recipes to setup tokens
include_recipe 'openstack-identity::_fernet_tokens'
include_recipe 'openstack-identity::_credential_tokens'

# define the address to bind the keystone apache public service to
bind_service = node['openstack']['bind_service']['public']['identity']
bind_address = bind_address bind_service

# set the keystone database credentials
db_user = node['openstack']['db']['identity']['username']
db_pass = get_password 'db', 'keystone'
node.default['openstack']['identity']['conf_secrets']
.[]('database')['connection'] =
  db_uri('identity', db_user, db_pass)

# search for memcache servers using the method from cookbook-openstack-common
memcache_servers = memcached_servers.join ','

# If a keystone-paste.ini is specified use it.
# TODO(jh): Starting with Rocky keystone-paste.ini is no longer being used
# and this block can be removed
if node['openstack']['identity']['pastefile_url']
  remote_file '/etc/keystone/keystone-paste.ini' do
    action :create_if_missing
    source node['openstack']['identity']['pastefile_url']
    owner keystone_user
    group keystone_group
    mode '644'
  end
else
  template '/etc/keystone/keystone-paste.ini' do
    source 'keystone-paste.ini.erb'
    owner keystone_user
    group keystone_group
    mode '644'
  end
end

# set keystone config parameter for rabbitmq if rabbit is the rpc_backend
if node['openstack']['mq']['service_type'] == 'rabbit'
  node.default['openstack']['identity']['conf_secrets']['DEFAULT']['transport_url'] = rabbit_transport_url 'identity'
end

# set keystone config parameters for endpoints, memcache
node.default['openstack']['identity']['conf'].tap do |conf|
  conf['DEFAULT']['public_endpoint'] = api_endpoint
  conf['memcache']['servers'] = memcache_servers if memcache_servers
end

# merge all config options and secrets to be used in the keystone.conf.erb
keystone_conf_options = merge_config_options 'identity'

# create the keystone.conf from attributes
template '/etc/keystone/keystone.conf' do
  source 'openstack-service.conf.erb'
  cookbook 'openstack-common'
  owner keystone_user
  group keystone_group
  mode '640'
  sensitive true
  variables(
    service_config: keystone_conf_options
  )
  notifies :restart, 'service[apache2]'
end

# delete all secrets saved in the attribute
# node['openstack']['identity']['conf_secrets'] after creating the keystone.conf
ruby_block "delete all attributes in node['openstack']['identity']['conf_secrets']" do
  block do
    node.rm(:openstack, :identity, :conf_secrets)
  end
end

# sync db after keystone.conf is generated
execute 'keystone-manage db_sync' do
  user 'root'
  only_if { node['openstack']['db']['identity']['migrate'] }
end

# bootstrap keystone after keystone.conf is generated
# TODO(frickler): drop admin endpoint once keystonemiddleware is fixed
execute 'bootstrap_keystone' do
  command "keystone-manage bootstrap \\
          --bootstrap-password #{admin_pass} \\
          --bootstrap-username #{admin_user} \\
          --bootstrap-project-name #{admin_project} \\
          --bootstrap-role-name #{admin_role} \\
          --bootstrap-service-name keystone \\
          --bootstrap-region-id #{region} \\
          --bootstrap-admin-url #{identity_internal_endpoint} \\
          --bootstrap-public-url #{identity_endpoint} \\
          --bootstrap-internal-url #{identity_internal_endpoint}"
  sensitive true
end

#### Start of Apache specific work

# service['apache2'] is defined in the apache2_default_install resource
# but other resources are currently unable to reference it.  To work
# around this issue, define the following helper in your cookbook:
service 'apache2' do
  extend Apache2::Cookbook::Helpers
  service_name lazy { apache_platform_service_name }
  supports restart: true, status: true, reload: true
  action :nothing
end

apache2_install 'openstack' do
  listen "#{bind_address}:#{bind_service['port']}"
end

apache2_mod_wsgi 'openstack'
apache2_module 'ssl' if node['openstack']['identity']['ssl']['enabled']

# create the keystone apache directory
keystone_apache_dir = "#{default_docroot_dir}/keystone"
directory keystone_apache_dir do
  owner 'root'
  group 'root'
  mode '755'
end

# create the keystone apache config using template
template "#{apache_dir}/sites-available/identity.conf" do
  extend Apache2::Cookbook::Helpers
  source 'wsgi-keystone.conf.erb'
  variables(
    server_host: bind_address,
    server_port: bind_service['port'],
    server_entry: '/usr/bin/keystone-wsgi-public',
    server_alias: 'identity',
    log_dir: default_log_dir,
    run_dir: lock_dir,
    user: keystone_user,
    group: keystone_group
  )
  notifies :restart, 'service[apache2]'
end

apache2_site 'identity' do
  notifies :restart, 'service[apache2]', :immediately
end
