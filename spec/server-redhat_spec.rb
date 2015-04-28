# encoding: UTF-8
#

require_relative 'spec_helper'

describe 'openstack-identity::server' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) { runner.converge(described_recipe) }

    include_context 'identity_stubs'

    it 'converges when configured to use sqlite db backend' do
      node.set['openstack']['db']['identity']['service_type'] = 'sqlite'
      expect { chef_run }.to_not raise_error
    end

    it 'upgrades mysql python packages' do
      expect(chef_run).to upgrade_package('identity cookbook package MySQL-python')
    end

    it 'upgrades db2 python packages if explicitly told' do
      node.set['openstack']['db']['identity']['service_type'] = 'db2'

      ['python-ibm-db', 'python-ibm-db-sa'].each do |pkg|
        expect(chef_run).to upgrade_package("identity cookbook package #{pkg}")
      end
    end

    it 'upgrades postgresql python packages if explicitly told' do
      node.set['openstack']['db']['identity']['service_type'] = 'postgresql'
      expect(chef_run).to upgrade_package('identity cookbook package python-psycopg2')
    end

    it 'upgrades memcache python packages' do
      expect(chef_run).to upgrade_package('identity cookbook package python-memcached')
    end

    it 'upgrades keystone packages' do
      expect(chef_run).to upgrade_package('identity cookbook package openstack-keystone')
    end

    it 'starts keystone on boot' do
      expect(chef_run).to enable_service('openstack-keystone')
    end

    describe 'keystone-paste.ini' do
      before { node.set['openstack']['identity']['pastefile_url'] = 'file:///usr/share/keystone/keystone-dist-paste.ini' }
      paste_file = '/etc/keystone/keystone-paste.ini'
      let(:file_resource) { chef_run.remote_file(paste_file) }

      it 'copies local keystone-dist-paste.ini when keystone-paste pastefile_url is specified' do
        expect(chef_run).to create_remote_file_if_missing(paste_file).with(
          source: 'file:///usr/share/keystone/keystone-dist-paste.ini',
          user: 'keystone',
          group: 'keystone',
          mode: 00644)
      end

      it 'restarts keystone when keystone-paste.ini is created' do
        expect(file_resource).to notify('service[keystone]').to(:restart)
      end
    end
  end
end
