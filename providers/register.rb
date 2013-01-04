#
# Cookbook Name:: keystone
# Provider:: register
#
# Copyright 2012, Rackspace US, Inc.
# Copyright 2012, AT&T, Inc.
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

@cached_admin_token = nil

action :create_service do
    http = _new_http new_resource

    # lookup service_uuid
    service_container = "OS-KSADM:services"
    service_key = "type"
    service_path = "/OS-KSADM/services"
    service_uuid, service_error = _find_id(new_resource, http, service_path, service_container, service_key, new_resource.service_type)
    Chef::Log.error("There was an error looking up Service '#{new_resource.service_type}'") if service_error

    # See if the service exists yet
    unless service_uuid or service_error
        # Service does not exist yet
        payload = _build_service_object(new_resource.service_type, new_resource.service_name, new_resource.service_description)
        req = _http_post new_resource, service_path
        req.body = JSON.generate(payload)
        resp = http.request req
        if resp.is_a?(Net::HTTPOK)
            Chef::Log.info("Created service '#{new_resource.service_name}'")
            new_resource.updated_by_last_action(true)
        else
            Chef::Log.error("Unable to create service '#{new_resource.service_name}'")
            Chef::Log.error("Response Code: #{resp.code}")
            Chef::Log.error("Response Message: #{resp.message}")
            new_resource.updated_by_last_action(false)
        end
    else
        Chef::Log.info("Service Type '#{new_resource.service_type}' already exists.. Not creating.") if service_uuid
        Chef::Log.info("Service UUID: #{service_uuid}") if service_uuid
        Chef::Log.error("There was an error looking up '#{new_resource.role_name}'") if service_error
        new_resource.updated_by_last_action(false)
    end
end


action :create_endpoint do
    http = _new_http new_resource

    # lookup service_uuid
    service_container = "OS-KSADM:services"
    service_key = "type"
    service_path = "/OS-KSADM/services"
    service_uuid, service_error = _find_id(new_resource, http, service_path, service_container, service_key, new_resource.service_type)
    Chef::Log.error("There was an error looking up Service '#{new_resource.service_type}'") if service_error

    unless service_uuid or service_error
        Chef::Log.error("Unable to find service type '#{new_resource.service_type}'")
        new_resource.updated_by_last_action(false)
    end

    # Construct the extension path
    path = "/endpoints"
    req = _http_get new_resource, path

    # Make sure this endpoint does not already exist
    resp = http.request req
    if resp.is_a?(Net::HTTPOK)
        endpoint_exists = false
        data = JSON.parse(resp.body)
        data['endpoints'].each do |endpoint|
            if endpoint['service_id'] == service_uuid
                # Match found
                endpoint_exists = true
                break
            end
        end
        if endpoint_exists
            Chef::Log.info("Endpoint already exists for Service Type '#{new_resource.service_type}' already exists.. Not creating.")
            new_resource.updated_by_last_action(false)
        else
            payload = _build_endpoint_object(
                      new_resource.endpoint_region,
                      service_uuid,
                      new_resource.endpoint_publicurl,
                      new_resource.endpoint_internalurl,
                      new_resource.endpoint_adminurl)
            req = _http_post new_resource, path
            req.body = JSON.generate(payload)
            resp = http.request req
            if resp.is_a?(Net::HTTPOK)
                Chef::Log.info("Created endpoint for service type '#{new_resource.service_type}'")
                new_resource.updated_by_last_action(true)
            else
                Chef::Log.error("Unable to create endpoint for service type '#{new_resource.service_type}'")
                Chef::Log.error("Response Code: #{resp.code}")
                Chef::Log.error("Response Message: #{resp.message}")
                new_resource.updated_by_last_action(false)
            end
        end
    else
        Chef::Log.error("Unknown response from the Keystone Server")
        Chef::Log.error("Response Code: #{resp.code}")
        Chef::Log.error("Response Message: #{resp.message}")
        new_resource.updated_by_last_action(false)
    end
end

action :create_tenant do
    http = _new_http new_resource

    # lookup tenant_uuid
    tenant_container = "tenants"
    tenant_key = "name"
    tenant_path = "/tenants"
    tenant_uuid, tenant_error = _find_id(new_resource, http, tenant_path, tenant_container, tenant_key, new_resource.tenant_name)
    Chef::Log.error("There was an error looking up Tenant '#{new_resource.tenant_name}'") if tenant_error

    unless tenant_uuid or tenant_error
        # Service does not exist yet
        payload = _build_tenant_object(new_resource.tenant_name, new_resource.service_description, new_resource.tenant_enabled)

        # Construct the extension path
        path = "/tenants"
        req = _http_post new_resource, path
        req.body = JSON.generate(payload)
        resp = http.request req
        if resp.is_a?(Net::HTTPOK)
            Chef::Log.info("Created tenant '#{new_resource.tenant_name}'")
            new_resource.updated_by_last_action(true)
        else
            Chef::Log.error("Unable to create tenant '#{new_resource.tenant_name}'")
            Chef::Log.error("Response Code: #{resp.code}")
            Chef::Log.error("Response Message: #{resp.message}")
            new_resource.updated_by_last_action(false)
        end
    else
        Chef::Log.info("Tenant '#{new_resource.tenant_name}' already exists.. Not creating.")
        Chef::Log.info("Tenant UUID: #{tenant_uuid}")
        Chef::Log.error("There was an error looking up '#{new_resource.role_name}'") if tenant_error
        new_resource.updated_by_last_action(false)
    end
end

action :create_role do
    http = _new_http new_resource

    # Construct the extension path
    path = "/OS-KSADM/roles"

    container = "roles"
    key = "name"

    # See if the role exists yet
    role_uuid, error = _find_id(new_resource, http, path, container, key, new_resource.role_name)
    unless role_uuid
        # role does not exist yet
        payload = _build_role_obj(new_resource.role_name)
        req = _http_post new_resource, path
        req.body = JSON.generate(payload)
        resp = http.request req
        if resp.is_a?(Net::HTTPOK)
            Chef::Log.info("Created Role '#{new_resource.role_name}'")
            new_resource.updated_by_last_action(true)
        else
            Chef::Log.error("Unable to create role '#{new_resource.role_name}'")
            Chef::Log.error("Response Code: #{resp.code}")
            Chef::Log.error("Response Message: #{resp.message}")
            new_resource.updated_by_last_action(false)
        end
    else
        Chef::Log.info("Role '#{new_resource.role_name}' already exists.. Not creating.") if error
        Chef::Log.info("Role UUID: #{role_uuid}")
        new_resource.updated_by_last_action(false)
    end
end

action :create_user do
    http = _new_http new_resource

    # lookup tenant_uuid
    tenant_container = "tenants"
    tenant_key = "name"
    tenant_path = "/tenants"
    tenant_uuid, tenant_error = _find_id(new_resource, http, tenant_path, tenant_container, tenant_key, new_resource.tenant_name)
    Chef::Log.error("There was an error looking up Tenant '#{new_resource.tenant_name}'") if tenant_error

    unless tenant_uuid
        Chef::Log.error("Unable to find tenant '#{new_resource.tenant_name}'")
        new_resource.updated_by_last_action(false)
    end

    # Construct the extension path using the found tenant_uuid
    path = "/tenants/#{tenant_uuid}/users"

    # Make sure this endpoint does not already exist
    req = _http_get new_resource, path
    resp = http.request req
    if resp.is_a?(Net::HTTPOK)
        user_exists = false
        data = JSON.parse(resp.body)
        data['users'].each do |endpoint|
            if endpoint['name'] == new_resource.user_name
                # Match found
                user_exists = true
                break
            end
        end
        if user_exists
            Chef::Log.info("User '#{new_resource.user_name}' already exists for tenant '#{new_resource.tenant_name}'")
            new_resource.updated_by_last_action(false)
        else
            payload = _build_user_object(
                      tenant_uuid,
                      new_resource.user_name,
                      new_resource.user_pass,
                      new_resource.user_enabled)

            # Construct the extension path using the found tenant_uuid
            path = "/users"
            req = _http_post new_resource, path
            req.body = JSON.generate(payload)
            resp = http.request req
            if resp.is_a?(Net::HTTPOK)
                Chef::Log.info("Created user '#{new_resource.user_name}' for tenant '#{new_resource.tenant_name}'")
                new_resource.updated_by_last_action(true)
            else
                Chef::Log.error("Unable to create user '#{new_resource.user_name}' for tenant '#{new_resource.tenant_name}'")
                Chef::Log.error("Response Code: #{resp.code}")
                Chef::Log.error("Response Message: #{resp.message}")
                new_resource.updated_by_last_action(false)
            end
        end
    else
        Chef::Log.error("Unknown response from the Keystone Server")
        Chef::Log.error("Response Code: #{resp.code}")
        Chef::Log.error("Response Message: #{resp.message}")
        new_resource.updated_by_last_action(false)
    end
end

action :grant_role do
    http = _new_http new_resource

    # lookup tenant_uuid
    tenant_container = "tenants"
    tenant_key = "name"
    tenant_path = "/tenants"
    tenant_uuid, tenant_error = _find_id(new_resource, http, tenant_path, tenant_container, tenant_key, new_resource.tenant_name)
    Chef::Log.error("There was an error looking up Tenant '#{new_resource.tenant_name}'") if tenant_error

    # lookup user_uuid
    user_container = "users"
    user_key = "name"
    # user_path = "/tenants/#{tenant_uuid}/users"
    user_path = "/users"
    user_uuid, user_error = _find_id(new_resource, http, user_path, user_container, user_key, new_resource.user_name)
    Chef::Log.error("There was an error looking up User '#{new_resource.user_name}'") if user_error

    # lookup role_uuid
    role_container = "roles"
    role_key = "name"
    role_path = "/OS-KSADM/roles"
    role_uuid, role_error = _find_id(new_resource, http, role_path, role_container, role_key, new_resource.role_name)
    Chef::Log.error("There was an error looking up Role '#{new_resource.role_name}'") if role_error

    Chef::Log.debug("Found Tenant UUID: #{tenant_uuid}")
    Chef::Log.debug("Found User UUID: #{user_uuid}")
    Chef::Log.debug("Found Role UUID: #{role_uuid}")

    # lookup roles assigned to user/tenant
    assigned_container = "roles"
    assigned_key = "name"
    assigned_path = "/tenants/#{tenant_uuid}/users/#{user_uuid}/roles"
    assigned_role_uuid, assigned_error = _find_id(new_resource, http, assigned_path, assigned_container, assigned_key, new_resource.role_name)
    Chef::Log.error("There was an error looking up Assigned Role '#{new_resource.role_name}' for User '#{new_resource.user_name}' and Tenant '#{new_resource.tenant_name}'") if assigned_error

    error = (tenant_error or user_error or role_error or assigned_error)
    unless role_uuid == assigned_role_uuid or error
        # Construct the extension path
        path = "/tenants/#{tenant_uuid}/users/#{user_uuid}/roles/OS-KSADM/#{role_uuid}"

        # needs a '' for the body, or it throws a 500
        req = _http_put new_resource, path
        req.body = ''
        resp = http.request req
        if resp.is_a?(Net::HTTPOK)
            Chef::Log.info("Granted Role '#{new_resource.role_name}' to User '#{new_resource.user_name}' in Tenant '#{new_resource.tenant_name}'")
            new_resource.updated_by_last_action(true)
        else
            Chef::Log.error("Unable to grant role '#{new_resource.role_name}'")
            Chef::Log.error("Response Code: #{resp.code}")
            Chef::Log.error("Response Message: #{resp.message}")
            new_resource.updated_by_last_action(false)
        end
    else
        Chef::Log.info("Role '#{new_resource.role_name}' already exists.. Not granting.")
        Chef::Log.error("There was an error looking up '#{new_resource.role_name}'") if error
        new_resource.updated_by_last_action(false)
    end
end


private
def _find_id(resource, http, path, container, key, match_value)
    uuid = nil
    error = false
    req = _http_get resource, path
    resp = http.request req
    if resp.is_a?(Net::HTTPOK)
        data = JSON.parse(resp.body)
        data[container].each do |obj|
            uuid = obj['id'] if obj[key] == match_value
            break if uuid
        end
    else
        Chef::Log.error("Unknown response from the Keystone Server")
        Chef::Log.error("Response Code: #{resp.code}")
        Chef::Log.error("Response Message: #{resp.message}")
        error = true
    end
    return uuid,error
end


def _build_service_object(type, name, description)
    service_obj = Hash.new
    service_obj.store("type", type)
    service_obj.store("name", name)
    service_obj.store("description", description)
    ret = Hash.new
    ret.store("OS-KSADM:service", service_obj)
    return ret
end


def _build_role_obj(name)
    role_obj = Hash.new
    role_obj.store("name", name)
    ret = Hash.new
    ret.store("role", role_obj)
    return ret
end


def _build_tenant_object(name, description, enabled)
    tenant_obj = Hash.new
    tenant_obj.store("name", name)
    tenant_obj.store("description", description)
    tenant_obj.store("enabled", enabled)
    ret = Hash.new
    ret.store("tenant", tenant_obj)
    return ret
end


def _build_endpoint_object(region, service_uuid, publicurl, internalurl, adminurl)
    endpoint_obj = Hash.new
    endpoint_obj.store("adminurl", adminurl)
    endpoint_obj.store("internalurl", internalurl)
    endpoint_obj.store("publicurl", publicurl)
    endpoint_obj.store("service_id", service_uuid)
    endpoint_obj.store("region", region)
    ret = Hash.new
    ret.store("endpoint", endpoint_obj)
    return ret
end


def _build_user_object(tenant_uuid, name, password, enabled)
    user_obj = Hash.new
    user_obj.store("tenantId", tenant_uuid)
    user_obj.store("name", name)
    user_obj.store("password", password)
    # Have to provide a null value for this because I dont want to have this in the LWRP
    user_obj.store("email", nil)
    user_obj.store("enabled", enabled)
    ret = Hash.new
    ret.store("user", user_obj)
    return ret
end


# Return a Net::HTTP object the caller can use to call paths
# on the Keystone Admin API endpoint. Admin token validation
# will already be handled and the x-auth-token header already
# set in the returned HTTP object's headers.
def _new_http resource
  uri = ::URI.parse(resource.auth_uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 3
  http.open_timeout = 3
  http
end


# Short-cut for returning an Net::HTTP::Post to a path on the admin API endpoint.
# Headers and admin token validation are already performed. All
# the caller needs to do is call http.request, supplying the returned object
def _http_post resource, path
  request = Net::HTTP::Post.new(path)
  _build_request resource, request
end


# Short-cut for returning an Net::HTTP::Put to a path on the admin API endpoint.
# Headers and admin token validation are already performed. All
# the caller needs to do is call http.request, supplying the returned object
def _http_put resource, path
  request = Net::HTTP::Put.new(path)
  _build_request resource, request
end


# Short-cut for returning an Net::HTTP::Get to a path on the admin API endpoint.
# Headers and admin token validation are already performed. All
# the caller needs to do is call http.request, supplying the returned object
def _http_get resource, path
  request = Net::HTTP::Get.new(path)
  _build_request resource, request
end


# Returns a token for use by a Keystone Admin user when
# issuing requests to the Keystone Admin API
def _get_admin_token auth_admin_uri, admin_tenant_name, admin_user, admin_password
  # Construct a HTTP object from the supplied URI pointing to the
  # Keystone Admin API endpoint.
  if not @cached_admin_token.nil?
    return @cached_admin_token
  end
  uri = ::URI.parse(auth_admin_uri)
  http = Net::HTTP.new(uri.host, uri.port)
  path = "/tokens"

  payload = Hash.new
  payload['auth'] = Hash.new
  payload['auth']['passwordCredentials'] = Hash.new
  payload['auth']['passwordCredentials']['username'] = admin_user
  payload['auth']['passwordCredentials']['password'] = admin_password
  payload['auth']['tenantName'] = admin_tenant_name
  
  req = Net::HTTP::Post.new(path)
  req.body = JSON.generate(payload)
  resp = http.request req
  if resp.is_a?(Net::HTTPOK)
    data = JSON.parse resp.body
    token = data['access']['token']['id']
    @cached_admin_token = token
  else
    Chef::Log.error("Unable to get admin token.")
    Chef::Log.error("Response Code: #{resp.code}")
    Chef::Log.error("Response Message: #{resp.message}")
  end
end

# Constructs the request object with all the requisite headers added
def _build_request resource, request
  admin_token = _get_admin_token resource.auth_uri, resource.admin_tenant_name, resource.admin_user, resource.admin_password
  request.add_field 'x-auth-token', admin_token
  request.add_field 'content-type', 'application/json'
  request.add_field 'user-agent', 'Chef keystone_register'
  request
end
