#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'toml'
require 'fileutils'
require 'pathname'
require 'hashie/extensions/coercion'
require 'hashie/extensions/deep_merge'
require 'hashie/extensions/method_access'
require 'hashie/extensions/merge_initializer'

module Smith

  class ConfigNotFoundError < IOError; end

  class Config

    CONFIG_FILENAME = 'smithrc'

    def initialize
      load_config
    end

    def reload
      @config = Config.new
    end

    def path
      @config_file
    end

    def method_missing(method, *args)
      @config.send(method, *args)
    end

    def self.get
      @config ||= Config.new
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
      @config_file = find_config_file
      @config = coerce_directories!(load_tomls(default_config_file, @config_file))
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

    # Find the config file. This checks the following paths before raising an
    # exception:
    #
    # * ./.smithrc
    # * $HOME/.smithrc
    # * /etc/smithrc
    # * /etc/smith/smithrc
    #
    # @return the config file path
    #
    def find_config_file
      if ENV["SMITH_CONFIG"]
        to_pathname(ENV["SMITH_CONFIG"]).tap do |path|
          raise ConfigNotFoundError, "Cannot find a config file name: #{path}" unless path.exist?
        end
      else
        user = ["./.#{CONFIG_FILENAME}", "#{ENV['HOME']}/.#{CONFIG_FILENAME}"].map { |p| to_pathname(p) }
        system = ["/etc/#{CONFIG_FILENAME}", "/etc/smith/#{CONFIG_FILENAME}"].map { |p| to_pathname(p) }
        default = [default_config_file]

        (user + system + default).detect { |path| path.exist? }
      end
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

    def default_config_file
      gem_root.join('config', 'smithrc.toml')
    end

    def load_tomls(default, main)
      load_toml(default).deep_merge(load_toml(main))
    end

    def load_toml(path)
      ConfigHash.new(TOML.parse(path.read, :symbolize_keys => true))
    end

    # Returns the gem root. We can't use Smith.root_path here as it hasn't
    # been initialised yet.
    def gem_root
      Pathname.new(__FILE__).dirname.parent.parent.expand_path
    end
  end
end
