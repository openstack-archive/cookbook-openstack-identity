name 'openstack-identity'
maintainer 'openstack-chef'
maintainer_email 'openstack-dev@lists.openstack.org'
license 'Apache 2.0'
description 'The OpenStack Identity service Keystone.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '13.0.0'

recipe 'openstack-identity::client', 'Install packages required for keystone client'
recipe 'openstack-identity::server-apache', 'Installs and Configures Keystone Service under Apache'
recipe 'openstack-identity::registration', 'Adds user, tenant, role and endpoint records to Keystone'
recipe 'openstack-identity::openrc', 'Creates openrc file'

%w(ubuntu redhat centos).each do |os|
  supports os
end

depends 'apache2', '~> 3.1.0'
depends 'openstack-common', '>= 13.0.0'
