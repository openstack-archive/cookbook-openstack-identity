# encoding: UTF-8
#
# Cookbook Name:: openstack-identity
# Provider:: register
#
# Copyright 2012, Rackspace US, Inc.
# Copyright 2012-2013, AT&T Services, Inc.
# Copyright 2013, Opscode, Inc.
# Copyright 2013, Craig Tracey <craigtracey@gmail.com>
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

require 'chef/mixin/shell_out'
include Chef::Mixin::ShellOut
include ::Openstack

private

def generate_boot_creds(resource)
  {
    'OS_SERVICE_ENDPOINT' => resource.auth_uri,
    'OS_SERVICE_TOKEN' => resource.bootstrap_token
  }
end

private

def generate_admin_creds(resource)
  identity_endpoint = resource.identity_endpoint
  identity_endpoint = endpoint('identity-admin').to_s unless identity_endpoint
  {
    'OS_USERNAME' => resource.admin_user,
    'OS_PASSWORD' => resource.admin_pass,
    'OS_TENANT_NAME' => resource.admin_tenant_name,
    'OS_AUTH_URL' => identity_endpoint
  }
end

private

def generate_user_creds(resource)
  identity_endpoint = resource.identity_endpoint
  identity_endpoint = endpoint('identity-api').to_s unless identity_endpoint
  {
    'OS_USERNAME' => resource.user_name,
    'OS_PASSWORD' => resource.user_pass,
    'OS_TENANT_NAME' => resource.tenant_name,
    'OS_AUTH_URL' => identity_endpoint
  }
end

private

def get_env(resource, env = 'boot')
  case env
  when 'boot'
    generate_boot_creds(resource)
  when 'user'
    generate_user_creds(resource)
  when 'admin'
    generate_admin_creds(resource)
  end
end

private

def identity_command(resource, cmd, args = {}, env = 'boot')
  keystonecmd = ['keystone'] << '--insecure' << cmd
  args.each do |key, val|
    keystonecmd << "--#{key}" unless key.empty?
    keystonecmd << val.to_s
  end
  cmd_env = get_env(resource, env)
  Chef::Log.debug("Running identity command: #{keystonecmd} env: " + cmd_env.to_s)
  rc = shell_out(keystonecmd, env: cmd_env)
  fail "#{rc.stderr} (#{rc.exitstatus})" if rc.exitstatus != 0
  rc.stdout
end

private

def identity_uuid(resource, type, key, value, args = {}, uuid_field = 'id')  # rubocop: disable ParameterLists
  rc = nil
  begin
    output = identity_command resource, "#{type}-list", args
    output = prettytable_to_array(output)
    rc = (type == 'endpoint') ? (search_uuid(output, uuid_field, key => value, 'region' => resource.endpoint_region)) : (search_uuid(output, uuid_field, key => value))
  rescue RuntimeError => e
    raise "Could not lookup uuid for #{type}:#{key}=>#{value}. Error was #{e.message}"
  end
  rc
end

private

def search_uuid(output, uuid_field, required_hash = {})
  rc = nil
  output.each do |obj|
    rc = obj[uuid_field] if obj.key?(uuid_field) && required_hash.values - obj.values_at(*required_hash.keys) == []
  end
  rc
end

private

def service_need_updated?(resource, args = {}, uuid_field = 'id')
  begin
    output = identity_command resource, 'service-list', args
    output = prettytable_to_array(output)
    return search_uuid(output, uuid_field, 'name' => resource.service_name).nil?
  rescue RuntimeError => e
    raise "Could not check service attributes for service: type => #{resource.service_type}, name => #{resource.service_name}. Error was #{e.message}"
  end
  false
end

private

def endpoint_need_updated?(resource, key, value, args = {}, uuid_field = 'id')
  begin
    output = identity_command resource, 'endpoint-list', args
    output = prettytable_to_array(output)
    return search_uuid(output, uuid_field, key => value, 'region' => resource.endpoint_region, 'publicurl' => resource.endpoint_publicurl, 'internalurl' => resource.endpoint_internalurl, 'adminurl' => resource.endpoint_adminurl).nil?
  rescue RuntimeError => e
    raise "Could not check endpoint attributes for endpoint:#{key}=>#{value}. Error was #{e.message}"
  end
  false
end

action :create_service do
  new_resource.updated_by_last_action(false)
  if node['openstack']['identity']['catalog']['backend'] == 'templated'
    Chef::Log.info('Skipping service creation - templated catalog backend in use.')
  else
    begin
      service_uuid = identity_uuid new_resource, 'service', 'type', new_resource.service_type
      need_updated = false
      if service_uuid
        Chef::Log.info("Service Type '#{new_resource.service_type}' already exists..")
        Chef::Log.info("Service UUID: #{service_uuid}")
        need_updated = service_need_updated? new_resource
        if need_updated
          Chef::Log.info("Service Type '#{new_resource.service_type}' needs to be updated, delete it first.")
          identity_command(new_resource, 'service-delete',
                           '' => service_uuid)
        end
      end
      unless service_uuid && !need_updated
        identity_command(new_resource, 'service-create',
                         'type' => new_resource.service_type,
                         'name' => new_resource.service_name,
                         'description' => new_resource.service_description)
        Chef::Log.info("Created service '#{new_resource.service_name}'")
        new_resource.updated_by_last_action(true)
      end
    rescue StandardError => e
      raise "Unable to create service '#{new_resource.service_name}' Error:" + e.message
    end
  end
end

action :create_endpoint do
  new_resource.updated_by_last_action(false)
  if node['openstack']['identity']['catalog']['backend'] == 'templated'
    Chef::Log.info('Skipping endpoint creation - templated catalog backend in use.')
  else
    begin
      service_uuid = identity_uuid new_resource, 'service', 'type', new_resource.service_type
      fail "Unable to find service type '#{new_resource.service_type}'" unless service_uuid

      endpoint_uuid = identity_uuid new_resource, 'endpoint', 'service_id', service_uuid
      need_updated = false
      if endpoint_uuid
        Chef::Log.info("Endpoint already exists for Service Type '#{new_resource.service_type}'.")
        need_updated = endpoint_need_updated? new_resource, 'service_id', service_uuid
        if need_updated
          Chef::Log.info("Endpoint for Service Type '#{new_resource.service_type}' needs to be updated, delete it first.")
          identity_command(new_resource, 'endpoint-delete',
                           '' => endpoint_uuid)
        end
      end
      unless endpoint_uuid && !need_updated
        identity_command(new_resource, 'endpoint-create',
                         'region' => new_resource.endpoint_region,
                         'service_id' => service_uuid,
                         'publicurl' => new_resource.endpoint_publicurl,
                         'internalurl' => new_resource.endpoint_internalurl,
                         'adminurl' => new_resource.endpoint_adminurl)
        Chef::Log.info("Created endpoint for service type '#{new_resource.service_type}'")
        new_resource.updated_by_last_action(true)
      end
    rescue StandardError => e
      raise "Unable to create endpoint for service type '#{new_resource.service_type}' Error: " + e.message
    end
  end
end

action :create_tenant do
  begin
    new_resource.updated_by_last_action(false)
    tenant_uuid = identity_uuid new_resource, 'tenant', 'name', new_resource.tenant_name

    if tenant_uuid
      Chef::Log.info("Tenant '#{new_resource.tenant_name}' already exists.. Not creating.")
      Chef::Log.info("Tenant UUID: #{tenant_uuid}") if tenant_uuid
    else
      identity_command(new_resource, 'tenant-create',
                       'name' => new_resource.tenant_name,
                       'description' => new_resource.tenant_description,
                       'enabled' => new_resource.tenant_enabled)
      Chef::Log.info("Created tenant '#{new_resource.tenant_name}'")
      new_resource.updated_by_last_action(true)
    end
  rescue StandardError => e
    raise "Unable to create tenant '#{new_resource.tenant_name}' Error: " + e.message
  end
end

action :create_role do
  begin
    new_resource.updated_by_last_action(false)
    role_uuid = identity_uuid new_resource, 'role', 'name', new_resource.role_name

    if role_uuid
      Chef::Log.info("Role '#{new_resource.role_name}' already exists.. Not creating.")
      Chef::Log.info("Role UUID: #{role_uuid}")
    else
      identity_command(new_resource, 'role-create',
                       'name' => new_resource.role_name)
      Chef::Log.info("Created Role '#{new_resource.role_name}'")
      new_resource.updated_by_last_action(true)
    end
  rescue StandardError => e
    raise "Unable to create role '#{new_resource.role_name}' Error: " + e.message
  end
end

action :create_user do
  begin
    new_resource.updated_by_last_action(false)

    output = identity_command(new_resource, 'user-list')
    users = prettytable_to_array output
    user_found = false
    users.each do |user|
      user_found = true if user['name'] == new_resource.user_name
    end

    if user_found
      Chef::Log.info("User '#{new_resource.user_name}' already exists")
      begin
        # Check if password is already updated by getting a token
        identity_command(new_resource, 'token-get', {}, 'user')
      rescue StandardError => e
        Chef::Log.debug('Get token error:' + e.message)
        Chef::Log.info("Sync password for user '#{new_resource.user_name}'")
        identity_command(new_resource, 'user-password-update',
                         'pass' => new_resource.user_pass,
                         '' => new_resource.user_name)
        new_resource.updated_by_last_action(true)
      end
      next
    end

    identity_command(new_resource, 'user-create',
                     'name' => new_resource.user_name,
                     'tenant' => new_resource.tenant_name,
                     'pass' => new_resource.user_pass,
                     'enabled' => new_resource.user_enabled)
    Chef::Log.info("Created user '#{new_resource.user_name}' for tenant '#{new_resource.tenant_name}'")
    new_resource.updated_by_last_action(true)
  rescue StandardError => e
    raise "Unable to create user '#{new_resource.user_name}' for tenant '#{new_resource.tenant_name}' Error: " + e.message
  end
end

action :grant_role do
  begin
    new_resource.updated_by_last_action(false)

    role_uuid = identity_uuid new_resource, 'role', 'name', new_resource.role_name
    fail "Unable to find role '#{new_resource.role_name}'" unless role_uuid

    assigned_role_uuid = identity_uuid(new_resource, 'user-role', 'name',
                                       new_resource.role_name,
                                       'tenant' => new_resource.tenant_name,
                                       'user' => new_resource.user_name)
    if role_uuid == assigned_role_uuid
      Chef::Log.info("Role '#{new_resource.role_name}' already granted to User '#{new_resource.user_name}' in Tenant '#{new_resource.tenant_name}'")
    else
      identity_command(new_resource, 'user-role-add',
                       'tenant' => new_resource.tenant_name,
                       'role-id' => role_uuid,
                       'user' => new_resource.user_name)
      Chef::Log.info("Granted Role '#{new_resource.role_name}' to User '#{new_resource.user_name}' in Tenant '#{new_resource.tenant_name}'")
      new_resource.updated_by_last_action(true)
    end
  rescue StandardError => e
    raise "Unable to grant role '#{new_resource.role_name}' to user '#{new_resource.user_name}' Error: " + e.message
  end
end

action :create_ec2_credentials do
  begin
    new_resource.updated_by_last_action(false)
    tenant_uuid = identity_uuid new_resource, 'tenant', 'name', new_resource.tenant_name
    fail "Unable to find tenant '#{new_resource.tenant_name}'" unless tenant_uuid

    user_uuid = identity_uuid(new_resource, 'user', 'name',
                              new_resource.user_name,
                              'tenant-id' => tenant_uuid)
    fail "Unable to find user '#{new_resource.user_name}' with tenant '#{new_resource.tenant_name}'" unless user_uuid

    # this is not really a uuid, but this will work nonetheless
    access = identity_uuid new_resource, 'ec2-credentials', 'tenant', new_resource.tenant_name, { 'user-id' => user_uuid }, 'access'
    if access
      Chef::Log.info("EC2 credentials already exist for '#{new_resource.user_name}' in tenant '#{new_resource.tenant_name}'")
    else
      output = identity_command(new_resource, 'ec2-credentials-create',
                                { 'user-id' => user_uuid,
                                  'tenant-id' => tenant_uuid },
                                'admin')
      Chef::Log.info("Created EC2 Credentials for User '#{new_resource.user_name}' in Tenant '#{new_resource.tenant_name}'")
      data = prettytable_to_array(output)

      if data.length != 1
        fail "Got bad data when creating ec2 credentials for #{new_resource.user_name} Data: #{data}"
      else
        # Update node attributes
        node.set['credentials']['EC2'][new_resource.user_name]['access'] = data[0]['access']
        node.set['credentials']['EC2'][new_resource.user_name]['secret'] = data[0]['secret']
        node.save unless Chef::Config[:solo]
        new_resource.updated_by_last_action(true)
      end
    end
  rescue StandardError => e
    raise "Unable to create EC2 Credentials for User '#{new_resource.user_name}' in Tenant '#{new_resource.tenant_name}' Error: " + e.message
  end
end
