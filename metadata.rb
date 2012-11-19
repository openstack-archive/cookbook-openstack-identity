maintainer       "Opscode, Inc."
maintainer_email "matt@opscode.com"
license          "Apache 2.0"
description      "The OpenStack Identity service Keystone."
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "2012.1.0"
name             "keystone"

%w{ ubuntu fedora }.each do |os|
  supports os
end

recipe           "keystone::db", "Configures database for use with keystone"
recipe           "keystone::server", "Installs and Configures Keystone Service"

depends          "database"
depends          "mysql"
depends          "openstack-common"
