require "spec_helper"

describe "keystone::server" do
  describe "redhat" do
    before do
      keystone_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::REDHAT_OPTS
      @chef_run.converge "keystone::server"
    end

    it "installs mysql python packages" do
      expect(@chef_run).to install_package "MySQL-python"
    end

    it "installs memcache python packages" do
      expect(@chef_run).to install_package "python-memcached"
    end

    it "installs keystone packages" do
      expect(@chef_run).to upgrade_package "openstack-keystone"
    end

    it "starts keystone on boot" do
      expect(@chef_run).to set_service_to_start_on_boot "openstack-keystone"
    end
  end
end
