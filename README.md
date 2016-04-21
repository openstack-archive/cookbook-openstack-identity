Description
===========

This cookbook installs the OpenStack Identity Service **Keystone** as part of
the OpenStack reference deployment Chef for OpenStack. The
https://github.com/openstack/openstack-chef-repo contains documentation for
using this cookbook in the context of a full OpenStack deployment. Keystone is
installed from packages, creating the default user, tenant, and roles. It also
registers the identity service and identity endpoint.

http://keystone.openstack.org

Requirements
============

- Chef 12 or higher
- chefdk 0.9.0 for testing (also includes berkshelf for cookbook dependency
  resolution)

Platform
========

- ubuntu
- redhat
- centos

Cookbooks
=========

The following cookbooks are dependencies:

- 'apache2', '~> 3.1'
- 'openstack-common', '>= 13.0.0'

Attributes
==========

Please see the extensive inline documentation in `attributes/*.rb` for
descriptions of all the settable attributes for this cookbook.

Note that all attributes are in the `default['openstack']` "namespace"

The usage of attributes to generate the keystone.conf is decribed in the
openstack-common cookbook.

Recipes
=======

## openstack-identity::client
- Installs the packages require to use keystone client.

## openstack-identity::openrc
- Creates a fully usable openrc file to export the needed environment variables
  to use the openstack client.

## openstack-identity::registration
- Registers the initial keystone endpoint as well as users, tenants and roles
  needed for the initial configuration utilizing the LWRP provided inside of
  this cookbook. The recipe is documented in detail with inline comments inside
  the recipe.

## openstack-identity::server-apache
- Installs and configures the OpenStack Identity Service running inside of an
  apache webserver. The recipe is documented in detail with inline comments
  inside the recipe.

Resources
=========

## openstack_identity_register

### Actions

- create_ec2_credentials:
- create_endpoint:
- create_role:
- create_service:
- create_tenant:
- create_user:
- grant_role:

### Attribute Parameters

- auth_uri: The uri used to as authentication endpoint for requests
- bootstrap_token: The admin bootstrap_token used for authentication
- service_type: Type of service to create (e.g. 'identity' or 'volume')
- service_name: The name of the service to create (only for action
  :create_service)
- service_description: The description for the service to create (only for
  action :create_service)
- endpoint_region: The region to create the endpoint in (only for action
  :create_endpoint) Defaults to <code>"RegionOne"</code>.
- endpoint_adminurl: The public url to register for the endpoint (only for
  action :create_endpoint)
- endpoint_internalurl:  The internal url to register for the endpoint (only for
  action :create_endpoint)
- endpoint_publicurl: The public url to register for the endpoint (only for
  action :create_endpoint)
- tenant_name: The name of the tenant to create or create the user in (only for
  action :create_tenant and :create_user)
- tenant_description: The description of the tenant to create (only for action
  :create_tenant)
- tenant_enabled: Enable or disable tenant to create (only for action
  :create_tenant) Defaults to <code>true</code>.
- user_name: The name of the user to create (only for action :create_user)
- user_pass: The passwort of the user to create (only for action :create_user)
- user_enabled: Enable or disable user to create (only for action :create_user)
  Defaults to <code>true</code>.
- role_name: The name of the role to create or grant to the user (only for
  :create_role and :grant_role)
- admin_tenant_name: The name of the admin tenant (only for
  :create_ec2_credentials)
- admin_user: The name of the admin user (only for :create_ec2_credentials)
- admin_pass: The password of the admin user (only for :create_ec2_credentials)
- identity_endpoint: The identity endpoint to use for user and ec2 creation. If
  not specified, default endpoint will be used. (only for create_ec2_credentials
and create_user)

### Examples

```
# Create 'openstack' tenant
openstack_identity_register "Register 'openstack' Tenant" do
  auth_host "192.168.1.10"
  auth_port "35357"
  auth_protocol "http"
  api_ver "/v2.0"
  auth_token "123456789876"
  tenant_name "openstack"
  tenant_description "Default Tenant"
  tenant_enabled "true" # Not required as this is the default
  action :create_tenant
end

# Create 'admin' user
openstack_identity_register "Register 'admin' User" do
  auth_host "192.168.1.10"
  auth_port "35357"
  auth_protocol "http"
  api_ver "/v2.0"
  auth_token "123456789876"
  tenant_name "openstack"
  user_name "admin"
  user_pass "secrete"
  user_enabled "true" # Not required as this is the default
  action :create_user
end

# Create 'admin' role
openstack_identity_register "Register 'admin' Role" do
  auth_host "192.168.1.10"
  auth_port "35357"
  auth_protocol "http"
  api_ver "/v2.0"
  auth_token "123456789876"
  role_name role_key
  action :create_role
end

# Grant 'admin' role to 'admin' user in the 'openstack' tenant
openstack_identity_register "Grant 'admin' Role to 'admin' User" do
  auth_host "192.168.1.10"
  auth_port "35357"
  auth_protocol "http"
  api_ver "/v2.0"
  auth_token "123456789876"
  tenant_name "openstack"
  user_name "admin"
  role_name "admin"
  action :grant_role
end

# Create 'identity' service
openstack_identity_register "Register Identity Service" do
  auth_host "192.168.1.10"
  auth_port "35357"
  auth_protocol "http"
  api_ver "/v2.0"
  auth_token "123456789876"
  service_name "keystone"
  service_type "identity"
  service_description "Keystone Identity Service"
  action :create_service
end

# Create 'identity' endpoint
openstack_identity_register "Register Identity Endpoint" do
  auth_host "192.168.1.10"
  auth_port "35357"
  auth_protocol "http"
  api_ver "/v2.0"
  auth_token "123456789876"
  service_type "identity"
  endpoint_region "RegionOne"
  endpoint_adminurl "http://192.168.1.10:35357/v2.0"
  endpoint_internalurl "http://192.168.1.10:5001/v2.0"
  endpoint_publicurl "http://1.2.3.4:5001/v2.0"
  action :create_endpoint
end
```


License and Author
==================

Author:: Justin Shepherd (<justin.shepherd@rackspace.com>)
Author:: Jason Cannavale (<jason.cannavale@rackspace.com>)
Author:: Ron Pedde (<ron.pedde@rackspace.com>)
Author:: Joseph Breu (<joseph.breu@rackspace.com>)
Author:: William Kelly (<william.kelly@rackspace.com>)
Author:: Darren Birkett (<darren.birkett@rackspace.co.uk>)
Author:: Evan Callicoat (<evan.callicoat@rackspace.com>)
Author:: Matt Ray (<matt@opscode.com>)
Author:: Jay Pipes (<jaypipes@att.com>)
Author:: John Dewey (<jdewey@att.com>)
Author:: Sean Gallagher (<sean.gallagher@att.com>)
Author:: Ionut Artarisi (<iartarisi@suse.cz>)
Author:: Chen Zhiwei (zhiwchen@cn.ibm.com)
Author:: Eric Zhou (zyouzhou@cn.ibm.com)
Author:: Jan Klare (j.klare@cloudbau.de)

Copyright 2012, Rackspace US, Inc.
Copyright 2012-2013, Opscode, Inc.
Copyright 2012-2013, AT&T Services, Inc.
Copyright 2013-2014, SUSE Linux GmbH
Copyright 2013-2014, IBM, Corp.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
