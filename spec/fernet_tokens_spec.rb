# encoding: UTF-8
#

require_relative 'spec_helper'

describe 'openstack-identity::_fernet_tokens' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    before do
      allow_any_instance_of(Chef::Recipe).to receive(:secret)
        .with('keystone', 'fernet_key0')
        .and_return('thisisfernetkey0')
      allow_any_instance_of(Chef::Recipe).to receive(:secret)
        .with('keystone', 'fernet_key1')
        .and_return('thisisfernetkey1')
    end

    it do
      expect(chef_run).to create_directory('/etc/keystone/fernet-tokens')
        .with(owner: 'keystone', user: 'keystone', mode: 00700)
    end

    [0, 1].each do |key_index|
      it do
        expect(chef_run).to create_file("/etc/keystone/fernet-tokens/#{key_index}")
          .with(
            content: "thisisfernetkey#{key_index}",
            owner: 'keystone',
            group: 'keystone',
            mode: 00600
          )
      end
    end
  end
end
