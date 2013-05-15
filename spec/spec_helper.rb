require "chefspec"

::LOG_LEVEL = :fatal
::REDHAT_OPTS = {
    :platform  => "redhat",
    :log_level => ::LOG_LEVEL
}
::UBUNTU_OPTS = {
    :platform  => "ubuntu",
    :version   => "12.04",
    :log_level => ::LOG_LEVEL
}

def keystone_stubs
  ::Chef::Recipe.any_instance.stub(:memcached_servers).and_return []
  ::Chef::Recipe.any_instance.stub(:db_password).and_return String.new
  ::Chef::Recipe.any_instance.stub(:secret).and_return String.new
end
