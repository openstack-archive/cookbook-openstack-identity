# encoding: UTF-8
#

require_relative 'spec_helper'

describe 'openstack-identity::server-apache' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'identity_stubs'

    it 'upgrades memcache python packages' do
      expect(chef_run).to upgrade_package('identity cookbook package python-memcached')
    end

    it 'upgrades keystone packages' do
      expect(chef_run).to upgrade_package('identity cookbook package openstack-keystone')
      expect(chef_run).to upgrade_package('identity cookbook package openstack-selinux')
      expect(chef_run).to upgrade_package('identity cookbook package mod_wsgi')
    end
  end
end
