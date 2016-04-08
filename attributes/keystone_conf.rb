default['openstack']['identity']['conf_secrets'] = {}
default['openstack']['identity']['conf'].tap do |conf|
  # [DEFAULT]
  if node['openstack']['identity']['syslog']['use']
    conf['DEFAULT']['log_config_append'] = '/etc/openstack/logging.conf'
  else
    conf['DEFAULT']['log_dir'] = '/var/log/keystone'
  end
  if node['openstack']['identity']['notification_driver'] == 'messaging'
    conf['DEFAULT']['notification_topics'] = 'notifications'
  end
  conf['DEFAULT']['rpc_backend'] = node['openstack']['mq']['service_type']

  # [assignment]
  conf['assignment']['driver'] = 'keystone.assignment.backends.sql.Assignment'

  # [auth]
  conf['auth']['external'] = 'keystone.auth.plugins.external.DefaultDomain'
  conf['auth']['methods'] = 'external, password, token, oauth1'

  # [catalog]
  conf['catalog']['driver'] = 'keystone.catalog.backends.sql.Catalog'

  # [identity]
  conf['identity']['domain_specific_drivers_enabled'] = false

  # [policy]
  conf['policy']['driver'] = 'keystone.policy.backends.sql.Policy'
end
