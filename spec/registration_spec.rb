# encoding: UTF-8
#

require_relative 'spec_helper'

describe 'openstack-identity::registration' do
  describe 'ubuntu' do
    let(:node)     { runner.node }
    let(:runner)   { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:chef_run) { runner.converge(described_recipe) }
    let(:node_add_user) do
      node.set_unless['openstack']['identity']['users'] = {
        'user1' => {
          'default_tenant' => 'default_tenant1',
          'password' => 'secret1',
          'roles' => {
            'role1' => ['role_tenant1'],
            'role2' => ['default_tenant1']
          }
        }
      }
    end

    include_context 'identity_stubs'

    describe 'tenant registration' do
      context 'default tenants' do
        ['admin'].each do |tenant_name|
          it "registers the #{tenant_name} tenant" do
            expect(chef_run).to create_tenant_openstack_identity_register(
              "Register '#{tenant_name}' Tenant"
            ).with(
              auth_uri: 'http://127.0.0.1:35357/v2.0',
              bootstrap_token: 'bootstrap-token',
              tenant_name: tenant_name,
              tenant_description: "#{tenant_name} Tenant"
            )
          end
        end
      end

      context 'configured tenants from users attribute' do
        before { node_add_user }
        ['default_tenant1', 'role_tenant1'].each do |tenant_name|
          it "registers the #{tenant_name} tenant" do
            expect(chef_run).to create_tenant_openstack_identity_register(
              "Register '#{tenant_name}' Tenant"
            ).with(
              auth_uri: 'http://127.0.0.1:35357/v2.0',
              bootstrap_token: 'bootstrap-token',
              tenant_name: tenant_name,
              tenant_description: "#{tenant_name} Tenant"
            )
          end
        end
      end
    end

    describe 'role registration' do
      context 'default roles' do
        %w{admin KeystoneAdmin KeystoneServiceAdmin}.each do |role_name|
          it "registers the #{role_name} role" do
            expect(chef_run).to create_role_openstack_identity_register(
              "Register '#{role_name}' Role"
            ).with(
              auth_uri: 'http://127.0.0.1:35357/v2.0',
              bootstrap_token: 'bootstrap-token',
              role_name: role_name
            )
          end
        end
      end

      context 'configured roles derived from users attribute' do
        before { node_add_user }

        ['role1', 'role2'].each do |role_name|
          it "registers the #{role_name} role" do
            expect(chef_run).to create_role_openstack_identity_register(
              "Register '#{role_name}' Role"
            ).with(
              auth_uri: 'http://127.0.0.1:35357/v2.0',
              bootstrap_token: 'bootstrap-token',
              role_name: role_name
            )
          end
        end
      end
    end

    describe 'user registration' do
      context 'default users' do
        user_admin = [
          'admin', 'admin',
          ['admin', 'KeystoneAdmin', 'KeystoneServiceAdmin']
        ]

        [user_admin].each do |user, tenant, roles|
          context "#{user} user" do
            it "registers the #{user} user" do
              expect(chef_run).to create_user_openstack_identity_register(
                "Register '#{user}' User"
              ).with(
                auth_uri: 'http://127.0.0.1:35357/v2.0',
                bootstrap_token: 'bootstrap-token',
                user_name: user,
                user_pass: '',
                tenant_name: tenant
              )
            end

            roles.each do |role|
              it "grants '#{role}' role to '#{user}' user in 'admin' tenant" do
                expect(chef_run).to grant_role_openstack_identity_register(
                  "Grant '#{role}' Role to '#{user}' User in 'admin' Tenant"
                ).with(
                  auth_uri: 'http://127.0.0.1:35357/v2.0',
                  bootstrap_token: 'bootstrap-token',
                  user_name: user,
                  role_name: role,
                  tenant_name: 'admin',
                  action: [:grant_role]
                )
              end
            end

          end
        end
      end

      context 'configured user' do
        before { node_add_user }

        it 'registers the user1 user' do
          expect(chef_run).to create_user_openstack_identity_register(
            "Register 'user1' User"
          ).with(
            auth_uri: 'http://127.0.0.1:35357/v2.0',
            bootstrap_token: 'bootstrap-token',
            user_name: 'user1',
            user_pass: 'secret1',
            tenant_name: 'default_tenant1'
          )
        end

        it "grants 'role1' role to 'user1' user in 'role_tenant1' tenant" do
          expect(chef_run).to grant_role_openstack_identity_register(
            "Grant 'role1' Role to 'user1' User in 'role_tenant1' Tenant"
          ).with(
            auth_uri: 'http://127.0.0.1:35357/v2.0',
            bootstrap_token: 'bootstrap-token',
            user_name: 'user1',
            role_name: 'role1',
            tenant_name: 'role_tenant1'
          )
        end
      end
    end

    describe 'service registration' do
      context 'with templated catalog backend' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'templated'
        end

        it 'does not register identity service' do
          expect(chef_run).to_not create_service_openstack_identity_register(
            'Register Identity Service'
          )
        end
      end

      context 'with sql catalog backend' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'sql'
        end
        it 'registers identity service' do
          expect(chef_run).to create_service_openstack_identity_register(
            'Register Identity Service'
          ).with(
            service_name: 'keystone',
            service_type: 'identity',
            service_description: 'Keystone Identity Service'
          )
        end
      end
    end

    describe 'endpoint registration' do
      context 'with templated catalog backend' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'templated'
        end

        it 'does not register identity endpoint' do
          expect(chef_run).to_not create_endpoint_openstack_identity_register(
            'Register Identity Endpoint'
          )
        end
      end

      context 'with sql catalog backend' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'sql'
        end

        it 'registers identity endpoint' do
          expect(chef_run).to create_endpoint_openstack_identity_register(
            'Register Identity Endpoint'
          ).with(
            auth_uri: 'http://127.0.0.1:35357/v2.0',
            bootstrap_token: 'bootstrap-token',
            service_type: 'identity',
            endpoint_region: 'RegionOne',
            endpoint_adminurl: 'http://127.0.0.1:35357/v2.0',
            endpoint_internalurl: 'http://127.0.0.1:35357/v2.0',
            endpoint_publicurl: 'http://127.0.0.1:5000/v2.0'
          )
        end

        it 'overrides identity endpoint region' do
          node.set['openstack']['identity']['region'] = 'identityRegion'
          expect(chef_run).to create_endpoint_openstack_identity_register(
            'Register Identity Endpoint'
          ).with(endpoint_region: 'identityRegion')
        end
      end
    end
  end
end
