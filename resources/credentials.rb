#
# Cookbook Name:: openstack-identity
# Resource:: credentials
#
# Copyright 2012, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

actions :create_ec2

# In earlier versions of Chef the LWRP DSL doesn't support specifying
# a default action, so you need to drop into Ruby.
def initialize(*args)
  super
  @action = :create_ec2
end

attribute :auth_uri, :kind_of => String
attribute :bootstrap_token, :kind_of => String

attribute :tenant_name, :kind_of => String
attribute :user_name, :kind_of => String
