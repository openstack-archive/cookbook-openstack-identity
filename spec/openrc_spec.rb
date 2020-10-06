require_relative 'spec_helper'

describe 'openstack-identity::openrc' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'identity_stubs'

    describe '/root/openrc' do
      let(:file) { chef_run.template('/root/openrc') }

      it 'creates the /root/openrc file' do
        expect(chef_run).to create_directory('/root').with(
          owner: 'root',
          group: 'root',
          mode: '0700',
          recursive: true
        )
        expect(chef_run).to create_template(file.name).with(
          sensitive: true,
          user: 'root',
          group: 'root',
          mode: '0600'
        )
      end

      it 'contains auth environment variables' do
        [
          /^export OS_USERNAME=admin$/,
          /^export OS_USER_DOMAIN_NAME=default$/,
          /^export OS_PASSWORD=admin$/,
          /^export OS_PROJECT_NAME=admin$/,
          /^export OS_PROJECT_DOMAIN_NAME=default$/,
          /^export OS_IDENTITY_API_VERSION=3$/,
          %r{^export OS_AUTH_URL=http://127.0.0.1:5000/v3$},
          /^export OS_REGION_NAME=RegionOne$/,
        ].each do |line|
          expect(chef_run).to render_file(file.name).with_content(line)
        end
      end

      context 'misc_openrc array' do
        cached(:chef_run) do
          node.override['openstack']['misc_openrc'] = ['export MISC1=OPTION1', 'export MISC2=OPTION2']
          runner.converge(described_recipe)
        end
        it 'templates misc_openrc array correctly' do
          expect(chef_run).to render_file(file.name).with_content(
            /^export MISC1=OPTION1$/
          )
          expect(chef_run).to render_file(file.name).with_content(
            /^export MISC2=OPTION2$/
          )
        end
      end

      context 'override auth environment variables' do
        cached(:chef_run) do
          node.override['openstack']['identity']['admin_project'] = 'admin-project-name-override'
          node.override['openstack']['identity']['admin_user'] = 'identity_admin'
          node.override['openstack']['identity']['admin_domain_id'] = 'admin-domain-override'
          node.override['openstack']['endpoints']['public']['identity']['uri'] = 'https://public.identity:1234/'
          runner.converge(described_recipe)
        end
        it 'contains overridden auth environment variables' do
          [
            /^export OS_USERNAME=identity_admin$/,
            /^export OS_PROJECT_NAME=admin-project-name-override$/,
            /^export OS_PASSWORD=identity_admin_pass$/,
            %r{^export OS_AUTH_URL=https://public.identity:1234/$},
          ].each do |line|
            expect(chef_run).to render_file(file.name).with_content(line)
          end
        end
      end
    end
  end
end
