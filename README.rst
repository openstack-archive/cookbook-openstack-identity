OpenStack Chef Cookbook - identity
==================================

.. image:: https://governance.openstack.org/badges/cookbook-openstack-identity.svg
    :target: https://governance.openstack.org/reference/tags/index.html

Description
===========

This cookbook installs the OpenStack Identity Service **Keystone** as
part of the OpenStack reference deployment Chef for OpenStack. The
`OpenStack chef-repo`_ contains documentation for using this cookbook in
the context of a full OpenStack deployment.  Keystone is installed from
packages, creating the default user, tenant, and roles. It also
registers the identity service and identity endpoint.

.. _OpenStack chef-repo: https://opendev.org/openstack/openstack-chef

https://docs.openstack.org/keystone/latest/

Requirements
============

- Chef 16 or higher
- Chef Workstation 21.10.640 for testing (also includes Berkshelf for
  cookbook dependency resolution)

Platform
========

- ubuntu
- redhat
- centos

Cookbooks
=========

The following cookbooks are dependencies:

- 'apache2', '~> 8.6'
- 'openstack-common', '>= 20.0.0'
- 'openstackclient'

Attributes
==========

Please see the extensive inline documentation in ``attributes/*.rb`` for
descriptions of all the settable attributes for this cookbook.

Note that all attributes are in the ``default['openstack']`` "namespace"

The usage of attributes to generate the ``keystone.conf`` is described
in the openstack-common cookbook.

Recipes
=======

openstack-identity::cloud_config
--------------------------------

- Manage the cloud config file located at ``/root/clouds.yaml``

openstack-identity::_credential_tokens
--------------------------------------

- Helper recipe to manage credential keys.

If you prefer, you can manually create the keys by doing the following:

.. code-block:: console

  $ keystone-manage credential_setup \
    --keystone-user keystone --keystone-group keystone

This should create a directory ``/etc/keystone/credential-keys`` with
the keys residing in it.

openstack-identity::_fernet_tokens
----------------------------------

- Helper recipe to manage fernet tokens

openstack-identity::openrc
--------------------------

- Creates a fully usable openrc file to export the needed environment
  variables to use the openstack client.

openstack-identity::registration
--------------------------------

- Registers the initial keystone endpoint as well as users, tenants and
  roles needed for the initial configuration utilizing the custom
  resource provided in the openstackclient cookbook. The recipe is
  documented in detail with inline comments inside the recipe.

openstack-identity::server-apache
---------------------------------

- Installs and configures the OpenStack Identity Service running inside
  of an apache webserver. The recipe is documented in detail with inline
  comments inside the recipe.

License and Author
==================

+------------+-------------------------------------------------+
| **Author** | Justin Shepherd (justin.shepherd@rackspace.com) |
+------------+-------------------------------------------------+
| **Author** | Jason Cannavale (jason.cannavale@rackspace.com) |
+------------+-------------------------------------------------+
| **Author** | Ron Pedde (ron.pedde@rackspace.com)             |
+------------+-------------------------------------------------+
| **Author** | Joseph Breu (joseph.breu@rackspace.com)         |
+------------+-------------------------------------------------+
| **Author** | William Kelly (william.kelly@rackspace.com)     |
+------------+-------------------------------------------------+
| **Author** | Darren Birkett (darren.birkett@rackspace.co.uk) |
+------------+-------------------------------------------------+
| **Author** | Evan Callicoat (evan.callicoat@rackspace.com)   |
+------------+-------------------------------------------------+
| **Author** | Matt Ray (matt@opscode.com)                     |
+------------+-------------------------------------------------+
| **Author** | Jay Pipes (jaypipes@att.com)                    |
+------------+-------------------------------------------------+
| **Author** | John Dewey (jdewey@att.com)                     |
+------------+-------------------------------------------------+
| **Author** | Sean Gallagher (sean.gallagher@att.com)         |
+------------+-------------------------------------------------+
| **Author** | Ionut Artarisi (iartarisi@suse.cz)              |
+------------+-------------------------------------------------+
| **Author** | Chen Zhiwei (zhiwchen@cn.ibm.com)               |
+------------+-------------------------------------------------+
| **Author** | Eric Zhou (zyouzhou@cn.ibm.com)                 |
+------------+-------------------------------------------------+
| **Author** | Jan Klare (j.klare@cloudbau.de)                 |
+------------+-------------------------------------------------+
| **Author** | Christoph Albers (c.albers@x-ion.de)            |
+------------+-------------------------------------------------+
| **Author** | Lance Albertson (lance@osuosl.org)              |
+------------+-------------------------------------------------+

+---------------+----------------------------------------------+
| **Copyright** | Copyright 2012, Rackspace US, Inc.           |
+---------------+----------------------------------------------+
| **Copyright** | Copyright 2012-2013, Opscode, Inc.           |
+---------------+----------------------------------------------+
| **Copyright** | Copyright 2012-2013, AT&T Services, Inc.     |
+---------------+----------------------------------------------+
| **Copyright** | Copyright 2013-2014, SUSE Linux              |
+---------------+----------------------------------------------+
| **Copyright** | GmbH Copyright 2013-2014, IBM, Corp.         |
+---------------+----------------------------------------------+
| **Copyright** | Copyright 2016-2021, Oregon State University |
+---------------+----------------------------------------------+

Licensed under the Apache License, Version 2.0 (the "License"); you may
not use this file except in compliance with the License. You may obtain
a copy of the License at

::

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
