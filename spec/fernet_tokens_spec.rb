# encoding: UTF-8
#

require_relative 'spec_helper'

describe 'openstack-identity::_fernet_tokens' do
  describe 'ubuntu' do
    include_context 'identity_stubs'

    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    it do
      expect(chef_run).to create_directory('/etc/keystone/fernet-tokens')
        .with(owner: 'keystone', user: 'keystone', mode: 0o0700)
    end

    [0, 1].each do |key_index|
      it do
        expect(chef_run).to create_file("/etc/keystone/fernet-tokens/#{key_index}")
          .with(
            content: "thisisfernetkey#{key_index}",
            owner: 'keystone',
            group: 'keystone',
            mode: 0o0400
          )
      end
    end
  end
end
