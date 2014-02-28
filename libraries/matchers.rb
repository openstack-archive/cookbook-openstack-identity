# encoding: UTF-8
if defined?(ChefSpec)
  def create_service_openstack_identity_register(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(
      :openstack_identity_register,
      :create_service,
      resource_name)
  end

  def create_endpoint_openstack_identity_register(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(
      :openstack_identity_register,
      :create_endpoint,
      resource_name)
  end

  def create_tenant_openstack_identity_register(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(
      :openstack_identity_register,
      :create_tenant,
      resource_name)
  end

  def create_user_openstack_identity_register(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(
      :openstack_identity_register,
      :create_user,
      resource_name)
  end

  def create_role_openstack_identity_register(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(
      :openstack_identity_register,
      :create_role,
      resource_name)
  end

  def grant_role_openstack_identity_register(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(
      :openstack_identity_register,
      :grant_role,
      resource_name)
  end

  def create_ec2_credentials_openstack_identity_register(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(
      :openstack_identity_register,
      :create_ec2_credentials,
      resource_name)
  end
end
