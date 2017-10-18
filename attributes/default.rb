# encoding: UTF-8
#
# Cookbook Name:: openstack-identity
# Recipe:: default
#
# Copyright 2012-2013, AT&T Services, Inc.
# Copyright 2013, Opscode, Inc.
# Copyright 2013, IBM Corp.
# Copyright 2017, x-ion GmbH
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

# Set to some text value if you want templated config files
# to contain a custom banner at the top of the written file
default['openstack']['identity']['custom_template_banner'] =
  '# This file is autogenerated by Chef, changes will be overwritten'

%w(admin internal public).each do |ep_type|
  # host for openstack admin/internal/public identity endpoint
  default['openstack']['endpoints'][ep_type]['identity']['host'] = '127.0.0.1'
  # scheme for openstack admin/internal/public identity endpoint
  default['openstack']['endpoints'][ep_type]['identity']['scheme'] = 'http'
  # path for openstack admin/internal/public identity endpoint
  default['openstack']['endpoints'][ep_type]['identity']['path'] = '/v3'
end

# port for openstack public identity endpoint
default['openstack']['endpoints']['public']['identity']['port'] = 5000
# port for openstack internal identity endpoint
default['openstack']['endpoints']['internal']['identity']['port'] = 5000
# port for openstack admin identity endpoint
default['openstack']['endpoints']['admin']['identity']['port'] = 35357

# address for openstack identity service main endpoint to bind to
default['openstack']['bind_service']['main']['identity']['host'] = '127.0.0.1'
# port for openstack identity service main endpoint to bind to
default['openstack']['bind_service']['main']['identity']['port'] = 5000
# address for openstack identity service admin endpoint to bind to
default['openstack']['bind_service']['admin']['identity']['host'] = '127.0.0.1'
# port for openstack identity service admin endpoint to bind to
default['openstack']['bind_service']['admin']['identity']['port'] = 35357

# identity service catalog backend for service endpoints
default['openstack']['identity']['catalog']['backend'] = 'sql'
# identity service token backend for user and service tokens
default['openstack']['identity']['token']['backend'] = 'sql'

# Specify a location to retrieve keystone-paste.ini from
# which can either be a remote url using http:// or a
# local path to a file using file:// which would generally
# be a distribution file - if this option is left nil then
# the templated version distributed with this cookbook
# will be used (keystone-paste.ini.erb)
default['openstack']['identity']['pastefile_url'] = nil

# This specify the pipeline of the keystone public API,
# all Identity public API requests will be processed by the order of the pipeline.
# this value will be used in the templated version of keystone-paste.ini
# The last item in this pipeline must be public_service or an equivalent
# application. It cannot be a filter.
default['openstack']['identity']['pipeline']['public_api'] = 'healthcheck cors sizelimit http_proxy_to_wsgi url_normalize request_id build_auth_context token_auth json_body ec2_extension public_service'
# This specify the pipeline of the keystone admin API,
# all Identity admin API requests will be processed by the order of the pipeline.
# this value will be used in the templated version of keystone-paste.ini
# The last item in this pipeline must be admin_service or an equivalent
# application. It cannot be a filter.
default['openstack']['identity']['pipeline']['admin_api'] = 'healthcheck cors sizelimit http_proxy_to_wsgi url_normalize request_id build_auth_context token_auth json_body ec2_extension s3_extension admin_service'
# This specify the pipeline of the keystone V3 API,
# all Identity V3 API requests will be processed by the order of the pipeline.
# this value will be used in the templated version of keystone-paste.ini
# The last item in this pipeline must be service_v3 or an equivalent
# application. It cannot be a filter.
default['openstack']['identity']['pipeline']['api_v3'] = 'healthcheck cors sizelimit http_proxy_to_wsgi url_normalize request_id build_auth_context token_auth json_body ec2_extension_v3 s3_extension service_v3'

# region to be used for endpoint registration
default['openstack']['identity']['region'] = node['openstack']['region']

# enable or disable the usage of syslog
default['openstack']['identity']['syslog']['use'] = false
# syslog log facility to log to in case syslog is used
default['openstack']['identity']['syslog']['facility'] = 'LOG_LOCAL2'
# syslog config facility in case syslog is used
default['openstack']['identity']['syslog']['config_facility'] = 'local2'

# user to be created and used for identity service
default['openstack']['identity']['admin_user'] = 'admin'
# project to be created and used for identity service
default['openstack']['identity']['admin_project'] = 'admin'
# domain to be created and used for identity service project
default['openstack']['identity']['admin_project_domain'] = 'default'
# role to be created and used for identity service
default['openstack']['identity']['admin_role'] = 'admin'
# domain to be created and used for identity service user
default['openstack']['identity']['admin_domain_name'] = 'default'

# specify whether to enable SSL for Keystone API endpoint
default['openstack']['identity']['ssl']['enabled'] = false
# specify server whether to enforce client certificate requirement
default['openstack']['identity']['ssl']['cert_required'] = false
# SSL certificate, keyfile and CA certficate file locations
default['openstack']['identity']['ssl']['basedir'] = '/etc/keystone/ssl'
# Protocol for SSL (Apache)
default['openstack']['identity']['ssl']['protocol'] = 'All -SSLv2 -SSLv3'
# Which ciphers to use with the SSL/TLS protocol (Apache)
# Example: 'RSA:HIGH:MEDIUM:!LOW:!kEDH:!aNULL:!ADH:!eNULL:!EXP:!SSLv2:!SEED:!CAMELLIA:!PSK!RC4:!RC4-MD5:!RC4-SHA'
default['openstack']['identity']['ssl']['ciphers'] = nil
# path of the cert file for SSL.
default['openstack']['identity']['ssl']['certfile'] = "#{node['openstack']['identity']['ssl']['basedir']}/certs/sslcert.pem"
# path of the keyfile for SSL.
default['openstack']['identity']['ssl']['keyfile'] = "#{node['openstack']['identity']['ssl']['basedir']}/private/sslkey.pem"
default['openstack']['identity']['ssl']['chainfile'] = nil
# path of the CA cert file for SSL.
default['openstack']['identity']['ssl']['ca_certs'] = "#{node['openstack']['identity']['ssl']['basedir']}/certs/sslca.pem"
# path of the CA cert files for SSL (Apache)
default['openstack']['identity']['ssl']['ca_certs_path'] = "#{node['openstack']['identity']['ssl']['basedir']}/certs/"

# Fernet keys to read from databags/vaults. This should be changed in the
# environment when rotating keys (with the defaults below, the items
# 'fernet_key0' and 'fernet_key1' will be read from the databag/vault
# 'keystone).
# For more information please read:
# http://docs.openstack.org/admin-guide-cloud/keystone_fernet_token_faq.html
default['openstack']['identity']['fernet']['keys'] = [0, 1]
default['openstack']['identity']['conf']['fernet_tokens']['key_repository'] =
  '/etc/keystone/fernet-tokens'

# The external (REMOTE_USER) auth plugin module. (String value)
default['openstack']['identity']['auth']['external'] = 'keystone.auth.plugins.external.DefaultDomain'
# Default auth methods. (List value)
default['openstack']['identity']['auth']['methods'] = 'external, password, token, oauth1'
# Default auth_version for now
default['openstack']['identity']['auth']['version'] = 'v3'

# configuration directory for keystone domain specific options
default['openstack']['identity']['identity']['domain_config_dir'] = '/etc/keystone/domains'

# keystone service user name
default['openstack']['identity']['user'] = 'keystone'
# keystone service user group
default['openstack']['identity']['group'] = 'keystone'

# platform defaults
case node['platform_family']
when 'fedora', 'rhel' # :pragma-foodcritic: ~FC024 - won't fix this
  # platform specific package and service name options
  default['openstack']['identity']['platform'] = {
    'memcache_python_packages' => ['python-memcached'],
    'keystone_packages' => ['openstack-keystone', 'openstack-selinux'],
    'keystone_service' => 'openstack-keystone',
    'keystone_process_name' => 'keystone-all',
    'package_options' => '',
  }
when 'debian'
  # platform specific package and service name options
  default['openstack']['identity']['platform'] = {
    'memcache_python_packages' => ['python-memcache'],
    'keystone_packages' => ['keystone'],
    'keystone_service' => 'keystone',
    'keystone_process_name' => 'keystone-all',
    'package_options' => "-o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-confdef'",
  }
end

# array of bare options for openrc (e.g. 'option=value')
default['openstack']['misc_openrc'] = nil

# openrc path
default['openstack']['openrc']['path'] = '/root'
# openrc path mode
default['openstack']['openrc']['path_mode'] = '0700'
# openrc file name
default['openstack']['openrc']['file'] = 'openrc'
# openrc file mode
default['openstack']['openrc']['file_mode'] = '0600'
# openrc file owner
default['openstack']['openrc']['user'] = 'root'
# openrc file group
default['openstack']['openrc']['group'] = 'root'
