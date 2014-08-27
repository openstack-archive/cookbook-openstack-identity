# CHANGELOG for cookbook-openstack-identity
This file is used to list changes made in each version of cookbook-openstack-identity.

## 10.0.1
* Update keystone.conf from mode 0644 to 0640
* Allow hash_algorithm to be configurable
* Raise exceptions when register provider keystone command fails
* Allow admin_bind_host to be settable in the keystone.conf template
* Add attributes for saml
* Allow attributes for domain specific drivers
* Allow existing users to have their passwords updated properly
* Bump Chef gem to 11.16
* Add test to verify each endpoint can be configured seperatly

## 10.0.0
* Upgrading to Juno
* Upgrading berkshelf from 2.0.18 to 3.1.5
* Fix the internal endpoint URL by using the InternalURL variable rather than AdminURL
* Sync conf files with Juno
* Allow admin and public workers to be configured
* Allow list_limit to be configurable
* Fix registration issue by adding '--insecure' to keystone command

## 9.3.1
* Add support for a templated keystone-paste.ini
  as well as support misc_paste options inserted
* bump berkshelf to 2.0.18 to allow Supermarket support
* fix fauxhai version for suse and redhat

## 9.3.0
* python_packages database client attributes have been migrated to the -common cookbook

## 9.2.1
* Add support for TLS in [ldap]

## 9.2.0
* Add support for miscellaneous options (like in Compute)

## 9.1.1
* Fix package action to allow updates

## 9.1.0
* Add token flushing cronjob

## 9.0.0
* Upgrade to Icehouse

## 8.1.3
* Remove duplicate service and admin ports attributes that are in Common LP1281108

## 8.1.2
### Bug
* Fix the DB2 ODBC driver issue

## 8.1.1
* Adding guard on register LWRP (:create_service) to not run if backend is 'templated'
* Adding guard on register LWRP (:create_endpoint) to not run if backend is 'templated'

## 8.1.0
* Add client recipe

## 8.0.0
* Updating to Havana
* Updating cookbook-openstack-common dep from 0.3.0 to 0.4.7

## 7.2.0:
* Allow orchestration and cloudformation as service/endpoint types.

## 7.1.0:
* Add new attribute default["openstack"]["identity"]["policy"]["backend"], default is 'sql'.

## 7.0.2:
### Bug
* Do not delete the sqlite database when node.openstack.db.identity.db_type is set to sqlite.
* Added `does not delete keystone.db when configured to use sqlite` test case for this scenario

## 7.0.1:
* Fixed <db_type>_python_packages issue when setting node.openstack.db.identity.db_type to sqlite.
* Added `converges when configured to use sqlite db backend` test case for this scenario.

## 7.0.0:
* Initial release of cookbook-openstack-identity.

- - -
Check the [Markdown Syntax Guide](http://daringfireball.net/projects/markdown/syntax) for help with Markdown.

The [Github Flavored Markdown page](http://github.github.com/github-flavored-markdown/) describes the differences between markdown on github and standard markdown.
