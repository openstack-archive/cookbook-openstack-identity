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
#

require 'uri'

class ::Chef::Recipe
  include ::Openstack
end

identity_admin_endpoint = admin_endpoint 'identity'
identity_internal_endpoint = internal_endpoint 'identity'
identity_public_endpoint = public_endpoint 'identity'
auth_uri = ::URI.decode identity_admin_endpoint.to_s

admin_tenant_name = node['openstack']['identity']['admin_tenant_name']
admin_user = node['openstack']['identity']['admin_user']
admin_pass = get_password 'user', node['openstack']['identity']['admin_user']

bootstrap_token = get_password 'token', 'openstack_identity_bootstrap_token'

# Register all the tenants specified in the users hash
identity_tenants = node['openstack']['identity']['users'].values.map do |user_info|
  user_info['roles'].values.push(user_info['default_tenant'])
end

identity_tenants.flatten.uniq.each do |tenant_name|
  openstack_identity_register "Register '#{tenant_name}' Tenant" do
    auth_uri auth_uri
    bootstrap_token bootstrap_token
    tenant_name tenant_name
    tenant_description "#{tenant_name} Tenant"

    action :create_tenant
  end
end

# Register all the roles from the users hash
identity_roles = node['openstack']['identity']['users'].values.map do |user_info|
  user_info['roles'].keys
end

identity_roles.flatten.uniq.each do |role_name|
  openstack_identity_register "Register '#{role_name}' Role" do
    auth_uri auth_uri
    bootstrap_token bootstrap_token
    role_name role_name

    action :create_role
  end
end

node['openstack']['identity']['users'].each do |username, user_info|
  pwd = get_password 'user', username
  openstack_identity_register "Register '#{username}' User" do
    auth_uri auth_uri
    bootstrap_token bootstrap_token
    user_name username
    user_pass pwd
    tenant_name user_info['default_tenant']
    user_enabled true # Not required as this is the default

    action :create_user
  end

  user_info['roles'].each do |rolename, tenant_list|
    tenant_list.each do |tenantname|
      openstack_identity_register "Grant '#{rolename}' Role to '#{username}' User in '#{tenantname}' Tenant" do
        auth_uri auth_uri
        bootstrap_token bootstrap_token
        user_name username
        role_name rolename
        tenant_name tenantname

        action :grant_role
      end
    end
  end
end

openstack_identity_register 'Register Identity Service' do
  auth_uri auth_uri
  bootstrap_token bootstrap_token
  service_name 'keystone'
  service_type 'identity'
  service_description 'Keystone Identity Service'

  action :create_service
  not_if { node['openstack']['identity']['catalog']['backend'] == 'templated' }
end

node.set['openstack']['identity']['adminURL'] = identity_admin_endpoint.to_s
node.set['openstack']['identity']['internalURL'] = identity_internal_endpoint.to_s
node.set['openstack']['identity']['publicURL'] = identity_public_endpoint.to_s

Chef::Log.info "Keystone AdminURL: #{identity_admin_endpoint}"
Chef::Log.info "Keystone InternalURL: #{identity_internal_endpoint}"
Chef::Log.info "Keystone PublicURL: #{identity_public_endpoint}"

openstack_identity_register 'Register Identity Endpoint' do
  auth_uri auth_uri
  bootstrap_token bootstrap_token
  service_type 'identity'
  endpoint_region node['openstack']['identity']['region']
  endpoint_adminurl node['openstack']['identity']['adminURL']
  endpoint_internalurl node['openstack']['identity']['internalURL']
  endpoint_publicurl node['openstack']['identity']['publicURL']

  action :create_endpoint
  not_if { node['openstack']['identity']['catalog']['backend'] == 'templated' }
end

node['openstack']['identity']['users'].each do |username, user_info|
  openstack_identity_register "Create EC2 credentials for '#{username}' user" do
    auth_uri auth_uri
    bootstrap_token bootstrap_token
    user_name username
    tenant_name user_info['default_tenant']
    admin_tenant_name admin_tenant_name
    admin_user admin_user
    admin_pass admin_pass

    action :create_ec2_credentials
  end
end
