name             'openstack-identity'
maintainer       'openstack-chef'
maintainer_email 'openstack-discuss@lists.openstack.org'
license          'Apache-2.0'
description      'The OpenStack Identity service Keystone.'
version          '18.0.0'

recipe 'cloud_config', 'Manage the cloud config file located at /root/clouds.yaml'
recipe '_credential_tokens', 'Helper recipe to manage credential keys'
recipe '_fernet_tokens', 'Helper recipe to manage fernet tokens'
recipe 'openrc', 'Creates a fully usable openrc file'
recipe 'registration', 'Registers the initial keystone endpoint as well as users, tenants and roles'
recipe 'server-apache', 'Installs and configures the OpenStack Identity Service running inside of an apache webserver.'

%w(ubuntu redhat centos).each do |os|
  supports os
end

depends 'apache2', '~> 8.0'
depends 'openstackclient'
depends 'openstack-common', '>= 18.0.0'

issues_url 'https://launchpad.net/openstack-chef'
source_url 'https://opendev.org/openstack/cookbook-openstack-identity'
chef_version '>= 14.0'
