name 'openstack-identity'
maintainer 'openstack-chef'
maintainer_email 'openstack-dev@lists.openstack.org'
license 'Apache 2.0'
description 'The OpenStack Identity service Keystone.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '12.0.0'

recipe 'openstack-identity::client', 'Install packages required for keystone client'
recipe 'openstack-identity::server', 'Installs and Configures Keystone Service'
recipe 'openstack-identity::server-apache', 'Installs and Configures Keystone Service under Apache'
recipe 'openstack-identity::registration', 'Adds user, tenant, role and endpoint records to Keystone'

%w(ubuntu fedora redhat centos suse).each do |os|
  supports os
end

depends 'apache2', '~> 3.1.0'
depends 'openstack-common', '>= 12.0.0'
