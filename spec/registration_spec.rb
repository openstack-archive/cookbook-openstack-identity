
require_relative 'spec_helper'

describe 'openstack-identity::registration' do
  describe 'ubuntu' do
    let(:node)     { runner.node }
    let(:runner)   { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    cached(:chef_run) { runner.converge(described_recipe) }

    include_context 'identity_stubs'

    connection_params = {
      openstack_auth_url: 'http://127.0.0.1:5000/v3',
      openstack_username: 'admin',
      openstack_api_key: 'admin',
      openstack_project_name: 'admin',
      openstack_domain_id: 'default',
      # openstack_endpoint_type: 'internalURL',
    }

    describe 'keystone bootstrap' do
      context 'default values' do
        it do
          expect(chef_run).to run_ruby_block('wait for identity endpoint')
        end

        it 'create service role' do
          expect(chef_run).to create_openstack_role(
            'service'
          ).with(
            connection_params: connection_params
          )
        end
      end
    end
  end
end
