# encoding: UTF-8
#

require_relative 'spec_helper'

describe 'openstack-identity::_pki_tokens' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include Helpers
    include_context 'identity_stubs'

    describe 'ssl directories' do
      let(:ssl_dir) { '/etc/keystone/ssl' }
      let(:certs_dir) { "#{ssl_dir}/certs" }
      let(:private_dir) { "#{ssl_dir}/private" }

      describe '/etc/keystone/ssl' do
        let(:dir_resource) { chef_run.directory(ssl_dir) }

        it 'creates /etc/keystone/ssl' do
          expect(chef_run).to create_directory(ssl_dir).with(
            owner: 'keystone',
            group: 'keystone',
            mode: 0700
          )
        end
      end

      describe '/etc/keystone/ssl/certs' do
        let(:dir_resource) { chef_run.directory(certs_dir) }

        it 'creates /etc/keystone/ssl/certs' do
          expect(chef_run).to create_directory(certs_dir).with(
            user: 'keystone',
            group: 'keystone',
            mode: 0755
          )
        end
      end

      describe '/etc/keystone/ssl/private' do
        let(:dir_resource) { chef_run.directory(private_dir) }

        it 'creates /etc/keystone/ssl/private' do
          expect(chef_run).to create_directory(private_dir)
            .with(
              user: 'keystone',
              group: 'keystone',
              mode: 0750
            )
        end
      end
    end

    describe 'pki setup' do
      let(:cmd) { 'keystone-manage pki_setup' }

      describe 'without {certfile,keyfile,ca_certs}_url attributes set' do
        it 'executes' do
          expect(FileTest).to receive(:exists?)
            .with('/etc/keystone/ssl/private/signing_key.pem')
            .and_return(false)

          expect(chef_run).to run_execute(cmd)
            .with(
              user: 'keystone',
              group: 'keystone'
            )
        end
      end

      it 'does not execute when dir exists' do
        expect(FileTest).to receive(:exists?)
          .with('/etc/keystone/ssl/private/signing_key.pem')
          .and_return(true)

        expect(chef_run).not_to run_execute(cmd)
          .with(
            user: 'keystone',
            group: 'keystone'
          )
      end
    end
  end
end
