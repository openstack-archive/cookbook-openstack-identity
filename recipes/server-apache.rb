# encoding: UTF-8
#
# Cookbook Name:: openstack-identity
# Recipe:: server-apache
#
# Copyright 2015, IBM Corp. Inc.
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

require 'uri'

# load the methods defined in cookbook-openstack-common libraries
class ::Chef::Recipe
  include ::Openstack
end

# Workaround lifted from openstack-dashboard::apache2-server to install apache2
# on a RHEL-ish machine with SELinux set to enforcing.
#
# TODO(sc): once apache2 is in a place to allow for subscribes to web_app,
#           this workaround should go away
#
execute 'set-selinux-permissive' do
  command '/sbin/setenforce Permissive'
  action :run

  only_if "[ ! -e /etc/httpd/conf/httpd.conf ] && [ -e /etc/redhat-release ] && [ $(/sbin/sestatus | grep -c '^Current mode:.*enforcing') -eq 1 ]"
end

# include the logging recipe from openstack-common if syslog usage is enbaled
if node['openstack']['identity']['syslog']['use']
  include_recipe 'openstack-common::logging'
end

platform_options = node['openstack']['identity']['platform']

identity_admin_endpoint = admin_endpoint 'identity'
identity_internal_endpoint = internal_endpoint 'identity'
identity_public_endpoint = public_endpoint 'identity'

# define the credentials to use for the initial admin user
admin_project = node['openstack']['identity']['admin_project']
admin_user = node['openstack']['identity']['admin_user']
admin_pass = get_password 'user', node['openstack']['identity']['admin_user']
admin_role = node['openstack']['identity']['admin_role']
region = node['openstack']['identity']['region']
keystone_user    = node['openstack']['identity']['user']
keystone_group   = node['openstack']['identity']['group']

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

# create the keystone config directory and set correct permissions
directory '/etc/keystone' do
  owner node['openstack']['identity']['user']
  group node['openstack']['identity']['group']
  mode 0o0700
end

# create keystone domain config dir if needed
directory node['openstack']['identity']['identity']['domain_config_dir'] do
  owner node['openstack']['identity']['user']
  group node['openstack']['identity']['group']
  mode 0o0700
  only_if { node['openstack']['identity']['identity']['domain_specific_drivers_enabled'] }
end

# delete the keystone.db sqlite file if another db backend is used
file '/var/lib/keystone/keystone.db' do
  action :delete
  not_if { node['openstack']['db']['identity']['service_type'] == 'sqlite' }
end

# include the recipe to setup fernet tokens
include_recipe 'openstack-identity::_fernet_tokens'

# initialize fernet tokens
execute 'fernet setup' do
  user 'root'
  command <<-EOH.gsub(/\s+/, ' ').strip!
        keystone-manage fernet_setup
      --keystone-user #{keystone_user}
      --keystone-group #{keystone_group}
  EOH
  notifies :run, 'execute[credential setup]', :immediately
end

execute 'credential setup' do
  user 'root'
  command <<-EOH.gsub(/\s+/, ' ').strip!
        keystone-manage credential_setup
      --keystone-user #{keystone_user}
      --keystone-group #{keystone_group}
  EOH
end

# define the address to bind the keystone apache main service to
main_bind_service = node['openstack']['bind_service']['main']['identity']
main_bind_address = bind_address main_bind_service
# define the address to bind the keystone apache admin service to
admin_bind_service = node['openstack']['bind_service']['admin']['identity']
admin_bind_address = bind_address admin_bind_service

# define the address where the keystone admin endpoint will be reachable
identity_admin_endpoint = admin_endpoint 'identity'

# set the keystone database credentials
db_user = node['openstack']['db']['identity']['username']
db_pass = get_password 'db', 'keystone'
node.default['openstack']['identity']['conf_secrets']
.[]('database')['connection'] =
  db_uri('identity', db_user, db_pass)

# search for memcache servers using the method from cookbook-openstack-common
memcache_servers = memcached_servers.join ','

# define the address where the keystone public endpoint will be reachable
identity_public_endpoint = public_endpoint 'identity'
ie = identity_public_endpoint
# define the keystone public endpoint full path
public_endpoint = "#{ie.scheme}://#{ie.host}:#{ie.port}/"
ae = identity_admin_endpoint
# define the keystone admin endpoint full path
admin_endpoint = "#{ae.scheme}://#{ae.host}:#{ae.port}/"

# If a keystone-paste.ini is specified use it.
# If platform_family is RHEL and we do not specify keystone-paste.ini,
# copy in /usr/share/keystone/keystone-dist-paste.ini since
# /etc/keystone/keystone-paste.ini is not packaged.
if node['openstack']['identity']['pastefile_url']
  remote_file '/etc/keystone/keystone-paste.ini' do
    action :create_if_missing
    source node['openstack']['identity']['pastefile_url']
    owner node['openstack']['identity']['user']
    group node['openstack']['identity']['group']
    mode 0o0644
  end
else
  template '/etc/keystone/keystone-paste.ini' do
    source 'keystone-paste.ini.erb'
    owner node['openstack']['identity']['user']
    group node['openstack']['identity']['group']
    mode 0o0644
  end
end

# set keystone config parameter for rabbitmq if rabbit is the rpc_backend
if node['openstack']['mq']['service_type'] == 'rabbit'
  node.default['openstack']['identity']['conf_secrets']['DEFAULT']['transport_url'] = rabbit_transport_url 'identity'
end

# set keystone config parameters for admin_token, endpoints and memcache
node.default['openstack']['identity']['conf'].tap do |conf|
  conf['DEFAULT']['public_endpoint'] = public_endpoint
  conf['DEFAULT']['admin_endpoint'] = admin_endpoint
  conf['memcache']['servers'] = memcache_servers if memcache_servers
end

# merge all config options and secrets to be used in the nova.conf.erb
keystone_conf_options = merge_config_options 'identity'

# create the keystone.conf from attributes
template '/etc/keystone/keystone.conf' do
  source 'openstack-service.conf.erb'
  cookbook 'openstack-common'
  owner node['openstack']['identity']['user']
  group node['openstack']['identity']['group']
  mode 0o0640
  variables(
    service_config: keystone_conf_options
  )
end

# delete all secrets saved in the attribute
# node['openstack']['identity']['conf_secrets'] after creating the keystone.conf
ruby_block "delete all attributes in node['openstack']['identity']['conf_secrets']" do
  block do
    node.rm(:openstack, :identity, :conf_secrets)
  end
end

# TODO: (jklare) needs to be refactored and filled by the service cookbooks, to
# avoid dependencies on unused cookbooks

# configure the endpoints in keystone_catalog.templates if the catalog backend
# is templated
if node['openstack']['identity']['catalog']['backend'] == 'templated'
  # These values are going into the templated catalog and
  # since they're the endpoints being used by the clients,
  # we should put in the public endpoints for each service.
  compute_public_endpoint = public_endpoint 'compute'
  ec2_public_endpoint = public_endpoint 'compute-ec2'
  image_public_endpoint = public_endpoint 'image'
  network_public_endpoint = public_endpoint 'network'
  volume_public_endpoint = public_endpoint 'block-storage'

  # populate the templated catlog
  # TODO: (jklare) this should be done in a helper method
  uris = {
    'identity-admin' => identity_admin_endpoint.to_s.gsub('%25', '%'),
    'identity' => identity_public_endpoint.to_s.gsub('%25', '%'),
    'image' => image_public_endpoint.to_s.gsub('%25', '%'),
    'compute' => compute_public_endpoint.to_s.gsub('%25', '%'),
    'ec2' => ec2_public_endpoint.to_s.gsub('%25', '%'),
    'network' => network_public_endpoint.to_s.gsub('%25', '%'),
    'volume' => volume_public_endpoint.to_s.gsub('%25', '%'),
  }

  template '/etc/keystone/default_catalog.templates' do
    source 'default_catalog.templates.erb'
    owner node['openstack']['identity']['user']
    group node['openstack']['identity']['group']
    mode 0o0644
    variables(
      uris: uris
    )
  end
end

# sync db after keystone.conf is generated
execute 'keystone-manage db_sync' do
  user 'root'
  only_if { node['openstack']['db']['identity']['migrate'] }
end

# bootstrap keystone after keystone.conf is generated
execute 'bootstrap_keystone' do
  command "keystone-manage bootstrap \\
          --bootstrap-password #{admin_pass} \\
          --bootstrap-username #{admin_user} \\
          --bootstrap-project-name #{admin_project} \\
          --bootstrap-role-name #{admin_role} \\
          --bootstrap-service-name keystone \\
          --bootstrap-region-id #{region} \\
          --bootstrap-admin-url #{identity_admin_endpoint} \\
          --bootstrap-public-url #{identity_public_endpoint} \\
          --bootstrap-internal-url #{identity_internal_endpoint}"
end

#### Start of Apache specific work

# configure attributes for apache2 cookbook to align with openstack settings
apache_listen = Array(node['apache']['listen']) # include already defined listen attributes
# Remove the default apache2 cookbook port, as that is also the default for horizon, but with
# a different address syntax.  *:80   vs  0.0.0.0:80
apache_listen -= ['*:80']
apache_listen += ["#{main_bind_address}:#{main_bind_service['port']}"]
apache_listen += ["#{admin_bind_address}:#{admin_bind_service['port']}"]
node.normal['apache']['listen'] = apache_listen.uniq

# include the apache2 default recipe and the recipes for mod_wsgi
include_recipe 'apache2'
include_recipe 'apache2::mod_wsgi'
# include the apache2 mod_ssl recipe if ssl is enabled for identity
include_recipe 'apache2::mod_ssl' if node['openstack']['identity']['ssl']['enabled']

# create the keystone apache directory
keystone_apache_dir = "#{node['apache']['docroot_dir']}/keystone"
directory keystone_apache_dir do
  owner 'root'
  group 'root'
  mode 0o0755
end

wsgi_apps = {
  'main' => {
    server_host: main_bind_address,
    server_port: main_bind_service['port'],
    server_entry: '/usr/bin/keystone-wsgi-public',
  },
  'admin' => {
    server_host: admin_bind_address,
    server_port: admin_bind_service['port'],
    server_entry: '/usr/bin/keystone-wsgi-admin',
  },
}

# create the keystone apache config using the web_app resource from the apache2
# cookbook
wsgi_apps.each do |app, opt|
  web_app "keystone-#{app}" do
    template 'wsgi-keystone.conf.erb'
    server_host opt[:server_host]
    server_port opt[:server_port]
    server_entry opt[:server_entry]
    server_suffix app
    log_dir node['apache']['log_dir']
    log_debug node['openstack']['identity']['debug']
    user node['openstack']['identity']['user']
    group node['openstack']['identity']['group']
    use_ssl node['openstack']['identity']['ssl']['enabled']
    cert_file node['openstack']['identity']['ssl']['certfile']
    chain_file node['openstack']['identity']['ssl']['chainfile']
    key_file node['openstack']['identity']['ssl']['keyfile']
    ca_certs_path node['openstack']['identity']['ssl']['ca_certs_path']
    cert_required node['openstack']['identity']['ssl']['cert_required']
    protocol node['openstack']['identity']['ssl']['protocol']
    ciphers node['openstack']['identity']['ssl']['ciphers']
  end
end

# disable keystone-site since ubuntu autoenables this
apache_site 'keystone' do
  enable false
end

# Hack until Apache cookbook has lwrp's for proper use of notify
# restart apache2 after keystone if completely configured
execute 'Keystone apache restart' do
  command 'uname'
  notifies :run, 'execute[restore-selinux-context]', :immediately
  notifies :restart, 'service[apache2]', :immediately
end

execute 'restore-selinux-context' do
  command 'restorecon -Rv /etc/httpd /etc/pki || :'
  action :nothing
  only_if { platform_family?('rhel') }
end
