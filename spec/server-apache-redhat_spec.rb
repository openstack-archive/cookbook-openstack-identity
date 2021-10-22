
require_relative 'spec_helper'

describe 'openstack-identity::server-apache' do
  ALL_RHEL.each do |p|
    context "redhat #{p[:version]}" do
      let(:runner) { ChefSpec::SoloRunner.new(p) }
      let(:node) { runner.node }
      cached(:chef_run) do
        runner.converge(described_recipe)
      end

      include_context 'identity_stubs'

      it 'upgrades keystone packages' do
        expect(chef_run).to upgrade_package('identity cookbook package openstack-keystone')
        expect(chef_run).to upgrade_package('identity cookbook package openstack-selinux')
      end

      case p
      when REDHAT_7
        it 'upgrades python packages' do
          expect(chef_run).to upgrade_package('identity cookbook package python-memcached')
          expect(chef_run).to upgrade_package('identity cookbook package python2-urllib3')
        end

      when REDHAT_8
        it 'upgrades python packages' do
          expect(chef_run).to upgrade_package('identity cookbook package python3-memcached')
          expect(chef_run).to upgrade_package('identity cookbook package python3-urllib3')
        end
      end
    end
  end
end
