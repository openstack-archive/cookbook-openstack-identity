name 'openstack-identity'
maintainer 'openstack-chef'
maintainer_email 'openstack-dev@lists.openstack.org'
license 'Apache 2.0'
description 'The OpenStack Identity service Keystone.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '14.0.0'

%w(ubuntu redhat centos).each do |os|
  supports os
end

depends 'apache2', '~> 3.1'
depends 'openstack-common', '>= 14.0.0'
