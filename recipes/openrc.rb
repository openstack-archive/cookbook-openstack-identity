#
# Cookbook:: openstack-identity
# recipe:: openrc
#
# Copyright:: 2014-2021, IBM Corp.
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

# This recipe create a fully usable openrc file to export the needed environment
# variables to use the openstack client.

class ::Chef::Recipe
  include ::Openstack
end

ksadmin_project = node['openstack']['identity']['admin_project']
project_domain_name = node['openstack']['identity']['admin_project_domain']
ksadmin_user = node['openstack']['identity']['admin_user']
admin_domain_name = node['openstack']['identity']['admin_domain_name']

ksadmin_pass = get_password 'user', ksadmin_user

identity_endpoint = public_endpoint 'identity'
auth_url = identity_endpoint.to_s

openrc_config = node['openstack']['identity']['openrc']

directory openrc_config['path'] do
  owner openrc_config['user']
  group openrc_config['group']
  mode openrc_config['path_mode']
  recursive true
end

template "#{openrc_config['path']}/#{openrc_config['file']}" do
  source 'openrc.erb'
  owner openrc_config['user']
  group openrc_config['group']
  mode openrc_config['file_mode']
  sensitive true
  variables(
    user: ksadmin_user,
    user_domain_name: admin_domain_name,
    project: ksadmin_project,
    project_domain_name: project_domain_name,
    password: ksadmin_pass,
    identity_endpoint: auth_url
  )
end
