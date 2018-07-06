# encoding: UTF-8
#

require_relative 'spec_helper'

describe 'openstack-identity::server-apache' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include Helpers
    include_context 'identity_stubs'

    service_name = 'keystone'
    service_user = 'admin'
    region = 'RegionOne'
    project_name = 'admin'
    role_name = 'admin'
    password = 'admin'
    admin_url = 'http://127.0.0.1:5000/v3'
    public_url = 'http://127.0.0.1:5000/v3'
    internal_url = 'http://127.0.0.1:5000/v3'

    it 'runs logging recipe if node attributes say to' do
      node.set['openstack']['identity']['syslog']['use'] = true
      expect(chef_run).to include_recipe('openstack-common::logging')
    end

    it 'does not run logging recipe' do
      expect(chef_run).not_to include_recipe('openstack-common::logging')
    end

    it 'upgrades mysql python packages' do
      expect(chef_run).to upgrade_package('identity cookbook package python-mysqldb')
    end

    it 'upgrades memcache python packages' do
      expect(chef_run).to upgrade_package('identity cookbook package python-memcache')
    end

    it 'upgrades keystone packages' do
      expect(chef_run).to upgrade_package('identity cookbook package keystone')
    end

    it 'bootstrap with keystone-manage' do
      expect(chef_run).to run_execute('bootstrap_keystone').with(command: "keystone-manage bootstrap \\
          --bootstrap-password #{password} \\
          --bootstrap-username #{service_user} \\
          --bootstrap-project-name #{project_name} \\
          --bootstrap-role-name #{role_name} \\
          --bootstrap-service-name #{service_name} \\
          --bootstrap-region-id #{region} \\
          --bootstrap-admin-url #{admin_url} \\
          --bootstrap-public-url #{public_url} \\
          --bootstrap-internal-url #{internal_url}")
    end

    describe '/etc/keystone' do
      let(:dir) { chef_run.directory('/etc/keystone') }

      it 'creates directory /etc/keystone' do
        expect(chef_run).to create_directory(dir.name).with(
          user: 'keystone',
          group: 'keystone',
          mode: 0o0700
        )
      end
    end

    describe '/etc/keystone/domains' do
      let(:dir) { '/etc/keystone/domains' }

      it 'does not create /etc/keystone/domains by default' do
        expect(chef_run).not_to create_directory(dir)
      end

      it 'creates /etc/keystone/domains when domain_specific_drivers_enabled enabled' do
        node.set['openstack']['identity']['identity']['domain_specific_drivers_enabled'] = true
        expect(chef_run).to create_directory(dir).with(
          user: 'keystone',
          group: 'keystone',
          mode: 0o0700
        )
      end
    end

    it 'deletes keystone.db' do
      expect(chef_run).to delete_file('/var/lib/keystone/keystone.db')
    end

    it 'does not delete keystone.db when configured to use sqlite' do
      node.set['openstack']['db']['identity']['service_type'] = 'sqlite'
      expect(chef_run).not_to delete_file('/var/lib/keystone/keystone.db')
    end

    describe 'keystone.conf' do
      let(:path) { '/etc/keystone/keystone.conf' }
      let(:resource) { chef_run.template(path) }
      describe 'file properties' do
        it 'creates /etc/keystone/keystone.conf' do
          expect(chef_run).to create_template(resource.name).with(
            user: 'keystone',
            group: 'keystone',
            mode: 0o0640
          )
        end
      end

      it 'has no list_limits by default' do
        expect(chef_run).not_to render_config_file(path).with_section_content('DEFAULT', /^list_limit = /)
      end

      it 'has default transport_url/AMQP options set' do
        [%r{^transport_url = rabbit://openstack:mypass@127.0.0.1:5672$}].each do |line|
          expect(chef_run).to render_file(path).with_content(line)
        end
      end

      describe '[DEFAULT] section' do
        describe 'syslog configuration' do
          log_file = %r{^log_dir = /var/log/keystone$}
          log_conf = %r{^log_config_append = /\w+}

          it 'renders log_file correctly' do
            expect(chef_run).to render_config_file(path).with_section_content('DEFAULT', log_file)
            expect(chef_run).not_to render_config_file(path).with_section_content('DEFAULT', log_conf)
          end

          it 'renders log_config correctly' do
            node.set['openstack']['identity']['syslog']['use'] = true

            expect(chef_run).to render_config_file(path).with_section_content('DEFAULT', log_conf)
            expect(chef_run).not_to render_config_file(path).with_section_content('DEFAULT', log_file)
          end
        end

        it 'has correct endpoints' do
          # values correspond to node attrs set in chef_run above
          pub = line_regexp('public_endpoint = http://127.0.0.1:5000/')

          expect(chef_run).to render_config_file(path).with_section_content('DEFAULT', pub)
        end
      end

      describe '[memcache] section' do
        it 'has no servers by default' do
          # `Openstack#memcached_servers' is stubbed in spec_helper.rb to
          # return an empty array, so we expect an empty `servers' list.
          r = line_regexp('servers = ')
          expect(chef_run).to render_config_file(path).with_section_content('memcache', r)
        end

        it 'has servers when hostnames are configured' do
          # Re-stub `Openstack#memcached_servers' here
          hosts = ['host1:111', 'host2:222']
          r = line_regexp("servers = #{hosts.join(',')}")

          allow_any_instance_of(Chef::Recipe).to receive(:memcached_servers)
            .and_return(hosts)
          expect(chef_run).to render_config_file(path).with_section_content('memcache', r)
        end
      end

      describe '[sql] section' do
        it 'has a connection' do
          r = /^connection = \w+/
          expect(chef_run).to render_config_file(path).with_section_content('database', r)
        end
      end

      describe '[ldap] section' do
        describe 'optional nil attributes' do
          optional_attrs = %w(group_tree_dn group_filter user_filter
                              user_tree_dn user_enabled_emulation_dn
                              group_attribute_ignore role_attribute_ignore
                              role_tree_dn role_filter project_tree_dn
                              project_enabled_emulation_dn project_filter
                              project_attribute_ignore)

          it 'does not configure attributes' do
            optional_attrs.each do |a|
              r = /^#{Regexp.quote(a)}  = $/
              expect(chef_run).not_to render_config_file(path).with_section_content('ldap', r)
            end
          end

          context 'ssl settings' do
            context 'when use_tls disabled' do
              it 'does not set tls_ options if use_tls is disabled' do
                [/^tls_cacertfile = /, /^tls_cacertdir = /, /^tls_req_cert = /].each do |setting|
                  expect(chef_run).not_to render_config_file(path).with_section_content('ldap', setting)
                end
              end
            end

            context 'when use_tls enabled' do
              before do
                node.set['openstack']['identity']['ldap']['use_tls'] = true
              end
            end
          end
        end
      end

      describe '[assignment] section' do
        it 'configures driver' do
          r = line_regexp('driver = sql')
          expect(chef_run).to render_config_file(path).with_section_content('assignment', r)
        end
      end

      describe '[catalog] section' do
        # use let() to access Helpers#line_regexp method
        let(:templated) do
          str = 'driver = keystone.catalog.backends.templated.TemplatedCatalog'
          line_regexp(str)
        end
        let(:sql) do
          line_regexp('driver = sql')
        end

        it 'configures driver' do
          expect(chef_run).to render_config_file(path).with_content(sql)
          expect(chef_run).not_to render_config_file(path).with_section_content('catalog', templated)
        end
      end

      describe '[policy] section' do
        it 'configures driver' do
          r = line_regexp('driver = sql')
          expect(chef_run).to render_config_file(path).with_section_content('policy', r)
        end
      end
    end

    describe 'default_catalog.templates' do
      let(:file) { '/etc/keystone/default_catalog.templates' }

      describe 'without templated backend' do
        it 'does not create' do
          expect(chef_run).not_to render_file(file)
        end
      end
    end

    describe 'db_sync' do
      let(:cmd) { 'keystone-manage db_sync' }

      it 'runs migrations' do
        expect(chef_run).to run_execute(cmd).with(
          user: 'root'
        )
      end

      it 'does not run migrations' do
        node.set['openstack']['db']['identity']['migrate'] = false
        expect(chef_run).not_to run_execute(cmd).with(
          user: 'root'
        )
      end
    end

    describe 'keystone-paste.ini as template' do
      let(:path) { '/etc/keystone/keystone-paste.ini' }
      let(:template) { chef_run.template(path) }

      it 'creates /etc/keystone/default_catalog.templates' do
        expect(chef_run).to create_template(template.name).with(
          user: 'keystone',
          group: 'keystone',
          mode: 0o644
        )
      end

      it 'has default api pipeline values' do
        expect(chef_run).to render_config_file(path).with_section_content(
          'pipeline:public_api',
          /^pipeline = healthcheck cors sizelimit http_proxy_to_wsgi osprofiler url_normalize request_id build_auth_context token_auth json_body ec2_extension public_service$/
        )
        expect(chef_run).to render_config_file(path).with_section_content(
          'pipeline:admin_api',
          /^pipeline = healthcheck cors sizelimit http_proxy_to_wsgi osprofiler url_normalize request_id build_auth_context token_auth json_body ec2_extension s3_extension admin_service$/
        )
        expect(chef_run).to render_config_file(path).with_section_content(
          'pipeline:api_v3',
          /^pipeline = healthcheck cors sizelimit http_proxy_to_wsgi osprofiler url_normalize request_id build_auth_context token_auth json_body ec2_extension_v3 s3_extension service_v3$/
        )
      end
      it 'template api pipeline set correct' do
        node.set['openstack']['identity']['pipeline']['public_api'] = 'public_service'
        node.set['openstack']['identity']['pipeline']['api_v3'] = 'service_v3'
        expect(chef_run).to render_config_file(path).with_section_content(
          'pipeline:public_api',
          /^pipeline = public_service$/
        )
        expect(chef_run).to render_config_file(path).with_section_content(
          'pipeline:api_v3',
          /^pipeline = service_v3$/
        )
      end
      it 'template misc_paste array correctly' do
        node.set['openstack']['identity']['misc_paste'] = ['MISC1 = OPTION1', 'MISC2 = OPTION2']
        expect(chef_run).to render_file(path).with_content(
          /^MISC1 = OPTION1$/
        )
        expect(chef_run).to render_file(path).with_content(
          /^MISC2 = OPTION2$/
        )
      end
    end

    describe 'keystone-paste.ini as remote file' do
      before { node.set['openstack']['identity']['pastefile_url'] = 'http://server/mykeystone-paste.ini' }
      let(:remote_paste) { chef_run.remote_file('/etc/keystone/keystone-paste.ini') }

      it 'uses a remote file if pastefile_url is specified' do
        expect(chef_run).to create_remote_file_if_missing('/etc/keystone/keystone-paste.ini').with(
          source: 'http://server/mykeystone-paste.ini',
          user: 'keystone',
          group: 'keystone',
          mode: 0o0644
        )
      end
    end

    describe 'apache setup' do
      it 'set apache addresses and ports' do
        expect(chef_run.node['apache']['listen']).to eq(%w(127.0.0.1:5000))
      end

      describe 'apache recipes' do
        it 'include apache recipes' do
          expect(chef_run).to include_recipe('apache2')
          expect(chef_run).to include_recipe('apache2::mod_wsgi')
          expect(chef_run).not_to include_recipe('apache2::mod_ssl')
        end

        it 'include apache recipes' do
          node.set['openstack']['identity']['ssl']['enabled'] = true
          expect(chef_run).to include_recipe('apache2::mod_ssl')
        end
      end

      describe 'apache wsgi' do
        let(:file) { '/etc/apache2/sites-available/identity.conf' }

        it 'creates identity.conf' do
          expect(chef_run).to create_template(file).with(
            user: 'root',
            group: 'root',
            mode: '0644'
          )
        end

        it 'does not configure keystone-admin.conf' do
          expect(chef_run).not_to render_file('/etc/apache2/sites-available/keystone-admin.conf')
        end

        it 'configures identity.conf lines' do
          node.set['openstack']['identity']['custom_template_banner'] = 'custom_template_banner_value'
          [/^custom_template_banner_value$/,
           /user=keystone/,
           /group=keystone/,
           %r{^    ErrorLog /var/log/apache2/identity.log$},
           %r{^    CustomLog /var/log/apache2/identity_access.log combined$}].each do |line|
            expect(chef_run).to render_file(file).with_content(line)
          end
        end

        it 'does not configure identity.conf triggered common lines' do
          [/^    LogLevel/,
           /^    SSL/].each do |line|
            expect(chef_run).not_to render_file(file).with_content(line)
          end
        end

        context 'Enable SSL' do
          let(:file) { '/etc/apache2/sites-available/identity.conf' }
          before do
            node.set['openstack']['identity']['ssl']['enabled'] = true
          end
          it 'configures identity.conf common ssl lines' do
            [/^    SSLEngine On$/,
             %r{^    SSLCertificateFile /etc/keystone/ssl/certs/sslcert.pem$},
             %r{^    SSLCertificateKeyFile /etc/keystone/ssl/private/sslkey.pem$},
             %r{^    SSLCACertificatePath /etc/keystone/ssl/certs/$},
             /^    SSLProtocol All -SSLv2 -SSLv3$/].each do |line|
              expect(chef_run).to render_file(file).with_content(line)
            end
          end
          it 'does not configure identity.conf common ssl lines' do
            [/^    SSLCertificateChainFile/,
             /^    SSLCipherSuite/,
             /^    SSLVerifyClient require/].each do |line|
              expect(chef_run).not_to render_file(file).with_content(line)
            end
          end
          it 'configures identity.conf chainfile when set' do
            node.set['openstack']['identity']['ssl']['chainfile'] = '/etc/keystone/ssl/certs/chainfile.pem'
            expect(chef_run).to render_file(file)
              .with_content(%r{^    SSLCertificateChainFile /etc/keystone/ssl/certs/chainfile.pem$})
          end
          it 'configures identity.conf ciphers when set' do
            node.set['openstack']['identity']['ssl']['ciphers'] = 'ciphers_value'
            expect(chef_run).to render_file(file)
              .with_content(/^    SSLCipherSuite ciphers_value$/)
          end
          it 'configures identity.conf cert_required set' do
            node.set['openstack']['identity']['ssl']['cert_required'] = true
            expect(chef_run).to render_file(file)
              .with_content(/^    SSLVerifyClient require$/)
          end
        end
      end

      describe 'identity.conf' do
        let(:file) { '/etc/apache2/sites-available/identity.conf' }
        it 'configures required lines' do
          [/^<VirtualHost 127.0.0.1:5000>$/,
           /^    WSGIDaemonProcess identity/,
           /^    WSGIProcessGroup identity$/,
           %r{^    WSGIScriptAlias / /usr/bin/keystone-wsgi-public$}].each do |line|
            expect(chef_run).to render_file(file).with_content(line)
          end
        end
      end

      describe 'restart apache' do
        let(:restart) { chef_run.execute('Keystone apache restart') }

        it 'has restart resource' do
          expect(chef_run).to run_execute(restart.name).with(
            command: 'uname'
          )
        end

        it 'has notified apache to restart' do
          expect(restart).to notify('service[apache2]').to(:restart).immediately
        end
      end
    end
  end
end
