#
# Cookbook Name:: openstack-identity
# Provider:: credentials
#
# Copyright 2012, Rackspace US, Inc.
# Copyright 2012-2013, AT&T Services, Inc.
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

action :create_ec2 do
    http = _new_http new_resource

    # lookup tenant_uuid
    Chef::Log.debug("Looking up Tenant_UUID for Tenant_Name: #{new_resource.tenant_name}")
    tenant_container = "tenants"
    tenant_key = "name"
    tenant_path = "tenants"
    tenant_uuid, tenant_error = _find_id(new_resource, http, tenant_path, tenant_container, tenant_key, new_resource.tenant_name)
    Chef::Log.error("There was an error looking up Tenant '#{new_resource.tenant_name}'") if tenant_error

    # lookup user_uuid
    Chef::Log.debug("Looking up User_UUID for User_Name: #{new_resource.user_name}")
    user_container = "users"
    user_key = "name"
    user_path = "tenants/#{tenant_uuid}/users"
    user_uuid, user_error = _find_id(new_resource, http, user_path, user_container, user_key, new_resource.user_name)
    Chef::Log.error("There was an error looking up User '#{new_resource.user_name}'") if user_error

    Chef::Log.debug("Found Tenant UUID: #{tenant_uuid}")
    Chef::Log.debug("Found User UUID: #{user_uuid}")

    # See if a set of credentials already exists for this user/tenant combo
    cred_container = "credentials"
    cred_key = "tenant_id"
    cred_path = "users/#{user_uuid}/credentials/OS-EC2"
    cred_tenant_uuid, cred_error = _find_cred_id(new_resource, http, cred_path, cred_container, cred_key, tenant_uuid)
    Chef::Log.error("There was an error looking up EC2 Credentials for User '#{new_resource.user_name}' and Tenant '#{new_resource.tenant_name}'") if cred_error

    error = (tenant_error or user_error or cred_error)
    unless cred_tenant_uuid or error
        # Construct the extension path
        path = "users/#{user_uuid}/credentials/OS-EC2"

        payload = _build_credentials_obj(tenant_uuid)

        req = _http_post new_resource, path
        req.body = JSON.generate(payload)
        resp = http.request req
        if resp.is_a?(Net::HTTPOK)
            Chef::Log.info("Created EC2 Credentials for User '#{new_resource.user_name}' in Tenant '#{new_resource.tenant_name}'")
            # Need to parse the output here and update node attributes
            data = JSON.parse(resp.body)
            node.set['credentials']['EC2'][new_resource.user_name]['access'] = data['credential']['access']
            node.set['credentials']['EC2'][new_resource.user_name]['secret'] = data['credential']['secret']
            node.save unless Chef::Config[:solo]
            new_resource.updated_by_last_action(true)
        else
            Chef::Log.error("Unable to create EC2 Credentials for User '#{new_resource.user_name}' in Tenant '#{new_resource.tenant_name}'")
            Chef::Log.error("Response Code: #{resp.code}")
            Chef::Log.error("Response Message: #{resp.message}")
            new_resource.updated_by_last_action(false)
        end
    else
        Chef::Log.info("Credentials already exist for User '#{new_resource.user_name}' in Tenant '#{new_resource.tenant_name}'.. Not creating.")
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
        Chef::Log.error("GET #{path} returned #{resp.code}")
        Chef::Log.error("Response Message: #{resp.message}")
        Chef::Log.error("Response Body: #{resp.body}")
        error = true
    end
    return uuid, error
end


def _find_cred_id(resource, http, path, container, key, match_value)
    uuid = nil
    error = false
    req = _http_get resource, path
    resp = http.request req
    if resp.is_a?(Net::HTTPOK)
        data = JSON.parse(resp.body)
        data[container].each do |obj|
            uuid = obj['tenant_id'] if obj[key] == match_value
            break if uuid
        end
    else
        Chef::Log.error("GET #{path} returned #{resp.code}")
        Chef::Log.error("Response Message: #{resp.message}")
        Chef::Log.error("Response Body: #{resp.body}")
        error = true
    end
    return uuid,error
end

def _build_credentials_obj(tenant_uuid)
    ret = Hash.new
    ret.store("tenant_id", tenant_uuid)
    return ret
end


# Return a Net::HTTP object the caller can use to call paths
# on the Keystone Admin API endpoint. Admin token validation
# will already be handled and the x-auth-token header already
# set in the returned HTTP object's headers.
def _new_http resource
  uri = ::URI.parse(resource.auth_uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.read_timeout = 3
  http.open_timeout = 3
  http
end


# Just cats the request URI with the supplied path, returning a string
def _path uri, subject
  [uri.request_uri, subject].join
end


# Short-cut for returning an Net::HTTP::Post to a path on the admin API endpoint.
# Headers and admin token validation are already performed. All
# the caller needs to do is call http.request, supplying the returned object
def _http_post resource, path
  uri = ::URI.parse(resource.auth_uri)
  path = _path uri, path
  request = Net::HTTP::Post.new(path)
  _build_request resource, request
end


# Short-cut for returning an Net::HTTP::Put to a path on the admin API endpoint.
# Headers and admin token validation are already performed. All
# the caller needs to do is call http.request, supplying the returned object
def _http_put resource, path
  uri = ::URI.parse(resource.auth_uri)
  path = _path uri, path
  request = Net::HTTP::Put.new(path)
  _build_request resource, request
end


# Short-cut for returning an Net::HTTP::Get to a path on the admin API endpoint.
# Headers and admin token validation are already performed. All
# the caller needs to do is call http.request, supplying the returned object
def _http_get resource, path
  uri = ::URI.parse(resource.auth_uri)
  path = _path uri, path
  request = Net::HTTP::Get.new(path)
  _build_request resource, request
end


# Constructs the request object with all the requisite headers added
def _build_request resource, request
  admin_token = resource.bootstrap_token
  request.add_field 'X-Auth-Token', admin_token
  request.add_field 'Content-type', 'application/json'
  request.add_field 'user-agent', 'Chef keystone_credentials'
  request
end
