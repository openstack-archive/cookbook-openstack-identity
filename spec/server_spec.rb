# encoding: UTF-8
#

require_relative 'spec_helper'

describe 'openstack-identity::server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set_unless['openstack']['endpoints']['identity-api'] = {
        'host' => '127.0.1.1',
        'port' => '5000',
        'scheme' => 'https'
      }
      node.set_unless['openstack']['endpoints']['identity-admin'] = {
        'host' => '127.0.1.1',
        'port' => '35357',
        'scheme' => 'https'
      }

      runner.converge(described_recipe)
    end

    include_context 'identity_stubs'

    it 'runs logging recipe if node attributes say to' do
      node.set['openstack']['identity']['syslog']['use'] = true
      expect(chef_run).to include_recipe('openstack-common::logging')
    end

    it 'does not run logging recipe' do
      expect(chef_run).not_to include_recipe('openstack-common::logging')
    end

    it 'converges when configured to use sqlite db backend' do
      node.set['openstack']['db']['identity']['service_type'] = 'sqlite'
      expect { chef_run }.to_not raise_error
    end

    it 'installs mysql python packages' do
      expect(chef_run).to install_package('python-mysqldb')
    end

    it 'installs postgresql python packages if explicitly told' do
      node.set['openstack']['db']['identity']['service_type'] = 'postgresql'
      expect(chef_run).to install_package('python-psycopg2')
    end

    it 'installs memcache python packages' do
      expect(chef_run).to install_package('python-memcache')
    end

    it 'installs keystone packages' do
      expect(chef_run).to upgrade_package('keystone')
    end

    it 'starts keystone on boot' do
      expect(chef_run).to enable_service('keystone')
    end

    it 'sleep on keystone service enable' do
      expect(chef_run.service('keystone')).to notify(
        'execute[Keystone: sleep]').to(:run)
    end

    describe '/etc/keystone' do
      let(:dir) { chef_run.directory('/etc/keystone') }

      it 'has proper owner' do
        expect(dir.owner).to eq('keystone')
        expect(dir.group).to eq('keystone')
      end

      it 'has proper modes' do
        expect(sprintf('%o', dir.mode)).to eq('700')
      end
    end

    describe '/etc/keystone/ssl' do
      let(:ssl_dir) { '/etc/keystone/ssl' }

      describe 'without pki' do
        it 'does not create' do
          expect(chef_run).not_to create_directory(ssl_dir)
        end
      end

      describe 'with pki' do
        before { node.set['openstack']['auth']['strategy'] = 'pki' }
        let(:dir_resource) { chef_run.directory(ssl_dir) }

        it 'creates' do
          expect(chef_run).to create_directory(ssl_dir)
        end

        it 'has proper owner' do
          expect(dir_resource.owner).to eq('keystone')
          expect(dir_resource.group).to eq('keystone')
        end

        it 'has proper modes' do
          expect(sprintf('%o', dir_resource.mode)).to eq('700')
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

    describe 'pki setup' do
      let(:cmd) { 'keystone-manage pki_setup' }

      describe 'without pki' do
        it 'does not execute' do
          expect(chef_run).to_not run_execute(cmd).with(
            user: 'keystone',
            group: 'keystone'
          )
        end
      end

      describe 'with pki' do
        before { node.set['openstack']['auth']['strategy'] = 'pki' }

        it 'executes' do
          ::FileTest.should_receive(:exists?)
            .with('/etc/keystone/ssl/private/signing_key.pem')
            .and_return(false)

          expect(chef_run).to run_execute(cmd).with(
            user: 'keystone',
            group: 'keystone'
          )
        end

        it 'does not execute when dir exists' do
          ::FileTest.should_receive(:exists?)
            .with('/etc/keystone/ssl/private/signing_key.pem')
            .and_return(true)

          expect(chef_run).not_to run_execute(cmd).with(
            user: 'keystone',
            group: 'keystone'
          )
        end
      end
    end

    describe 'keystone.conf' do
      let(:template) { chef_run.template '/etc/keystone/keystone.conf' }

      it 'has proper owner' do
        expect(template.owner).to eq('keystone')
        expect(template.group).to eq('keystone')
      end

      it 'has proper modes' do
        expect(sprintf('%o', template.mode)).to eq('644')
      end

      it 'has bind host' do
        match = 'bind_host = 127.0.1.1'
        expect(chef_run).to render_file(template.name).with_content(match)
      end

      it 'has proper public and admin endpoint' do
        pub_endpoint = 'public_endpoint = https://127.0.1.1:5000/'
        adm_endpoint = 'admin_endpoint = https://127.0.1.1:35357/'
        expect(chef_run).to render_file(template.name).with_content(
          pub_endpoint)
        expect(chef_run).to render_file(template.name).with_content(
          adm_endpoint)
      end

      it 'has policy driver' do
        match = 'driver = keystone.policy.backends.sql.Policy'
        expect(chef_run).to render_file(template.name).with_content(match)
      end

      it 'notifies keystone restart' do
        expect(template).to notify('service[keystone]').to(:restart)
      end

      describe 'optional LDAP attributes' do
        optional_attrs = %w{group_tree_dn group_filter user_filter
                            user_tree_dn user_enabled_emulation_dn
                            group_attribute_ignore role_attribute_ignore
                            role_tree_dn role_filter tenant_tree_dn
                            tenant_enabled_emulation_dn tenant_filter
                            tenant_attribute_ignore}

        optional_attrs.each do |setting|
          it "does not have the optional #{setting} LDAP attribute" do
            expect(chef_run).not_to render_file(template.name).with_content(
              /^#{Regexp.quote(setting)} =/)
          end

          it "has the optional #{setting} LDAP attribute commented out" do
            expect(chef_run).to render_file(template.name).with_content(
              /^# #{Regexp.quote(setting)} =$/)
          end
        end
      end

      %w{url user suffix use_dumb_member
         allow_subtree_delete dumb_member page_size
         alias_dereferencing query_scope user_objectclass
         user_id_attribute user_name_attribute
         user_mail_attribute user_pass_attribute
         user_enabled_attribute user_domain_id_attribute
         user_attribute_ignore user_enabled_mask
         user_enabled_default user_allow_create
         user_allow_update user_allow_delete
         user_enabled_emulation tenant_objectclass
         tenant_id_attribute tenant_member_attribute
         tenant_name_attribute tenant_desc_attribute
         tenant_enabled_attribute tenant_domain_id_attribute
         tenant_allow_create tenant_allow_update
         tenant_allow_delete tenant_enabled_emulation
         role_objectclass role_id_attribute role_name_attribute
         role_member_attribute role_allow_create
         role_allow_update role_allow_delete group_objectclass
         group_id_attribute group_name_attribute
         group_member_attribute group_desc_attribute
         group_domain_id_attribute group_allow_create
         group_allow_update group_allow_delete
      }.each do |setting|
        it "has a #{setting} LDAP attribute" do
          expect(chef_run).to render_file(template.name).with_content(
          /^#{Regexp.quote(setting)} = \w+/)
        end
      end
    end

    describe 'default_catalog.templates' do
      let(:file) { '/etc/keystone/default_catalog.templates' }

      describe 'without templated' do
        it 'does not create' do
          expect(chef_run).not_to render_file(file)
        end
      end

      describe 'with templated' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'templated'
        end
        let(:template) { chef_run.template(file) }

        it 'creates' do
          expect(chef_run).to render_file(file)
        end

        it 'has proper owner' do
          expect(template.owner).to eq('keystone')
          expect(template.group).to eq('keystone')
        end

        it 'has proper modes' do
          expect(sprintf('%o', template.mode)).to eq('644')
        end

        it 'template contents' do
          pending 'TODO: implement'
        end

        it 'notifies keystone restart' do
          expect(template).to notify('service[keystone]').to(:restart)
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
  end
end
