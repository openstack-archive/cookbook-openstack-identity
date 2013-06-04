require_relative "spec_helper"

describe "openstack-identity::db" do
  it "installs mysql packages" do
    @chef_run = converge
  end

  it "creates database and user" do
    ::Chef::Recipe.any_instance.should_receive(:db_create_with_user).
      with "identity", "keystone", "test-pass"

    converge
  end

  def converge
    ::Chef::Recipe.any_instance.stub(:db_password).with("keystone").
      and_return "test-pass"

    ::ChefSpec::ChefRunner.new(::UBUNTU_OPTS).converge "openstack-identity::db"
  end
end
