actions :create_ec2

# In earlier versions of Chef the LWRP DSL doesn't support specifying
# a default action, so you need to drop into Ruby.
def initialize(*args)
  super
  @action = :create_ec2
end

attribute :auth_protocol, :kind_of => String, :equal_to => [ "http", "https" ]
attribute :auth_host, :kind_of => String
attribute :auth_port, :kind_of => String
attribute :api_ver, :kind_of => String, :default => "/v2.0"
attribute :auth_token, :kind_of => String

attribute :tenant_name, :kind_of => String
attribute :user_name, :kind_of => String
