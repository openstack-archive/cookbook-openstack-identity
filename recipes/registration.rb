#
# Cookbook:: openstack-identity
# Recipe:: setup
#
# Copyright:: 2012-2021, Rackspace US, Inc.
# Copyright:: 2012-2021, Chef Software, Inc.
# Copyright:: 2020-2021, Oregon State University
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

require 'chef/mixin/shell_out'

class ::Chef::Recipe
  include ::Openstack
end

identity_endpoint = public_endpoint 'identity'
identity_internal_endpoint = internal_endpoint 'identity'
auth_url = identity_internal_endpoint.to_s

# define the credentials to use for the initial admin user
admin_project = node['openstack']['identity']['admin_project']
admin_user = node['openstack']['identity']['admin_user']
admin_pass = get_password 'user', node['openstack']['identity']['admin_user']
admin_domain = node['openstack']['identity']['admin_domain_name']

# endpoint type to use when creating resources
# NOTE(frickler): fog-openstack defaults to the 'admin' endpoint for
# Identity operations, so we need to override this after we dropped that one
# TODO(ramereth): commenting this out until
# https://github.com/fog/fog-openstack/pull/494 gets merged and released.
# endpoint_type = node['openstack']['identity']['endpoint_type']

connection_params = {
  openstack_auth_url: auth_url,
  openstack_username: admin_user,
  openstack_api_key: admin_pass,
  openstack_project_name: admin_project,
  openstack_domain_id: admin_domain,
  # openstack_endpoint_type: endpoint_type,
}

ruby_block 'wait for identity endpoint' do
  block do
    begin
      Timeout.timeout(60) do
        until Net::HTTP.get_response(URI(auth_url)).message == 'OK'
          Chef::Log.info 'waiting for identity endpoint to be up...'
          sleep 1
        end
      end
    rescue Timeout::Error
      raise 'Waited 60 seconds for identity endpoint to become ready'\
        ' and will not wait any longer'
    end
  end
end

# create default service role
openstack_role 'service' do
  connection_params connection_params
end

node.default['openstack']['identity']['internalURL'] = identity_internal_endpoint.to_s
node.default['openstack']['identity']['publicURL'] = identity_endpoint.to_s

Chef::Log.info "Keystone InternalURL: #{identity_internal_endpoint}"
Chef::Log.info "Keystone PublicURL: #{identity_endpoint}"
