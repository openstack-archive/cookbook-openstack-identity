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
      openstack_auth_url: 'http://127.0.0.1:5000/v3/auth/tokens',
      openstack_username: 'admin',
      openstack_api_key: 'admin',
      openstack_project_name: 'admin',
      openstack_domain_id: 'default',
    }
    service_user = 'admin'
    role_name = 'admin'
    admin_domain_name = 'default'
    domain_name = 'identity'

    describe 'keystone bootstrap' do
      context 'default values' do
        it do
          expect(chef_run).to run_ruby_block('wait for identity endpoint')
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
            domain_name: admin_domain_name,
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
    end
  end
end
