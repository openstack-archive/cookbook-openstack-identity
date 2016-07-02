# encoding: UTF-8
#
# Cookbook Name:: openstack-identity
# Resource:: register
#
# Copyright 2012, Rackspace US, Inc.
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

# These resources provide an abstraction layer for interacting with the keystone
# server's API, allowin for other nodes to register any required users, tenants,
# roles, services, or endpoints.

actions :create_service, :create_endpoint, :create_tenant, :create_user, :create_role, :grant_role, :create_ec2_credentials

# In earlier versions of Chef the LWRP DSL doesn't support specifying
# a default action, so you need to drop into Ruby.
def initialize(*args)
  super
  @action = :create
end

BOOLEAN = [TrueClass, FalseClass].freeze

# The uri used to as authentication endpoint for requests
attribute :auth_uri, kind_of: String
# The admin bootstrap_token used for authentication
attribute :bootstrap_token, kind_of: String
# The type of service to create (e.g. 'identity' or 'volume')
attribute :service_type, kind_of: String
# The name of the service to create (only for action :create_service)
attribute :service_name, kind_of: String
# The description for the service to create (only for action :create_service)
attribute :service_description, kind_of: String
# The region to create the endpoint in (only for action :create_endpoint)
attribute :endpoint_region, kind_of: String, default: 'RegionOne'
# The admin url to register for the endpoint (only for action :create_endpoint)
attribute :endpoint_adminurl, kind_of: String
# The internal url to register for the endpoint (only for action
# :create_endpoint)
attribute :endpoint_internalurl, kind_of: String
# The public url to register for the endpoint (only for action :create_endpoint)
attribute :endpoint_publicurl, kind_of: String
# The name of the tenant to create or create the user in (only for action
# :create_tenant and :create_user)
attribute :tenant_name, kind_of: String
# The description of the tenant to create (only for action :create_tenant)
attribute :tenant_description, kind_of: String
# Enable or disable tenant to create (only for action :create_tenant)
attribute :tenant_enabled, kind_of: BOOLEAN, default: true
# The name of the user to create (only for action :create_user)
attribute :user_name, kind_of: String
# The passwort of the user to create (only for action :create_user)
attribute :user_pass, kind_of: String
# Enable or disable user to create (only for action :create_user)
attribute :user_enabled, kind_of: BOOLEAN, default: true
# The name of the role to create or grant to the user (only for :create_role and
# :grant_role)
attribute :role_name, kind_of: String
# The name of the admin tenant (only for :create_ec2_credentials)
attribute :admin_tenant_name, kind_of: String
# The name of the admin user (only for :create_ec2_credentials)
attribute :admin_user, kind_of: String
# The password of the admin user (only for :create_ec2_credentials)
attribute :admin_pass, kind_of: String
# The identity endpoint to use for user and ec2 creation. If not specified,
# default endpoint will be used. (only for create_ec2_credentials and
# create_user)
attribute :identity_endpoint, kind_of: String
