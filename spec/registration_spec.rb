# encoding: UTF-8
#

require_relative 'spec_helper'

describe 'openstack-identity::registration' do
  describe 'ubuntu' do
    let(:node)     { runner.node }
    let(:runner)   { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:chef_run) { runner.converge(described_recipe) }

    include_context 'identity_stubs'

    connection_params = {
      openstack_auth_url: 'http://127.0.0.1:35357/v3/auth/tokens',
      openstack_username: 'admin',
      openstack_api_key: 'admin',
      openstack_project_name: 'admin',
      openstack_domain_name: 'default'
    }
    service_name = 'keystone'
    service_user = 'admin'
    region = 'RegionOne'
    project_name = 'admin'
    role_name = 'admin'
    password = 'admin'
    domain_name = 'default'
    admin_url = 'http://127.0.0.1:35357/v3'
    public_url = 'http://127.0.0.1:5000/v3'
    internal_url = 'http://127.0.0.1:5000/v3'

    describe 'keystone bootstrap' do
      context 'default values' do
        it 'bootstrap with keystone-manage' do
          expect(chef_run).to run_execute('bootstrap_keystone'
                                         ).with(command: "keystone-manage bootstrap \\
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
        it "registers #{domain_name} domain" do
          expect(chef_run).to create_openstack_domain(
            domain_name
          ).with(
            connection_params: connection_params
          )
        end

        it "grants #{service_user} user to #{domain_name} domain" do
          expect(chef_run).to grant_domain_openstack_user(
            service_user
          ).with(
            domain_name: domain_name,
            role_name: role_name,
            connection_params: connection_params
          )
        end

        it 'create service role' do
          expect(chef_run).to create_openstack_role(
            'service'
          ).with(
            connection_params: connection_params
          )
        end

        it 'create service role' do
          expect(chef_run).to create_openstack_role(
            '_member_'
          ).with(
            connection_params: connection_params
          )
        end
      end
      context 'all different values' do
        connection_params_other = {
          openstack_auth_url: 'https://admin.identity:1234/v3/auth/tokens',
          openstack_username: 'identity_admin',
          openstack_api_key: 'identity_admin_pass',
          openstack_project_name: 'admin_project',
          openstack_domain_name: 'identity_domain'
        }
        before do
          node.set['openstack']['endpoints']['admin']['identity']['uri'] =
            'https://admin.identity:1234/v3'
          node.set['openstack']['endpoints']['internal']['identity']['uri'] =
            'https://internal.identity:5678/v3'
          node.set['openstack']['endpoints']['public']['identity']['uri'] =
            'https://public.identity:9753/v3'
          node.set['openstack']['region'] = 'otherRegion'
          node.set['openstack']['identity']['admin_project'] = 'admin_project'
          node.set['openstack']['identity']['admin_user'] = 'identity_admin'
          node.set['openstack']['identity']['admin_role'] = 'identity_role'
          node.set['openstack']['identity']['admin_domain_name'] =
            'identity_domain'
        end

        it 'bootstrap with keystone-manage' do
          expect(chef_run).to run_execute('bootstrap_keystone'
                                         ).with(command: "keystone-manage bootstrap \\
          --bootstrap-password identity_admin_pass \\
          --bootstrap-username identity_admin \\
          --bootstrap-project-name admin_project \\
          --bootstrap-role-name identity_role \\
          --bootstrap-service-name #{service_name} \\
          --bootstrap-region-id otherRegion \\
          --bootstrap-admin-url https://admin.identity:1234/v3 \\
          --bootstrap-public-url https://public.identity:9753/v3 \\
          --bootstrap-internal-url https://internal.identity:5678/v3")
        end

        it 'registers identity_domain domain' do
          expect(chef_run).to create_openstack_domain(
            'identity_domain'
          ).with(
            connection_params: connection_params_other
          )
        end

        it 'grants identity_admin user to identity_domain domain' do
          expect(chef_run).to grant_domain_openstack_user(
            'identity_admin'
          ).with(
            domain_name: 'identity_domain',
            role_name: 'identity_role',
            connection_params: connection_params_other
          )
        end

        it 'create service role' do
          expect(chef_run).to create_openstack_role(
            'service'
          ).with(
            connection_params: connection_params_other
          )
        end
        it 'create service role' do
          expect(chef_run).to create_openstack_role(
            '_member_'
          ).with(
            connection_params: connection_params_other
          )
        end
      end
    end
  end
end
