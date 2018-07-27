source 'https://supermarket.chef.io'

if Dir.exist?('../cookbook-openstack-common')
  cookbook 'openstack-common', path: '../cookbook-openstack-#{cookbook}'
else
  cookbook 'openstack-common', git: 'https://git.openstack.org/openstack/cookbook-openstack-common', branch: 'stable/queens'
end

if Dir.exist?('../cookbook-openstackclient')
  cookbook 'openstackclient', path: '../cookbook-openstackclient'
else
  cookbook 'openstackclient', git: 'https://git.openstack.org/openstack/cookbook-openstackclient', branch: 'stable/queens'
end

metadata
