Description
===========

This cookbook installs the OpenStack Identity Service **Keystone** as part of the OpenStack reference deployment Chef for OpenStack. The https://github.com/openstack/openstack-chef-repo contains documentation for using this cookbook in the context of a full OpenStack deployment. Keystone is installed from packages, creating the default user, tenant, and roles. It also registers the identity service and identity endpoint.

http://keystone.openstack.org/

Requirements
============

Chef 0.10.0 or higher required (for Chef environment use)

Cookbooks
---------

The following cookbooks are dependencies:

* openstack-common

Usage
=====

client
------

Installs the keystone client packages


server (deprecated, will be removed in M release)
------

Installs and Configures Keystone Service

```json
"run_list": [
    "recipe[openstack-identity::server]"
]
```

server-apache
-------------

Installs and Configures Keystone Service under Apache

```json
"run_list": [
    "recipe[openstack-identity::server-apache]"
]
```

Resources/Providers
===================

These resources provide an abstraction layer for interacting with the keystone server's API, allowing for other nodes to register any required users, tenants, roles, services, or endpoints.

register
--------

Register users, tenants, roles, services and endpoints with Keystone

### Actions

- :create_tenant: Create a tenant
- :create_user: Create a user for a specified tenant
- :create_role: Create a role
- :grant_role: Grant a role to a specified user for a specified tenant
- :create_service: Create a service
- :create_endpoint: Create an endpoint for a sepcified service

### General Attributes

- auth_protocol: Required communication protocol with Keystone server
 - Acceptable values are [ "http", "https" ]
- auth_host: Keystone server IP Address
- auth_port: Port Keystone server is listening on
- api_ver: API Version for Keystone server
 - Accepted values are [ "/v2.0" ]
- auth_token: Auth Token for communication with Keystone server
- misc_keystone: Array of strings to be added to the keystone.conf file

### :create_tenant Specific Attributes

- tenant_name: Name of tenant to create
- tenant_description: Description of tenant to create
- tenant_enabled: Enable or Disable tenant
 - Accepted values are [ "true", "false" ]
 - Default is "true"

### :create_user Specific Attributes

- user_name: Name of user account to create
- user_pass: Password for the user account
- user_enabled: Enable or Disable user
 - Accepted values are [ "true", "false" ]
 - Default is "true"
- tenant_name: Name of tenant to create user in

### :create_role Specific Attributes

- role_name: Name of the role to create

### :grant_role Specific Attributes

- role_name: Name of the role to grant
- user_name: User name to grant the role to
- tenant_name: Name of tenant to grant role in

### :create_service Specific Attributes

- service_name: Name of service
- service_description: Description of service
- service_type: Type of service to create
 - Accepted values are [ "image", "identity", "compute", "storage", "ec2", "volume", "object-store", "metering", "network", "orchestration", "cloudformation" ]
- **NOTE:** call will be skipped if `openstack['identity']['catalog']['backend']` is set to 'templated'

### :create_endpoint Specific Attributes

- endpoint_region: Default value is "RegionOne"
- endpoint_adminurl: URL to admin endpoint (using admin port)
- endpoint_internalurl: URL to service endpoint (using service port)
- endpoint_publicurl: URL to public endpoint
 - Default is same as endpoint_internalURL
- service_type: Type of service to create endpoint for
 - Accepted values are [ "image", "identity", "compute", "storage", "ec2", "volume", "object-store", "metering", "network", "orchestration", "cloudformation" ]
- **NOTE:** call will be skipped if `openstack['identity']['catalog']['backend']` is set to 'templated'

### Examples

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

credentials
-----------

Create EC2 credentials for a given user in the specified tenant

### Actions

- :create_ec2: create EC2 credentials

### General Attributes

- auth_protocol: Required communication protocol with Keystone server. Acceptable values are [ "http", "https" ]
- auth_host: Keystone server IP Address
- auth_port: Port Keystone server is listening on
- api_ver: API Version for Keystone server
 - Accepted values are [ "/v2.0" ]
- auth_token: Auth Token for communication with Keystone server

### :create_ec2 Specific Attributes

- user_name: User name to grant the credentials for
- tenant_name: Tenant name to grant the credentials in

### Examples

    openstack_identity_credentials "Create EC2 credentials for 'admin' user" do
      auth_host "192.168.1.10"
      auth_port "35357"
      auth_protocol "http"
      api_ver "/v2.0"
      auth_token "123456789876"
      user_name "admin"
      tenant_name "openstack"
    end

Attributes
==========

Please refer to the Common cookbook for more attributes.

* `openstack['identity']['db_server_chef_role']` - The name of the Chef role that knows about the db server
* `openstack['identity']['user']` - User keystone runs as
* `openstack['identity']['group']` - Group keystone runs as
* `openstack['identity']['db']` - Name of keystone database
* `openstack['identity']['db_user']` - Username for keystone database access
* `openstack['identity']['db_passwd']` - Password for keystone database access
* `openstack['identity']['db_ipaddress']` - IP address of the keystone database
* `openstack['identity']['api_ipaddress']` - IP address for the keystone API to bind to. _TODO_: Rename to bind_address
* `openstack['identity']['verbose']` - Enables/disables verbose output for keystone API server
* `openstack['identity']['debug']` - Enables/disables debug output for keystone API server
* `openstack['identity']['admin_token']` - Admin token for bootstraping keystone server
* `openstack['identity']['admin_workers']` - The number of worker processes to serve the admin WSGI application
* `openstack['identity']['public_workers']` - The number of worker processes to serve the public WSGI application
* `openstack['identity']['roles']` - Array of roles to create in the keystone server
* `openstack['identity']['users']` - Array of users to create in the keystone server
* `openstack['identity']['pastefile_url']` - Specify the URL for a keystone-paste.ini file that will override the default packaged file
* `openstack['identity']['token']['expiration']` - Token validity time in seconds
* `openstack['identity']['token']['hash_algorithm']` - Hash algorithms to use for hashing PKI tokens
* `openstack['identity']['catalog']['backend']` - Storage mechanism for the keystone service catalog
* `openstack['identity']["control_exchange"]` - The AMQP exchange to connect to if using RabbitMQ or Qpid, defaults to openstack
* `openstack['identity']['rpc_backend']` - The messaging module to use
* `openstack['identity']['rpc_thread_pool_size']` - Size of RPC thread pool
* `openstack['identity']['rpc_conn_pool_size']` - Size of RPC connection pool
* `openstack['identity']['rpc_response_timeout']` - Seconds to wait for a response from call or multicall
* `openstack['identity']['ldap']['url']` - LDAP host URL (default: 'ldap://localhost')
* `openstack['identity']['ldap']['user']` - LDAP bind DN (default: 'dc=Manager,dc=example,dc=com')
* `openstack['identity']['ldap']['password']` - LDAP bind password (default: nil)
* `openstack['identity']['ldap']['use_tls']` - Use TLS for LDAP (default: false)
* `openstack['identity']['ldap']['tls_cacertfile']` - Path to CA cert file (default: nil)
* `openstack['identity']['ldap']['tls_cacertdir']` - Path to CA cert directory (default: nil)
* `openstack['identity']['ldap']['tls_req_cert']` - CA cert check ('demand', 'allow' or 'never', default: 'demand')
* `openstack['identity']['ldap']['use_pool']` - Enable LDAP connection pool
* `openstack['identity']['ldap']['pool_size']` - Connection pool size
* `openstack['identity']['ldap']['pool_retry_max']` - Maximum count of reconnect trials
* `openstack['identity']['ldap']['pool_retry_delay']` - Time span in seconds to wait between two reconnect trials (floating point value)
* `openstack['identity']['ldap']['pool_connection_timeout']` - Connector timeout in seconds. Value -1 indicates indefinite
* `openstack['identity']['ldap']['pool_connection_lifetime']` - Connection lifetime in seconds.(integer value)
* `openstack['identity']['ldap']['use_auth_pool']` - Enable LDAP connection pooling for end user authentication
* `openstack['identity']['ldap']['auth_pool_size']` - End user auth connection pool size. (integer value)
* `openstack['identity']['ldap']['auth_pool_connection_lifetime']` -  End user auth connection lifetime in seconds. (integervalue)

* `openstack['identity']['misc_keystone']` - **Array of strings to be added to keystone.conf**
* `openstack['identity']['list_limit']` - Maximum number of entities that will be returned in a collection
* `openstack['identity']['assignment']['list_limit']` - Maximum number of entities that will be returned in a assignment collection
* `openstack['identity']['catalog']['list_limit']` - Maximum number of entities that will be returned in a catalog collection
* `openstack['identity']['identity']['list_limit']` - Maximum number of entities that will be returned in a identity collection
* `openstack['identity']['policy']['list_limit']` - Maximum number of entities that will be returned in a policy collection
* `openstack['identity']['pipeline']['public_api']` - Pipeline of identity public api
* `openstack['identity']['pipeline']['admin_api']` - Pipeline of identity admin api
* `openstack['identity']['pipeline']['api_v3']` - Pipeline of identity V3 api
* `openstack['identity']['ssl']['enabled']` - Enable HTTPS Keystone API endpoint. Default is false
* `openstack['identity']['ssl']['cert_required']` - When SSL is enabled this flag is used to require client certificate. Default is false.
* `openstack['identity']['ssl']['basedir']` - Path to Keystone SSL directory
* `openstack['identity']['ssl']['certfile']`- Cert file location
* `openstack['identity']['ssl']['keyfile']` - Key file location
* `openstack['identity']['ssl']['ca_certs']` - Path to CA certificate file

Most `openstack['identity']['ldap']` attributes map directly to the corresponding config options in keystone.conf's `[ldap]` backend.  They are primarily used when configuring `openstack['identity']['identity']['backend']` and/or `openstack["identity"]["assignment"]["backend"]` as `ldap` (both default to `sql`).

The `openstack['identity']['ldap']['use_tls']` option should not be used in conjunction with an `ldaps://` url.  When the latter is used (and `openstack['identity']['ldap']['use_tls'] = false`), the certificate path and validation will instead be subject to the OS's LDAP config.

If `openstack['identity']['ldap']['tls_cacertfile']` is set, `openstack['identity']['ldap']['tls_cacertdir']` will be ignored.  Set `openstack['identity']['ldap']['tls_cacertfile']` to `nil` if `openstack['identity']['ldap']['tls_cacertdir']` is desired.
Values of `openstack['identity']['ldap']['tls_req_cert']` correspond to the standard options permitted by the TLS_REQCERT TLS option (`never` performs no validation of certs, `allow` performs some basic name checks but no thorough CA validation, `demand` requires the certificate chain to be valid for the connection to succeed).

The following attributes are defined in attributes/default.rb of the common cookbook, but are documented here due to their relevance:

* `openstack['endpoints']['identity-bind']['host']` - The IP address to bind the identity services to
* `openstack['endpoints']['identity-bind']['scheme']` - Unused
* `openstack['endpoints']['identity-bind']['port']` - Unused
* `openstack['endpoints']['identity-bind']['path']` - Unused
* `openstack['endpoints']['identity-bind']['bind_interface']` - The interface name to bind the identity services to

If the value of the 'bind_interface' attribute is non-nil, then the identity service will be bound to the first IP address on that interface.  If the value of the 'bind_interface' attribute is nil, then the identity service will be bound to the IP address specified in the host attribute.

### SSL enabling
To enable SSL on Keystone, a key and certficate must be created and installed on server running Keystone. The location of these files can be provided with the node attributes described above. Also, note that `openstack['endpoints']['identity-bind']['scheme']`, from openstack common cookbook, must be set to 'https' in order to enable SSL.

### Token flushing
When managing tokens with an SQL backend the token database may grow unboundedly as new tokens are issued and expired
tokens are not disposed of. Expired tokens may need to be kept around in order to allow for auditability.

It is up to deployers to define when their tokens can be safely deleted. Keystone provides a tool to purge expired tokens,
and the server recipe can create a cronjob to run that tool. By default the cronjob will be configured to run hourly.

The flush tokens cronjob configuration parameters are listed below:

* `openstack['identity']['token_flush_cron']['enabled']` - Boolean indicating whether the flush tokens cronjob is enabled. It is by default enabled if the token backend is 'sql'.
* `openstack['identity']['token_flush_cron']['log_file']` - The log file for the flush tokens tool.
* `openstack['identity']['token_flush_cron']['hour']` - The hour at which the flush tokens cronjob should run (values 0 - 23).
* `openstack['identity']['token_flush_cron']['minute']` - The minute at which the flush tokens cronjob should run (values 0 - 59).
* `openstack']['identity']['token_flush_cron']['day']` - The day of the month when the flush tokens cronjob should run (values 1 - 31).
* `openstack['identity']['token_flush_cron']['weekday']` = The day of the week at which the flush tokens cronjob should run (values 0 - 6, where Sunday is 0).

Testing
=====

Please refer to the [TESTING.md](TESTING.md) for instructions for testing the cookbook.

Berkshelf
=====

Berks will resolve version requirements and dependencies on first run and
store these in Berksfile.lock. If new cookbooks become available you can run
`berks update` to update the references in Berksfile.lock. Berksfile.lock will
be included in stable branches to provide a known good set of dependencies.
Berksfile.lock will not be included in development branches to encourage
development against the latest cookbooks.

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
Author:: Jan Klare (j.klare@x-ion.de)

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
