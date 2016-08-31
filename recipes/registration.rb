# encoding: UTF-8
#
# Cookbook Name:: openstack-identity
# Recipe:: setup
#
# Copyright 2012, Rackspace US, Inc.
# Copyright 2012-2013, Opscode, Inc.
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

# This recipe registers the initial keystone endpoint as well as users, tenants
# and roles needed for the initial configuration utilizing the LWRP provided
# inside of this cookbook. The recipe is documented in detail with inline
# comments inside the recipe.

require 'uri'
require 'chef/mixin/shell_out'

class ::Chef::Recipe
  include ::Openstack
end

identity_admin_endpoint = admin_endpoint 'identity'
identity_internal_endpoint = internal_endpoint 'identity'
identity_public_endpoint = public_endpoint 'identity'
auth_url = ::URI.decode identity_admin_endpoint.to_s

# define the credentials to use for the initial admin user
admin_project = node['openstack']['identity']['admin_project']
admin_user = node['openstack']['identity']['admin_user']
admin_pass = get_password 'user', node['openstack']['identity']['admin_user']
admin_role = node['openstack']['identity']['admin_role']
admin_domain = node['openstack']['identity']['admin_domain_name']
region = node['openstack']['identity']['region']

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

connection_params = {
  openstack_auth_url:     "#{auth_url}/auth/tokens",
  openstack_username:     admin_user,
  openstack_api_key:      admin_pass,
  openstack_project_name: admin_project,
  openstack_domain_name:    admin_domain
}

openstack_domain admin_domain do
  connection_params connection_params
end

openstack_user admin_user do
  domain_name admin_domain
  role_name admin_role
  connection_params connection_params
  action :grant_domain
end

# create default service role
openstack_role 'service' do
  connection_params connection_params
end

# create default role for horizon dashboard login
openstack_role '_member_' do
  connection_params connection_params
end

node.set['openstack']['identity']['adminURL'] = identity_admin_endpoint.to_s
node.set['openstack']['identity']['internalURL'] = identity_internal_endpoint.to_s
node.set['openstack']['identity']['publicURL'] = identity_public_endpoint.to_s

Chef::Log.info "Keystone AdminURL: #{identity_admin_endpoint}"
Chef::Log.info "Keystone InternalURL: #{identity_internal_endpoint}"
Chef::Log.info "Keystone PublicURL: #{identity_public_endpoint}"
