# encoding: UTF-8
#
# Cookbook Name:: openstack-identity
# Recipe:: _pki_tokens
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

certfile_url = node['openstack']['identity']['signing']['certfile_url']
keyfile_url = node['openstack']['identity']['signing']['keyfile_url']
ca_certs_url = node['openstack']['identity']['signing']['ca_certs_url']
signing_basedir = node['openstack']['identity']['signing']['basedir']

directory signing_basedir do
  owner node['openstack']['identity']['user']
  group node['openstack']['identity']['group']
  mode 00700
end

directory "#{signing_basedir}/certs" do
  owner node['openstack']['identity']['user']
  group node['openstack']['identity']['group']
  mode 00755
end

directory "#{signing_basedir}/private" do
  owner node['openstack']['identity']['user']
  group node['openstack']['identity']['group']
  mode 00750
end

if certfile_url.nil? || keyfile_url.nil? || ca_certs_url.nil?
  execute 'keystone-manage pki_setup' do
    user node['openstack']['identity']['user']
    group node['openstack']['identity']['group']

    not_if { ::FileTest.exists? "#{node['openstack']['identity']['signing']['basedir']}/private/signing_key.pem" }
  end
else
  remote_file node['openstack']['identity']['signing']['certfile'] do
    source certfile_url
    owner node['openstack']['identity']['user']
    group node['openstack']['identity']['group']
    mode 00640
  end

  remote_file node['openstack']['identity']['signing']['keyfile'] do
    source keyfile_url
    owner node['openstack']['identity']['user']
    group node['openstack']['identity']['group']
    mode 00640
  end

  remote_file node['openstack']['identity']['signing']['ca_certs'] do
    source ca_certs_url
    owner node['openstack']['identity']['user']
    group node['openstack']['identity']['group']
    mode 00640
  end
end
