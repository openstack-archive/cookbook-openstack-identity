# encoding: UTF-8
#
# Cookbook Name:: openstack-identity
# Recipe:: _fernet_tokens
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class ::Chef::Recipe
  include ::Openstack
end

node.default['openstack']['identity']['conf']['fernet_tokens']['key_repository'] =
  '/etc/keystone/fernet-tokens'
node.default['openstack']['identity']['conf']['token']['provider'] = 'fernet'

key_repository = node['openstack']['identity']['conf']['fernet_tokens']['key_repository']

directory key_repository do
  owner node['openstack']['identity']['user']
  group node['openstack']['identity']['group']
  mode 00700
end

node['openstack']['identity']['fernet']['keys'].each do |key_index|
  key = secret('keystone', "fernet_key#{key_index}")
  file File.join(key_repository, key_index.to_s) do
    content key
    owner node['openstack']['identity']['user']
    group node['openstack']['identity']['group']
    mode 00600
  end
end
