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

    it 'upgrades postgresql python packages if explicitly told' do
      node.set['openstack']['db']['identity']['service_type'] = 'postgresql'
      expect(chef_run).to upgrade_package('identity cookbook package python-psycopg2')
    end

    it 'upgrades memcache python packages' do
      expect(chef_run).to upgrade_package('identity cookbook package python-memcache')
    end

    it 'upgrades keystone packages' do
      expect(chef_run).to upgrade_package('identity cookbook package keystone')
    end

    it 'has flush tokens cronjob running every day at 3:30am' do
      expect(chef_run).to create_cron('keystone-manage-token-flush').with_command(/keystone-manage token_flush/)
      expect(chef_run).to create_cron('keystone-manage-token-flush').with_minute('0')
      expect(chef_run).to create_cron('keystone-manage-token-flush').with_hour('*')
      expect(chef_run).to create_cron('keystone-manage-token-flush').with_day('*')
      expect(chef_run).to create_cron('keystone-manage-token-flush').with_weekday('*')
    end

    it 'deletes flush tokens cronjob when tokens backend is not sql' do
      node.set['openstack']['identity']['token']['backend'] = 'notsql'
      expect(chef_run).to delete_cron('keystone-manage-token-flush')
    end

    describe '/etc/keystone' do
      let(:dir) { chef_run.directory('/etc/keystone') }

      it 'creates directory /etc/keystone' do
        expect(chef_run).to create_directory(dir.name).with(
          user: 'keystone',
          group: 'keystone',
          mode: 00700
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
          mode: 00700
        )
      end
    end

    describe 'ssl directories' do
      let(:ssl_dir) { '/etc/keystone/ssl' }
      let(:certs_dir) { "#{ssl_dir}/certs" }
      let(:private_dir) { "#{ssl_dir}/private" }

      describe 'without pki' do
        before { node.set['openstack']['auth']['strategy'] = 'uuid' }

        it 'does not create /etc/keystone/ssl' do
          expect(chef_run).not_to create_directory(ssl_dir)
        end

        it 'does not create /etc/keystone/ssl/certs' do
          expect(chef_run).not_to create_directory(certs_dir)
        end

        it 'does not create /etc/keystone/ssl/private' do
          expect(chef_run).not_to create_directory(private_dir)
        end
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
            mode: 00640
          )
        end
      end

      it 'has no list_limits by default' do
        expect(chef_run).not_to render_config_file(path).with_section_content('DEFAULT', /^list_limit = /)
      end

      it 'has rpc_backend set for rabbit' do
        expect(chef_run).to render_config_file(path).with_section_content('DEFAULT', /^rpc_backend = rabbit$/)
      end

      describe '[DEFAULT] section' do
        it 'has admin token' do
          r = line_regexp('admin_token = bootstrap-token')
          expect(chef_run).to render_config_file(path).with_section_content('DEFAULT', r)
        end

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
          adm = line_regexp('admin_endpoint = http://127.0.0.1:35357/')

          expect(chef_run).to render_config_file(path).with_section_content('DEFAULT', pub)
          expect(chef_run).to render_config_file(path).with_section_content('DEFAULT', adm)
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
          r = line_regexp('driver = keystone.assignment.backends.sql.Assignment')
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
          line_regexp('driver = keystone.catalog.backends.sql.Catalog')
        end

        it 'configures driver' do
          expect(chef_run).to render_config_file(path).with_content(sql)
          expect(chef_run).not_to render_config_file(path).with_section_content('catalog', templated)
        end
      end

      describe '[policy] section' do
        it 'configures driver' do
          r = line_regexp('driver = keystone.policy.backends.sql.Policy')
          expect(chef_run).to render_config_file(path).with_section_content('policy', r)
        end
      end

      describe '[oslo_messaging_rabbit] section' do
        it 'has defaults for oslo_messaging_rabbit section' do
          [
            /^rabbit_userid = guest$/,
            /^rabbit_password = guest$/
          ].each do |line|
            expect(chef_run).to render_config_file(path).with_section_content('oslo_messaging_rabbit', line)
          end
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
          user: 'keystone',
          group: 'keystone'
        )
      end

      it 'does not run migrations' do
        node.set['openstack']['db']['identity']['migrate'] = false
        expect(chef_run).not_to run_execute(cmd).with(
          user: 'keystone',
          group: 'keystone'
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
          mode: 0644
        )
      end

      it 'has default api pipeline value' do
        expect(chef_run).to render_file(path).with_content(/^pipeline = sizelimit url_normalize request_id build_auth_context token_auth admin_token_auth json_body ec2_extension user_crud_extension public_service$/)
        expect(chef_run).to render_file(path).with_content(/^pipeline = sizelimit url_normalize request_id build_auth_context token_auth admin_token_auth json_body ec2_extension s3_extension crud_extension admin_service$/)
        expect(chef_run).to render_file(path).with_content(/^pipeline = sizelimit url_normalize request_id build_auth_context token_auth admin_token_auth json_body ec2_extension_v3 s3_extension simple_cert_extension revoke_extension federation_extension oauth1_extension endpoint_filter_extension service_v3$/)
      end
      it 'template api pipeline set correct' do
        node.set['openstack']['identity']['pipeline']['public_api'] = 'public_service'
        node.set['openstack']['identity']['pipeline']['admin_api'] = 'admin_service'
        node.set['openstack']['identity']['pipeline']['api_v3'] = 'service_v3'
        expect(chef_run).to render_file(path).with_content(/^pipeline = public_service$/)
        expect(chef_run).to render_file(path).with_content(/^pipeline = admin_service$/)
        expect(chef_run).to render_file(path).with_content(/^pipeline = service_v3$/)
      end
      it 'template misc_paste array correctly' do
        node.set['openstack']['identity']['misc_paste'] = ['MISC1 = OPTION1', 'MISC2 = OPTION2']
        expect(chef_run).to render_file(path).with_content(
          /^MISC1 = OPTION1$/)
        expect(chef_run).to render_file(path).with_content(
          /^MISC2 = OPTION2$/)
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
          mode: 00644
        )
      end
    end

    describe 'apache setup' do
      it 'stop and disable keystone service' do
        expect(chef_run).to stop_service('keystone')
        expect(chef_run).to disable_service('keystone')
      end

      it 'set apache addresses and ports' do
        expect(chef_run.node['apache']['listen']).to eq(
          %w(127.0.0.1:5000 127.0.0.1:35357)
        )
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

      it 'creates directory /var/www/html/keystone' do
        expect(chef_run).to create_directory('/var/www/html/keystone').with(
          user: 'root',
          group: 'root',
          mode: 00755
        )
      end

      it 'creates wsgi files' do
        %w(main admin).each do |file|
          expect(chef_run).to create_file("/var/www/html/keystone/#{file}").with(
            user: 'root',
            group: 'root',
            mode: 00755
          )
        end
      end

      describe 'apache wsgi' do
        ['/etc/apache2/sites-available/keystone-main.conf',
         '/etc/apache2/sites-available/keystone-admin.conf'].each do |file|
          it "creates #{file}" do
            expect(chef_run).to create_template(file).with(
              user: 'root',
              group: 'root',
              mode: '0644'
            )
          end

          it "configures #{file} common lines" do
            node.set['openstack']['identity']['custom_template_banner'] = 'custom_template_banner_value'
            [/^custom_template_banner_value$/,
             /user=keystone/,
             /group=keystone/,
             %r{^    ErrorLog /var/log/apache2/keystone.log$},
             %r{^    CustomLog /var/log/apache2/keystone_access.log combined$}].each do |line|
              expect(chef_run).to render_file(file).with_content(line)
            end
          end

          it "does not configure #{file} triggered common lines" do
            [/^    LogLevel/,
             /^    SSL/].each do |line|
              expect(chef_run).not_to render_file(file).with_content(line)
            end
          end
          context 'Enable SSL' do
            before do
              node.set['openstack']['identity']['ssl']['enabled'] = true
            end
            it "configures #{file} common ssl lines" do
              [/^    SSLEngine On$/,
               %r{^    SSLCertificateFile /etc/keystone/ssl/certs/sslcert.pem$},
               %r{^    SSLCertificateKeyFile /etc/keystone/ssl/private/sslkey.pem$},
               %r{^    SSLCACertificatePath /etc/keystone/ssl/certs/$},
               /^    SSLProtocol All -SSLv2 -SSLv3$/].each do |line|
                expect(chef_run).to render_file(file).with_content(line)
              end
            end
            it "does not configure #{file} common ssl lines" do
              [/^    SSLCertificateChainFile/,
               /^    SSLCipherSuite/,
               /^    SSLVerifyClient require/].each do |line|
                expect(chef_run).not_to render_file(file).with_content(line)
              end
            end
            it "configures #{file} chainfile when set" do
              node.set['openstack']['identity']['ssl']['chainfile'] = '/etc/keystone/ssl/certs/chainfile.pem'
              expect(chef_run).to render_file(file)
                .with_content(%r{^    SSLCertificateChainFile /etc/keystone/ssl/certs/chainfile.pem$})
            end
            it "configures #{file} ciphers when set" do
              node.set['openstack']['identity']['ssl']['ciphers'] = 'ciphers_value'
              expect(chef_run).to render_file(file)
                .with_content(/^    SSLCipherSuite ciphers_value$/)
            end
            it "configures #{file} cert_required set" do
              node.set['openstack']['identity']['ssl']['cert_required'] = true
              expect(chef_run).to render_file(file)
                .with_content(/^    SSLVerifyClient require$/)
            end
          end
        end

        describe 'keystone-main.conf' do
          it 'configures required lines' do
            [/^<VirtualHost 127.0.0.1:5000>$/,
             /^    WSGIDaemonProcess keystone-main/,
             /^    WSGIProcessGroup keystone-main$/,
             %r{^    WSGIScriptAlias / /var/www/html/keystone/main$}].each do |line|
              expect(chef_run).to render_file('/etc/apache2/sites-available/keystone-main.conf').with_content(line)
            end
          end
        end

        describe 'keystone-admin.conf' do
          it 'configures required lines' do
            [/^<VirtualHost 127.0.0.1:35357>$/,
             /^    WSGIDaemonProcess keystone-admin/,
             /^    WSGIProcessGroup keystone-admin$/,
             %r{^    WSGIScriptAlias / /var/www/html/keystone/admin$}].each do |line|
              expect(chef_run).to render_file('/etc/apache2/sites-available/keystone-admin.conf').with_content(line)
            end
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
