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

connection_params = {
  openstack_auth_url:     "#{auth_url}/auth/tokens",
  openstack_username:     admin_user,
  openstack_api_key:      admin_pass,
  openstack_project_name: admin_project,
  openstack_domain_name:    admin_domain,
}

ruby_block 'wait for identity admin endpoint' do
  block do
    begin
      Timeout.timeout(60) do
        until Net::HTTP.get_response(URI(auth_url)).message == 'OK'
          Chef::Log.info 'waiting for identity admin endpoint to be up...'
          sleep 1
        end
      end
    rescue Timeout::Error
      raise 'Waited 60 seconds for identity admin endpoint to become ready'\
        ' and will not wait any longer'
    end
  end
end

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

node.normal['openstack']['identity']['adminURL'] = identity_admin_endpoint.to_s
node.normal['openstack']['identity']['internalURL'] = identity_internal_endpoint.to_s
node.normal['openstack']['identity']['publicURL'] = identity_public_endpoint.to_s

Chef::Log.info "Keystone AdminURL: #{identity_admin_endpoint}"
Chef::Log.info "Keystone InternalURL: #{identity_internal_endpoint}"
Chef::Log.info "Keystone PublicURL: #{identity_public_endpoint}"
