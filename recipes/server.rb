# encoding: UTF-8
#
# Cookbook Name:: openstack-identity
# Recipe:: server
#
# Copyright 2012, Rackspace US, Inc.
# Copyright 2012-2013, Opscode, Inc.
# Copyright 2013 SUSE LINUX Products GmbH.
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
#

require 'uri'

class ::Chef::Recipe # rubocop:disable Documentation
  include ::Openstack
end

if node['openstack']['identity']['syslog']['use']
  include_recipe 'openstack-common::logging'
end

platform_options = node['openstack']['identity']['platform']

db_type = node['openstack']['db']['identity']['service_type']
unless db_type == 'sqlite'
  platform_options["#{db_type}_python_packages"].each do |pkg|
    package pkg do
      options platform_options['package_options']
      action :upgrade
    end
  end
end

platform_options['memcache_python_packages'].each do |pkg|
  package pkg do
    options platform_options['package_options']
    action :upgrade
  end
end

platform_options['keystone_packages'].each do |pkg|
  package pkg do
    options platform_options['package_options']
    action :upgrade
  end
end

execute 'Keystone: sleep' do
  command 'sleep 10s'

  action :nothing
end

service 'keystone' do
  service_name platform_options['keystone_service']
  supports status: true, restart: true

  action [:enable]

  notifies :run, 'execute[Keystone: sleep]', :immediately
end

directory '/etc/keystone' do
  owner node['openstack']['identity']['user']
  group node['openstack']['identity']['group']
  mode  00700
end

file '/var/lib/keystone/keystone.db' do
  action :delete
  not_if { node['openstack']['db']['identity']['service_type'] == 'sqlite' }
end

if node['openstack']['auth']['strategy'] == 'pki'
  certfile_url = node['openstack']['identity']['signing']['certfile_url']
  keyfile_url = node['openstack']['identity']['signing']['keyfile_url']
  ca_certs_url = node['openstack']['identity']['signing']['ca_certs_url']
  signing_basedir = node['openstack']['identity']['signing']['basedir']

  directory signing_basedir do
    owner node['openstack']['identity']['user']
    group node['openstack']['identity']['group']
    mode  00700
  end

  directory "#{signing_basedir}/certs" do
    owner node['openstack']['identity']['user']
    group node['openstack']['identity']['group']
    mode  00755
  end

  directory "#{signing_basedir}/private" do
    owner node['openstack']['identity']['user']
    group node['openstack']['identity']['group']
    mode  00750
  end

  if certfile_url.nil? || keyfile_url.nil? || ca_certs_url.nil?
    execute 'keystone-manage pki_setup' do
      user  node['openstack']['identity']['user']
      group node['openstack']['identity']['group']

      not_if { ::FileTest.exists? node['openstack']['identity']['signing']['keyfile'] }
    end
  else
    remote_file node['openstack']['identity']['signing']['certfile'] do
      source certfile_url
      owner  node['openstack']['identity']['user']
      group  node['openstack']['identity']['group']
      mode   00640

      notifies :restart, 'service[keystone]', :delayed
    end

    remote_file node['openstack']['identity']['signing']['keyfile'] do
      source keyfile_url
      owner  node['openstack']['identity']['user']
      group  node['openstack']['identity']['group']
      mode   00640

      notifies :restart, 'service[keystone]', :delayed
    end

    remote_file node['openstack']['identity']['signing']['ca_certs'] do
      source ca_certs_url
      owner  node['openstack']['identity']['user']
      group  node['openstack']['identity']['group']
      mode   00640

      notifies :restart, 'service[keystone]', :delayed
    end
  end
end

bind_endpoint = endpoint 'identity-bind'
identity_admin_endpoint = endpoint 'identity-admin'
identity_endpoint = endpoint 'identity-api'
compute_endpoint = endpoint 'compute-api'
ec2_endpoint = endpoint 'compute-ec2-api'
image_endpoint = endpoint 'image-api'
network_endpoint = endpoint 'network-api'
volume_endpoint = endpoint 'block-storage-api'

db_user = node['openstack']['db']['identity']['username']
db_pass = get_password 'db', 'keystone'
sql_connection = db_uri('identity', db_user, db_pass)

bootstrap_token = get_secret 'openstack_identity_bootstrap_token'

bind_address = bind_endpoint.host

# If the search role is set, we search for memcache
# servers via a Chef search. If not, we look at the
# memcache.servers attribute.
memcache_servers = memcached_servers.join ','  # from openstack-common lib

# These configuration endpoints must not have the path (v2.0, etc)
# added to them, as these values are used in returning the version
# listing information from the root / endpoint.
ie = identity_endpoint
public_endpoint = "#{ie.scheme}://#{ie.host}:#{ie.port}/"
ae = identity_admin_endpoint
admin_endpoint = "#{ae.scheme}://#{ae.host}:#{ae.port}/"

# If a keystone-paste.ini is specified use it.
# If platform_family is RHEL and we do not specify keystone-paste.ini,
# copy in /usr/share/keystone/keystone-dist-paste.ini since
# /etc/keystone/keystone-paste.ini is not packaged.
if node['openstack']['identity']['pastefile_url']
  remote_file '/etc/keystone/keystone-paste.ini' do
    source   node['openstack']['identity']['pastefile_url']
    owner    node['openstack']['identity']['user']
    group    node['openstack']['identity']['group']
    mode     00644
    notifies :restart, 'service[keystone]', :delayed
  end
else
  remote_file '/etc/keystone/keystone-paste.ini' do
    source   'file:////usr/share/keystone/keystone-dist-paste.ini'
    action   :create_if_missing
    owner    node['openstack']['identity']['user']
    group    node['openstack']['identity']['group']
    mode     00644
    notifies :restart, 'service[keystone]', :delayed
    only_if  { platform_family?('rhel') }
  end
end

template '/etc/keystone/keystone.conf' do
  source 'keystone.conf.erb'
  owner node['openstack']['identity']['user']
  group node['openstack']['identity']['group']
  mode   00644
  variables(
    sql_connection: sql_connection,
    bind_address: bind_address,
    bootstrap_token: bootstrap_token,
    memcache_servers: memcache_servers,
    public_endpoint: public_endpoint,
    public_port: identity_endpoint.port,
    admin_endpoint: admin_endpoint,
    admin_port: identity_admin_endpoint.port,
    ldap: node['openstack']['identity']['ldap'],
    token_expiration: node['openstack']['identity']['token']['expiration']
  )

  notifies :restart, 'service[keystone]', :immediately
end

# populate the templated catlog, if you're using the templated catalog backend
uris = {
  'identity-admin' => identity_admin_endpoint.to_s.gsub('%25', '%'),
  'identity' => identity_endpoint.to_s.gsub('%25', '%'),
  'image' => image_endpoint.to_s.gsub('%25', '%'),
  'compute' => compute_endpoint.to_s.gsub('%25', '%'),
  'ec2' => ec2_endpoint.to_s.gsub('%25', '%'),
  'network' => network_endpoint.to_s.gsub('%25', '%'),
  'volume' => volume_endpoint.to_s.gsub('%25', '%')
}

template '/etc/keystone/default_catalog.templates' do
  source 'default_catalog.templates.erb'
  owner node['openstack']['identity']['user']
  group node['openstack']['identity']['group']
  mode   00644
  variables(
    uris: uris
  )

  notifies :restart, 'service[keystone]', :immediately
  only_if { node['openstack']['identity']['catalog']['backend'] == 'templated' }
end

# sync db after keystone.conf is generated
execute 'keystone-manage db_sync' do
  user node['openstack']['identity']['user']
  group node['openstack']['identity']['group']

  only_if { node['openstack']['db']['identity']['migrate'] }
end

# Configure the flush tokens cronjob
should_run_cron = node['openstack']['identity']['token_flush_cron']['enabled'] && node['openstack']['identity']['token']['backend'] == 'sql'
log_file = node['openstack']['identity']['token_flush_cron']['log_file']

cron 'keystone-manage-token-flush' do
  minute node['openstack']['identity']['token_flush_cron']['minute']
  hour node['openstack']['identity']['token_flush_cron']['hour']
  day node['openstack']['identity']['token_flush_cron']['day']
  weekday node['openstack']['identity']['token_flush_cron']['weekday']
  action should_run_cron ? :create : :delete
  user node['openstack']['identity']['user']
  command %Q{
    `which keystone-manage` token_flush > #{log_file} 2>&1 &&
    echo keystone-manage token_flush ran at $(/bin/date) with exit code $? >> #{log_file}
  }.gsub!(/\n/, '')
end
# TODO(luisg): We can remove the \n substitution in the cron command when https://tickets.opscode.com/browse/CHEF-5238 is fixed
