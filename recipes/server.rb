#
# Cookbook Name:: keystone
# Recipe:: server
#
# Copyright 2012, Rackspace US, Inc.
# Copyright 2012, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "uri"

class ::Chef::Recipe
  include ::Openstack
end

platform_options = node["keystone"]["platform"]

##### NOTE #####
# https://bugs.launchpad.net/ubuntu/+source/keystone/+bug/931236
################

platform_options["mysql_python_packages"].each do |pkg|
  package pkg do
    action :install
  end
end

platform_options["keystone_packages"].each do |pkg|
  package pkg do
    options platform_options["package_options"]

    action :upgrade
  end
end

execute "Keystone: sleep" do
  command "sleep 10s"

  action :nothing
end

service "keystone" do
  service_name platform_options["keystone_service"]
  supports :status => true, :restart => true

  action [ :enable ]

  notifies :run, "execute[Keystone: sleep]", :immediately
end

directory "/etc/keystone" do
  owner node['keystone']['user']
  group node['keystone']['group']
  mode  00700

  action :create
end

file "/var/lib/keystone/keystone.db" do
  action :delete
end

execute "keystone-manage db_sync" do
  command "keystone-manage db_sync"

  action :nothing
end

execute "keystone-manage pki_setup" do
  command "keystone-manage pki_setup"

  action :nothing
  not_if { node["keystone"]["signing"]["token_format"] == "UUID" }
end

identity_admin_endpoint = endpoint "identity-admin"
identity_endpoint = endpoint "identity-api"

admin_tenant_name = node["keystone"]["admin_tenant_name"]
admin_user = node["keystone"]["admin_user"]
admin_pass = user_password node["keystone"]["admin_user"]
auth_uri = ::URI.decode identity_admin_endpoint.to_s

db_user = node["keystone"]["db"]["username"]
db_pass = db_password "keystone"
sql_connection = db_uri("identity", db_user, db_pass)

bootstrap_token = secret "secrets", "keystone_bootstrap_token"

bind_interface = node["keystone"]["bind_interface"]
interface_node = node["network"]["interfaces"][bind_interface]["addresses"]
ip_address = interface_node.select do |address, data|
  data['family'] == "inet"
end[0][0]

template "/etc/keystone/keystone.conf" do
  source "keystone.conf.erb"
  owner node["keystone"]["user"]
  group node["keystone"]["group"]
  mode   00644
  variables(
    :sql_connection => sql_connection,
    :ip_address => ip_address,
    "bootstrap_token" => bootstrap_token
  )

  notifies :run, "execute[keystone-manage db_sync]", :immediately
  notifies :run, "execute[keystone-manage pki_setup]", :immediately
  notifies :restart, "service[keystone]", :immediately
end

template "/etc/keystone/logging.conf" do
  source "keystone-logging.conf.erb"
  owner node["keystone"]["user"]
  group node["keystone"]["group"]
  mode   00644

  notifies :restart, "service[keystone]", :immediately
end

# We need to bootstrap the keystone admin user so that calls
# to keystone_register will succeed, since those provider calls
# use the admin tenant/user/pass to get an admin token.
bash "bootstrap-keystone-admin" do
  # A shortcut bootstrap command was added to python-keystoneclient
  # in early Grizzly timeframe... but we need to do all the commands
  # here manually since the python-keystoneclient package included
  # in CloudArchive (for now) doesn't have it...
  #command "keystone bootstrap --os-token=#{bootstrap_token} --user-name=#{admin_user} --tenant-name=#{admin_tenant_name} --pass=#{admin_pass}"
  base_ks_cmd = "keystone --endpoint=#{auth_uri} --token=#{bootstrap_token}"
  code <<-EOF
set -x
function get_id () {
    echo `"$@" | grep ' id ' | awk '{print $4}'`
}
#{base_ks_cmd} tenant-list | grep #{admin_tenant_name}
if [[ $? -eq 1 ]]; then
  ADMIN_TENANT=$(get_id #{base_ks_cmd} tenant-create --name=#{admin_tenant_name})
else
  ADMIN_TENANT=$(#{base_ks_cmd} tenant-list | grep #{admin_tenant_name} | awk '{print $2}')
fi
#{base_ks_cmd} role-list | grep admin
if [[ $? -eq 1 ]]; then
  ADMIN_ROLE=$(get_id #{base_ks_cmd} role-create --name=admin)
else
  ADMIN_ROLE=$(#{base_ks_cmd} role-list | grep admin | awk '{print $2}')
fi
#{base_ks_cmd} user-list | grep #{admin_user}
if [[ $? -eq 1 ]]; then
  ADMIN_USER=$(get_id #{base_ks_cmd} user-create --name=#{admin_user} --pass="#{admin_pass}" --email=#{admin_user}@example.com)
else
  ADMIN_USER=$(#{base_ks_cmd} user-list | grep #{admin_user} | awk '{print $2}')
fi
#{base_ks_cmd} user-role-list --user-id=$ADMIN_USER --tenant-id=$ADMIN_TENANT | grep admin
if [[ $? -eq 1 ]]; then
  #{base_ks_cmd} user-role-add --user-id $ADMIN_USER --role-id $ADMIN_ROLE --tenant-id $ADMIN_TENANT
fi
exit 0
EOF
end

#TODO(shep): this should probably be derived from keystone.users hash keys
node["keystone"]["tenants"].each do |tenant_name|
  ## Add openstack tenant ##
  keystone_register "Register '#{tenant_name}' Tenant" do
    auth_uri auth_uri
    admin_user admin_user
    admin_tenant_name admin_tenant_name
    admin_password admin_pass
    tenant_name tenant_name
    tenant_description "#{tenant_name} Tenant"
    tenant_enabled "true" # Not required as this is the default
    action :create_tenant
  end
end

## Add Roles ##

node["keystone"]["roles"].each do |role_key|
  keystone_register "Register '#{role_key.to_s}' Role" do
    auth_uri auth_uri
    admin_user admin_user
    admin_tenant_name admin_tenant_name
    admin_password admin_pass
    role_name role_key

    action :create_role
  end
end

node["keystone"]["users"].each do |username, user_info|
  keystone_register "Register '#{username}' User" do
    auth_uri auth_uri
    admin_user admin_user
    admin_tenant_name admin_tenant_name
    admin_password admin_pass
    user_name username
    user_pass user_info["password"]
    tenant_name user_info["default_tenant"]
    user_enabled "true" # Not required as this is the default

    action :create_user
  end

  user_info["roles"].each do |rolename, tenant_list|
    tenant_list.each do |tenantname|
      keystone_register "Grant '#{rolename}' Role to '#{username}' User in '#{tenantname}' Tenant" do
        auth_uri auth_uri
        admin_user admin_user
        admin_tenant_name admin_tenant_name
        admin_password admin_pass
        user_name username
        role_name rolename
        tenant_name tenantname

        action :grant_role
      end
    end
  end
end

## Add Services ##

keystone_register "Register Identity Service" do
  auth_uri auth_uri
  admin_user admin_user
  admin_tenant_name admin_tenant_name
  admin_password admin_pass
  service_name "keystone"
  service_type "identity"
  service_description "Keystone Identity Service"

  action :create_service
end

## Add Endpoints ##

node.set["keystone"]["adminURL"] = identity_admin_endpoint.to_s
node.set["keystone"]["internalURL"] = identity_admin_endpoint.to_s
node.set["keystone"]["publicURL"] = identity_endpoint.to_s

Chef::Log.info "Keystone AdminURL: #{identity_admin_endpoint.to_s}"
Chef::Log.info "Keystone InternalURL: #{identity_admin_endpoint.to_s}"
Chef::Log.info "Keystone PublicURL: #{identity_endpoint.to_s}"

keystone_register "Register Identity Endpoint" do
  auth_uri auth_uri
  admin_user admin_user
  admin_tenant_name admin_tenant_name
  admin_password admin_pass
  service_type "identity"
  endpoint_region node["keystone"]["region"]
  endpoint_adminurl node["keystone"]["adminURL"]
  endpoint_internalurl node["keystone"]["adminURL"]
  endpoint_publicurl node["keystone"]["publicURL"]

  action :create_endpoint
end

node["keystone"]["users"].each do |username, user_info|
  keystone_credentials "Create EC2 credentials for '#{username}' user" do
    auth_uri auth_uri
    admin_user admin_user
    admin_tenant_name admin_tenant_name
    admin_password admin_pass
    user_name username
    tenant_name user_info["default_tenant"]
  end
end
