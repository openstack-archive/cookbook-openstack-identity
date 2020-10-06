
require_relative 'spec_helper'

describe 'openstack-identity::_credential_tokens' do
  describe 'ubuntu' do
    include_context 'identity_stubs'

    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) { runner.converge(described_recipe) }

    it do
      expect(chef_run).to create_directory('/etc/keystone/credential-tokens')
        .with(owner: 'keystone', user: 'keystone', mode: '700')
    end

    [0, 1].each do |key_index|
      it do
        expect(chef_run).to create_file("/etc/keystone/credential-tokens/#{key_index}")
          .with(
            content: "thisiscredentialkey#{key_index}",
            owner: 'keystone',
            group: 'keystone',
            mode: '400'
          )
      end
    end
  end
end
