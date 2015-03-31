# Encoding: UTF-8
require 'chefspec'
require 'chefspec/berkshelf'

ChefSpec::Coverage.start! { add_filter 'openstack-identity' }

LOG_LEVEL = :fatal
SUSE_OPTS = {
  platform: 'suse',
  version: '11.3',
  log_level: LOG_LEVEL
}
REDHAT_OPTS = {
  platform: 'redhat',
  version: '7.1',
  log_level: LOG_LEVEL
}
UBUNTU_OPTS = {
  platform: 'ubuntu',
  version: '14.04',
  log_level: LOG_LEVEL
}

# Helper methods
module Helpers
  # Create an anchored regex to exactly match the entire line
  # (name borrowed from grep --line-regexp)
  #
  # @param [String] str The whole line to match
  # @return [Regexp] The anchored/escaped regular expression
  def line_regexp(str)
    /^#{Regexp.quote(str)}$/
  end
end

shared_context 'identity_stubs' do
  before do
    allow_any_instance_of(Chef::Recipe).to receive(:memcached_servers)
      .and_return([])
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('db', anything)
      .and_return('')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('user', anything)
      .and_return('')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('user', 'user1')
      .and_return('secret1')
    allow_any_instance_of(Chef::Recipe).to receive(:get_secret)
      .with('openstack_identity_bootstrap_token')
      .and_return('bootstrap-token')
  end
end
