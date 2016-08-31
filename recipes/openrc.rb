# encoding: UTF-8
#
# Cookbook Name:: openstack-identity
# recipe:: openrc
#
# Copyright 2014 IBM Corp.
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

auth_api_version = node['openstack']['api']['auth']['version']
ksadmin_pass = get_password 'user', ksadmin_user
identity_public_endpoint = public_endpoint 'identity'
auth_url = auth_uri_transform identity_public_endpoint.to_s, auth_api_version

directory node['openstack']['openrc']['path'] do
  owner node['openstack']['openrc']['user']
  group node['openstack']['openrc']['group']
  mode node['openstack']['openrc']['path_mode']
  recursive true
end

template "#{node['openstack']['openrc']['path']}/#{node['openstack']['openrc']['file']}" do
  source 'openrc.erb'
  owner node['openstack']['openrc']['user']
  group node['openstack']['openrc']['group']
  mode node['openstack']['openrc']['file_mode']
  sensitive true
  variables(
    user: ksadmin_user,
    user_domain_name: admin_domain_name,
    project: ksadmin_project,
    project_domain_name: project_domain_name,
    api_version: '3',
    password: ksadmin_pass,
    identity_endpoint: auth_url
  )
end
