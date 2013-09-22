#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'pathname'

module Smith

  class ConfigNotFoundError < IOError; end

  class Config

    CONFIG_FILENAME = '.smithrc'

    attr_accessor :agent, :agency, :amqp, :logging, :smith, :eventmachine, :smith, :ruby

    to_hash = proc do
      def to_hash
        Hash[*members.zip(values).flatten]
      end

      def merge(h)
        to_hash.merge(h)
      end

      def has_key?(k)
        to_hash.has_key?(k)
      end
    end

    Struct.new("Agent", :monitor, :singleton, :metadata, :prefetch, &to_hash)
    Struct.new("Agency", :cache_path, :agent_path, :acl_path, :acl_cache_path, :pid_dir, &to_hash)
    Struct.new("AmqpOpts", :durable, :auto_delete, &to_hash)
    Struct.new("Broker", :host, :port, :user, :password, :vhost, &to_hash)
    Struct.new("Subscribe", :ack, &to_hash)
    Struct.new("Pop", :ack, &to_hash)
    Struct.new("Publish", :headers, &to_hash)
    Struct.new("Amqp", :broker, :exchange, :queue, :publish, :subscribe, :pop, &to_hash)
    Struct.new("Appender", :type, :filename, &to_hash)
    Struct.new("Logging", :trace, :level, :default_pattern, :default_date_pattern, :appender, :filetype, :vhost, &to_hash)
    Struct.new("Smith", :namespace, :timeout, &to_hash)
    Struct.new("Eventmachine", :file_descriptors, :epoll, :kqueue, &to_hash)

    def initialize
      load_config
    end

    def reload
      @config = Config.new
    end

    def to_hash
      {:agent => @agent, :agency => @agency, :amqp => @amqp, :eventmachine => @eventmachine, :logging => @logging, :smith => @smith, :ruby => @ruby}
    end

    def path
      @config_file
    end

    def self.get
      @config ||= Config.new
    end

    private

    def set_as_boolean(config, k, default=nil)
      v = config[k]
      if v.nil? && default
        default
      else
        v = v.downcase
        if v == 'true'
          true
        elsif v == 'false'
          false
        else
          raise ArgumentError, "#{k} must be true or false, #{v} given."
        end
      end
    end

    def set_as_string(config, k, default=nil)
      config[k]
    end

    def set_as_integer(config, k, default=nil)
      v = config[k]
      if v.nil? && default
        default
      else
        begin
          Integer(v)
        rescue
          raise ArgumentError, "#{k} must be an integer. #{v} given."
        end
      end
    end

    def load_config
      config = read_config_file(find_config_file)

      amqp_opts = Struct::AmqpOpts.new(true, false)
      cache_path = Pathname.new(config[:agency_cache_path]).expand_path
      local_acl_path = Pathname.new(__FILE__).dirname.join('messaging').join('acl').expand_path
      acl_path = "#{local_acl_path}#{File::PATH_SEPARATOR}#{config[:acl_path]}"
      broker = Struct::Broker.new(config[:broker_host], set_as_integer(config, :broker_port), config[:broker_user], config[:broker_password], config[:broker_vhost] || '/')
      appender = Struct::Appender.new(config[:logging_appender_type], config[:logging_appender_filename])

      @agent = Struct::Agent.new(set_as_boolean(config, :agent_monitor), set_as_boolean(config, :agent_singleton), '', set_as_integer(config, :agent_prefetch))
      @agency = Struct::Agency.new(cache_path, config[:agent_path], acl_path, cache_path.join('acl'), config[:agency_pid_dir])
      @amqp = Struct::Amqp.new(broker, amqp_opts, amqp_opts, Struct::Publish.new({}), Struct::Subscribe.new(true), Struct::Pop.new(true))
      @eventmachine = Struct::Eventmachine.new(set_as_integer(config, :file_descriptors, 1024), set_as_boolean(config, :epoll, true), set_as_boolean(config, :kqueue, true))
      @logging = Struct::Logging.new(config[:logging_trace], config[:logging_level], config[:logging_pattern], config[:logging_date_pattern], appender)
      @smith = Struct::Smith.new(config[:smith_namespace], set_as_integer(config, :smith_timeout))

      # Set the default ruby runtime. This will use the ruby that is in the path.
      @ruby = Hash.new(config[:default_vm] || 'ruby')

      config[:agent_vm] && config[:agent_vm].split(/\s+/).each do |vm_spec|
        agent, vm = vm_spec.split(/:/)
        @ruby[agent] = vm
      end

      find_config_file
    end

    # Read the config file
    def read_config_file(config_file)
      @config_file = config_file
      config_file.readlines.inject({}) do |a, line|
        a.tap do |acc|
          parameters = line.gsub(/#.*$/, '').strip
          unless parameters.empty?
            key, value = parameters.split(/\s+/, 2)
            a[key.to_sym] = value
          end
        end
      end
    end

    # Find the config file. If it isn't in the CWD recurse up the file path
    # until it reaches the user home directory. If it gets to the home
    # directory without finding a config file rais a ConfigNotFoundError
    # exception.
    #
    # path:       the pathname to find the config file. Defaults to CWD.
    # recursive:  rucures up the path. Defaults to true.
    def find_config_file(path=Pathname.new(".").expand_path, recursive=true)
      conf = path.join(CONFIG_FILENAME)
      if conf.exist?
        return conf
      else
        if path == Pathname.new(ENV['HOME']) || path.root?
          raise ConfigNotFoundError, "Cannot find a usable config file."
        end
        find_config_file(path.dirname)
      end
    end
  end
end
