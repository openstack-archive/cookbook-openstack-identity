require "spec_helper"

describe "openstack-identity::server" do
  describe "suse" do
    before do
      keystone_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::OPENSUSE_OPTS
      @chef_run.converge "openstack-identity::server"
    end

    it "runs logging recipe if node attributes say to" do
      chef_run = ::ChefSpec::ChefRunner.new ::OPENSUSE_OPTS
      node = chef_run.node
      node.set["openstack"]["identity"]["syslog"]["use"] = true
      node.set["network"]["ipaddress_lo"] = "10.10.10.10"
      chef_run.converge "openstack-identity::server"
      expect(chef_run).to include_recipe "openstack-common::logging"
    end

    it "doesn't run logging recipe" do
      expect(@chef_run).not_to include_recipe "openstack-common::logging"
    end

    it "installs mysql python packages" do
      expect(@chef_run).to install_package "python-mysql"
    end

    it "installs memcache python packages" do
      expect(@chef_run).to install_package "python-python-memcached"
    end

    it "installs keystone packages" do
      expect(@chef_run).to upgrade_package "openstack-keystone"
    end

    it "starts keystone on boot" do
      expect(@chef_run).to set_service_to_start_on_boot "openstack-keystone"
    end

    it "sleep on keystone service enable" do
      expect(@chef_run.service("keystone")).
        to notify "execute[Keystone: sleep]", :run
    end

    describe "/etc/keystone" do
      before do
        @dir = @chef_run.directory "/etc/keystone"
      end

      it "has proper owner" do
        expect(@dir).to be_owned_by "openstack-keystone", "openstack-keystone"
      end

      it "has proper modes" do
        expect(sprintf("%o", @dir.mode)).to eq "700"
      end
    end

    #TODO: ChefSpec needs to handle guards better.
    #      should only be created when pki is enabled
    describe "/etc/keystone/ssl" do
      before do
        @dir = @chef_run.directory "/etc/keystone/ssl"
      end

      it "has proper owner" do
        expect(@dir).to be_owned_by "openstack-keystone", "openstack-keystone"
      end

      it "has proper modes" do
        expect(sprintf("%o", @dir.mode)).to eq "700"
      end
    end

    it "deletes keystone.db" do
      expect(@chef_run).to delete_file "/var/lib/keystone/keystone.db"
    end

    #TODO: ChefSpec needs to handle guards better.
    #      should only be performed when pki is enabled
    it "runs pki setup" do
      cmd = "keystone-manage pki_setup"
      expect(@chef_run).to execute_command(cmd).with(
        :user => "openstack-keystone"
      )
    end

    it "doesn't run pki setup when signing dir exists" do
      pending "TODO: how to test this"
    end

    describe "keystone.conf" do
      before do
        @file = @chef_run.template "/etc/keystone/keystone.conf"
      end

      it "has proper owner" do
        expect(@file).to be_owned_by "openstack-keystone", "openstack-keystone"
      end

      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "644"
      end

      it "template contents" do
        pending "TODO: implement"
      end

      it "notifies nova-api-ec2 restart" do
        expect(@file).to notify "service[keystone]", :restart
      end
    end

    #TODO: ChefSpec needs to handle guards better.
    describe "default_catalog.templates" do
      before do
        @file = @chef_run.template "/etc/keystone/default_catalog.templates"
      end

      it "has proper owner" do
        expect(@file).to be_owned_by "openstack-keystone", "openstack-keystone"
      end

      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "644"
      end

      it "template contents" do
        pending "TODO: implement"
      end

      it "notifies nova-api-ec2 restart" do
        expect(@file).to notify "service[keystone]", :restart
      end
    end

    it "runs db migrations" do
      cmd = "keystone-manage db_sync"
      expect(@chef_run).to execute_command cmd
    end
  end
end
