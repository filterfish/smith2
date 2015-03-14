#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'toml'
require 'pathname'
require 'hashie/extensions/coercion'
require 'hashie/extensions/deep_merge'
require 'hashie/extensions/method_access'
require 'hashie/extensions/merge_initializer'


module Smith

  class ConfigNotFoundError < IOError; end

  class Config

    CONFIG_FILENAME = 'smithrc'

    SYSTEM_CONFIG_PATHS = ['/etc', "/etc/smith"].map do |p|
      Pathname.new(p).join(CONFIG_FILENAME)
    end

    def initialize(filename=".#{CONFIG_FILENAME}")
      @filename = filename
      load_config
    end

    def reload
      @config = Config.new(@filename)
    end

    def path
      @config_file
    end

    def self.get(filename=".#{CONFIG_FILENAME}")
      @config ||= Config.new(filename)
    end

    def method_missing(method, *args)
      @config.send(method, *args)
    end

    private

    class ConfigHash < Hash
      include Hashie::Extensions::Coercion
      include Hashie::Extensions::DeepMerge
      include Hashie::Extensions::MethodReader
      include Hashie::Extensions::MergeInitializer

      coerce_value Hash, ConfigHash
    end

    def load_config
      toml = TOML.parse(read_config_file(find_config_file), :symbolize_keys => true)
      @config = coerce_directories!(ConfigHash.new(default_amqp_opts).deep_merge(toml))
    end

    # Read the config file
    def read_config_file(config_file)
      @config_file = config_file
      config_file.read
    end

    # Check appropriate env vars and convert the string representation to Pathname
    # @param config [ConfigHash] the config.
    # @return [ConfigHash] the config with coerced paths.
    def coerce_directories!(config)
      config.tap do |c|
        c.agency[:pid_directory] = path_from_env('SMITH_PID_DIRECTORY', c.agency[:pid_directory])
        c.agency[:cache_directory] = path_from_env('SMITH_CACHE_DIRECTORY', c.agency[:cache_directory])

        c.agency[:acl_directories] = paths_from_env('SMITH_ACL_DIRECTORIES', c.agency[:acl_directories]) + [smith_acl_directory]
        c.agency[:agent_directories] = paths_from_env('SMITH_AGENT_DIRECTORIES', c.agency[:agent_directories])
      end
    end

    # Find the config file. If it isn't in the CWD recurse up the file path
    # until it reaches the user home directory. If it gets to the home
    # directory without finding a config file it will read /etc/smithrc and
    # then /etc/smith/config. If that fails give up and raise a
    # ConfigNotFoundError exception.
    #
    # path:       the pathname to find the config file. Defaults to CWD.
    # recursive:  rucures up the path. Defaults to true.
    def find_config_file(path=to_pathname("."), recursive=true)
      conf = path.join(@filename)
      if conf.exist?
        return conf
      else
        if path == to_pathname(ENV['HOME'])
          # Can't find the config file in the dir hierachy. Check default dirs
          p = SYSTEM_CONFIG_PATHS.detect { |p| p.exist? }
          if p
            return p
          else
            raise ConfigNotFoundError, "Cannot find a config file name: #{@filename}"
          end
        else
          if path.root?
            raise ConfigNotFoundError, "Cannot find a config file name: #{@filename}"
          end
        end
        find_config_file(path.dirname)
      end
    end

    def default_amqp_opts
      { :amqp => {
          :exchange => {:durable => true, :auto_delete => false},
          :queue => {:durable => true, :auto_delete => false},
          :pop => {:ack => true},
          :publish => {:headers => {}},
          :subscribe => {:ack => true}
        }
      }
    end

    def to_pathname(p)
      Pathname.new(p).expand_path
    end

    def path_from_env(env_var, var)
      to_pathname((ENV[env_var]) ? ENV[env_var] : var)
    end

    def paths_from_env(env_var, vars)
      split_path(vars).map { |var| path_from_env(env_var, var) }
    end

    def split_path(paths)
      paths.split(File::PATH_SEPARATOR)
    end

    def smith_acl_directory
      Pathname.new(__FILE__).dirname.join('messaging').join('acl').expand_path
    end
  end
end
