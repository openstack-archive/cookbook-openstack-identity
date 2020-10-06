
require_relative 'spec_helper'

describe 'openstack-identity::_fernet_tokens' do
  describe 'ubuntu' do
    include_context 'identity_stubs'

    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) { runner.converge(described_recipe) }

    it do
      expect(chef_run).to create_directory('/etc/keystone/fernet-tokens')
        .with(owner: 'keystone', user: 'keystone', mode: '700')
    end

    [0, 1].each do |key_index|
      it do
        expect(chef_run).to create_file("/etc/keystone/fernet-tokens/#{key_index}")
          .with(
            content: "thisisfernetkey#{key_index}",
            owner: 'keystone',
            group: 'keystone',
            mode: '400'
          )
      end
    end
    it do
      expect(chef_run).to run_execute('keystone-manage fernet_setup').with(
        command: 'keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone'
      )
    end
  end
end
