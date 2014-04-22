# encoding: UTF-8

require_relative 'spec_helper'

describe 'openstack-identity::default' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) { runner.converge(described_recipe) }
    let(:events) { Chef::EventDispatch::Dispatcher.new }
    let(:cookbook_collection) { Chef::CookbookCollection.new([]) }
    let(:run_context) { Chef::RunContext.new(node, cookbook_collection, events) }

    describe 'tenant_create' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('tenant1',
                                                          run_context)
        r.tenant_name('tenant1')
        r.tenant_description('tenant1 Tenant')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'when tenant does not already exist' do
        before do
          provider.stub(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
          provider.stub(:identity_command)
            .with(resource, 'tenant-create',
                  'name' => 'tenant1',
                  'description' => 'tenant1 Tenant',
                  'enabled' => true)
            .and_return(true)
        end

        it 'should create a tenant' do
          provider.run_action(:create_tenant)

          expect(resource).to be_updated
        end
      end

      context 'when tenant does already exist' do
        before do
          provider.stub(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
        end

        it 'should not create a tenant' do
          provider.run_action(:create_tenant)

          expect(resource).to_not be_updated
        end
      end
    end

    describe 'service_create' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('service1',
                                                          run_context)
        r.service_type('compute')
        r.service_name('service1')
        r.service_description('service1 Service')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'catalog.backend is sql' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'sql'
        end

        context 'when service does not already exist' do
          it 'should create a service' do
            provider.stub(:identity_uuid)
              .with(resource, 'service', 'type', 'compute')
            provider.stub(:identity_command)
              .with(resource, 'service-create',
                    'type' => 'compute',
                    'name' => 'service1',
                    'description' => 'service1 Service')
              .and_return(true)
            provider.run_action(:create_service)

            expect(resource).to be_updated
          end
        end

        context 'when service does not already exist' do
          it 'should not create a service' do
            provider.stub(:identity_uuid)
              .with(resource, 'service', 'type', 'compute')
              .and_return('1234567890ABCDEFGH')
            provider.run_action(:create_service)

            expect(resource).to_not be_updated
          end
        end
      end

      context 'catalog.backend is templated' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'templated'
        end

        it 'should not create a service if using a templated backend' do
          provider.run_action(:create_service)
          expect(resource).to_not be_updated
        end
      end
    end

    describe 'service_create' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('endpoint1',
                                                          run_context)
        r.endpoint_region('Region One')
        r.service_type('compute')
        r.endpoint_publicurl('http://public')
        r.endpoint_internalurl('http://internal')
        r.endpoint_adminurl('http://admin')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'catalog.backend is sql' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'sql'
        end

        context 'when endpoint does not already exist' do
          before do
            provider.stub(:identity_uuid)
              .with(resource, 'service', 'type', 'compute')
              .and_return('1234567890ABCDEFGH')
            provider.stub(:identity_uuid)
              .with(resource, 'endpoint', 'service_id', '1234567890ABCDEFGH')
            provider.stub(:identity_command)
              .with(resource, 'endpoint-create',
                    'region' => 'Region One',
                    'service_id' => '1234567890ABCDEFGH',
                    'publicurl' => 'http://public',
                    'internalurl' => 'http://internal',
                    'adminurl' => 'http://admin')
          end

          it 'should create an endpoint' do
            provider.run_action(:create_endpoint)
            expect(resource).to be_updated
          end
        end

        context 'when endpoint does already exist' do
          before do
            provider.stub(:identity_uuid)
              .with(resource, 'service', 'type', 'compute')
              .and_return('1234567890ABCDEFGH')
            provider.stub(:identity_uuid)
              .with(resource, 'endpoint', 'service_id', '1234567890ABCDEFGH')
              .and_return('0987654321HGFEDCBA')
          end

          it 'should not create an endpoint' do
            provider.run_action(:create_endpoint)
            expect(resource).to_not be_updated
          end
        end
      end

      context 'catalog.backend is templated' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'templated'
        end

        it 'should not create an endpoint' do
          provider.run_action(:create_endpoint)
          expect(resource).to_not be_updated
        end
      end
    end

    describe 'role create' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('role1', run_context)
        r.role_name('role1')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'when role does not already exist' do
        before do
          provider.stub(:identity_uuid)
            .with(resource, 'role', 'name', 'role1')
          provider.stub(:identity_command)
            .with(resource, 'role-create',
                  'name' => 'role1')
        end

        it 'should create a role' do
          provider.run_action(:create_role)
          expect(resource).to be_updated
        end
      end

      context 'when role already exist' do
        before do
          provider.stub(:identity_uuid)
            .with(resource, 'role', 'name', 'role1')
            .and_return('1234567890ABCDEFGH')
        end

        it 'should not create a role' do
          provider.run_action(:create_role)
          expect(resource).to_not be_updated
        end
      end
    end

    describe 'user create' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('user1', run_context)
        r.user_name('user1')
        r.tenant_name('tenant1')
        r.user_pass('password')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'when user does not already exist' do
        before do
          provider.stub(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          provider.stub(:identity_command)
            .with(resource, 'user-list',
                  'tenant-id' => '1234567890ABCDEFGH')
          provider.stub(:identity_command)
            .with(resource, 'user-create',
                  'name' => 'user1',
                  'tenant-id' => '1234567890ABCDEFGH',
                  'pass' => 'password',
                  'enabled' => true)
          provider.stub(:prettytable_to_array)
            .and_return([])
        end

        it 'should create a user' do
          provider.run_action(:create_user)
          expect(resource).to be_updated
        end
      end

      context 'when user already exist' do
        before do
          provider.stub(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          provider.stub(:identity_command)
            .with(resource, 'user-list',
                  'tenant-id' => '1234567890ABCDEFGH')
          provider.stub(:prettytable_to_array)
            .and_return([{ 'name' => 'user1' }])
          provider.stub(:identity_uuid)
            .with(resource, 'user', 'name', 'user1')
            .and_return('HGFEDCBA0987654321')
        end

        it 'should not create a user' do
          provider.run_action(:create_user)
          expect(resource).to_not be_updated
        end
      end

      describe '#identity_command' do
        it 'should handle false values and long descriptions' do
          provider.stub(:shell_out)
            .with(['keystone', 'user-create', '--enabled',
                   'false', '--description', 'more than one word'],
                  env: {
                    'OS_SERVICE_ENDPOINT' => nil,
                    'OS_SERVICE_TOKEN' => nil })
            .and_return double('shell_out', exitstatus: 0, stdout: 'good')

          expect(
            provider.send(:identity_command, resource, 'user-create',
                          'enabled' => false,
                          'description' => 'more than one word')
          ).to eq('good')
        end
      end
    end

    describe 'role grant' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('grant1', run_context)
        r.user_name('user1')
        r.tenant_name('tenant1')
        r.role_name('role1')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'when role has not already been granted' do
        before do
          provider.stub(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          provider.stub(:identity_uuid)
            .with(resource, 'user', 'name', 'user1')
            .and_return('HGFEDCBA0987654321')
          provider.stub(:identity_uuid)
            .with(resource, 'role', 'name', 'role1')
            .and_return('ABC1234567890DEF')
          provider.stub(:identity_uuid)
            .with(resource, 'user-role', 'name', 'role1',
                  'tenant-id' => '1234567890ABCDEFGH',
                  'user-id' => 'HGFEDCBA0987654321')
            .and_return('ABCD1234567890EFGH')
          provider.stub(:identity_command)
            .with(resource, 'user-role-add',
                  'tenant-id' => '1234567890ABCDEFGH',
                  'role-id' => 'ABC1234567890DEF',
                  'user-id' => 'HGFEDCBA0987654321')
        end

        it 'should grant a role' do
          provider.run_action(:grant_role)
          expect(resource).to be_updated
        end
      end

      context 'when role has already been granted' do
        before do
          provider.stub(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          provider.stub(:identity_uuid)
            .with(resource, 'user', 'name', 'user1')
            .and_return('HGFEDCBA0987654321')
          provider.stub(:identity_uuid)
            .with(resource, 'role', 'name', 'role1')
            .and_return('ABC1234567890DEF')
          provider.stub(:identity_uuid)
            .with(resource, 'user-role', 'name', 'role1',
                  'tenant-id' => '1234567890ABCDEFGH',
                  'user-id' => 'HGFEDCBA0987654321')
            .and_return('ABC1234567890DEF')
          provider.stub(:identity_command)
            .with(resource, 'user-role-add',
                  'tenant-id' => '1234567890ABCDEFGH',
                  'role-id' => 'ABC1234567890DEF',
                  'user-id' => 'HGFEDCBA0987654321')
        end

        it 'should not grant a role' do
          provider.run_action(:grant_role)
          expect(resource).to_not be_updated
        end
      end
    end

    describe 'ec2_credentials create' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('ec2', run_context)
        r.user_name('user1')
        r.tenant_name('tenant1')
        r.admin_tenant_name('admintenant1')
        r.admin_user('adminuser1')
        r.admin_pass('password')
        r.identity_endpoint('http://admin')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'when ec2 creds have not already been created' do
        before do
          provider.stub(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          provider.stub(:identity_uuid)
            .with(resource, 'user', 'name', 'user1',
                  'tenant-id' => '1234567890ABCDEFGH')
            .and_return('HGFEDCBA0987654321')
          provider.stub(:identity_uuid)
            .with(resource, 'ec2-credentials', 'tenant', 'tenant1',
                  { 'user-id' => 'HGFEDCBA0987654321' }, 'access')
          provider.stub(:identity_command)
            .with(resource, 'ec2-credentials-create',
                  'user-id' => 'HGFEDCBA0987654321',
                  'tenant-id' => '1234567890ABCDEFGH')
          provider.stub(:prettytable_to_array)
            .and_return([{ 'access' => 'access', 'secret' => 'secret' }])
        end

        it 'should grant ec2 creds' do
          provider.run_action(:create_ec2_credentials)
          expect(resource).to be_updated
        end
      end

      context 'when ec2 creds have not already been created' do
        before do
          provider.stub(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          provider.stub(:identity_uuid)
            .with(resource, 'user', 'name', 'user1',
                  'tenant-id' => '1234567890ABCDEFGH')
            .and_return('HGFEDCBA0987654321')
          provider.stub(:identity_uuid)
            .with(resource, 'ec2-credentials', 'tenant', 'tenant1',
                  { 'user-id' => 'HGFEDCBA0987654321' }, 'access')
            .and_return('ABC1234567890DEF')
        end

        it 'should grant ec2 creds if they already exist' do
          provider.run_action(:create_ec2_credentials)
          expect(resource).to_not be_updated
        end
      end
    end
  end
end
