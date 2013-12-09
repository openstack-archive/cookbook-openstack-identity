require_relative "spec_helper"

describe "openstack-identity::server" do
  before { identity_stubs }
  describe "redhat" do
    before do
      @chef_run = ::ChefSpec::Runner.new ::REDHAT_OPTS
      @chef_run.converge "openstack-identity::server"
    end

    it "converges when configured to use sqlite db backend" do
      chef_run = ::ChefSpec::Runner.new ::REDHAT_OPTS
      node = chef_run.node
      node.set["openstack"]["db"]["identity"]["db_type"] = "sqlite"
      chef_run.converge "openstack-identity::server"
    end

    it "installs mysql python packages" do
      expect(@chef_run).to install_package "MySQL-python"
    end

    it "installs postgresql python packages if explicitly told" do
      chef_run = ::ChefSpec::Runner.new ::REDHAT_OPTS do |n|
        n.set["openstack"]["db"]["identity"]["db_type"] = "postgresql"
      end
      chef_run.converge "openstack-identity::server"

      expect(chef_run).to install_package "python-psycopg2"
    end

    it "installs memcache python packages" do
      expect(@chef_run).to install_package "python-memcached"
    end

    it "installs keystone packages" do
      expect(@chef_run).to upgrade_package "openstack-keystone"
    end

    it "starts keystone on boot" do
      expect(@chef_run).to enable_service("openstack-keystone")
    end
  end
end
