require 'capistrano'
require 'chef/knife'
require 'chef/data_bag_item'
require 'chef/search/query'

module Capistrano::Chef
  # Set up chef configuration
  def self.configure_chef
    knife = Chef::Knife.new
    # If you don't do this it gets thrown into debug mode
    knife.config = { :verbosity => 1 }
    knife.configure_chef
  end

  # Do a search on the Chef server and return an attary of the requested
  # matching attributes
  def self.search_chef_nodes(query = '*:*', options = {})
    # TODO: This can only get a node's top-level attributes. Make it get nested
    # ones.
    attr = options.delete(:attribute) || :ipaddress
    # WTF, options never passed
    Chef::Search::Query.new.search(:node, query)[0].map {|n| n[:ec2][:public_hostname] }
  end

  def self.get_apps_data_bag_item(id)
    Chef::DataBagItem.load(:apps, id).raw_data
  end

  # Load into Capistrano
  def self.load_into(configuration)
    self.configure_chef
    configuration.set :capistrano_chef, self
    configuration.load do
      def chef_server_private_ip(public_hostname)
        servers = Chef::Search::Query.new.search(:node, "public_hostname:#{public_hostname}")[0]
        raise "found more than 1 server for public hostname: #{public_hostname}" if servers.size > 1
        raise "no server found for #{public_hostname} public hostname" if servers.empty?
        servers[0][:cloud][:local_ipv4]
      end #find_chef_server

      def chef_role(name, query = '*:*', options = {})
        role name, *(capistrano_chef.search_chef_nodes(query) + [options])
      end

      def set_from_data_bag
        raise ':application must be set' if fetch(:application).nil?
        capistrano_chef.get_apps_data_bag_item(application).each do |k, v|
          set k, v
        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::Chef.load_into(Capistrano::Configuration.instance)
end
