require_relative 'spec_helper'
require 'yaml'

describe 'openstack-identity::cloud_config' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'identity_stubs'

    describe '/root/clouds.yaml' do
      let(:file) { chef_run.template('/root/clouds.yaml') }

      it 'creates the /root/clouds.yaml file' do
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
          mode: '0600',
          variables: {
            cloud_name: 'default',
            identity_endpoint: 'http://127.0.0.1:5000/v3',
            password: 'admin',
            project: 'admin',
            project_domain_name: 'default',
            user_domain_name: 'default',
            user: 'admin',
          }
        )
      end

      cloud_yaml = {
        'clouds' => {
          'default' => {
            'auth' => {
              'username' => 'admin',
              'user_domain_name' => 'default',
              'password' => 'admin',
              'project_name' => 'admin',
              'project_domain_name' => 'default',
              'auth_url' => 'http://127.0.0.1:5000/v3',
            },
            'identity_api_version' => 3,
            'region_name' => 'RegionOne',
          },
        },
      }

      it 'contains auth environment variables' do
        expect(chef_run).to render_file(file.name).with_content(YAML.dump(cloud_yaml))
      end

      context 'override auth environment variables' do
        cloud_yaml_override = {
          'clouds' => {
            'cloud-config-override' => {
              'auth' => {
                'username' => 'identity_admin',
                'user_domain_name' => 'admin-domain-override',
                'password' => 'identity_admin_pass',
                'project_name' => 'admin-project-name-override',
                'project_domain_name' => 'admin-domain-name-override',
                'auth_url' => 'https://public.identity:1234/',
              },
              'identity_api_version' => 3,
              'region_name' => 'RegionOne',
            },
          },
        }
        cached(:chef_run) do
          node.override['openstack']['identity']['cloud_config']['cloud_name'] = 'cloud-config-override'
          node.override['openstack']['identity']['admin_user'] = 'identity_admin'
          node.override['openstack']['identity']['admin_project_domain'] = 'admin-domain-name-override'
          node.override['openstack']['identity']['admin_project'] = 'admin-project-name-override'
          node.override['openstack']['identity']['admin_domain_name'] = 'admin-domain-override'
          node.override['openstack']['endpoints']['public']['identity']['uri'] = 'https://public.identity:1234/'
          runner.converge(described_recipe)
        end
        it 'contains overridden auth environment variables' do
          expect(chef_run).to render_file(file.name).with_content(YAML.dump(cloud_yaml_override))
        end
      end
    end
  end
end
