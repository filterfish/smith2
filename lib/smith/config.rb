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
  class MissingConfigItemError < StandardError; end

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
      @config = load_tomls(default_config_file, @config_file)
      coerce_directories!
    end

    # Make sure the non-default direcotires are set.
    # @raise [MissingConfigItemError<Array<String>>] the config items that are not set.
    def check_directories
      errors = []
      errors << "agncy.acl_directories" if @config.agency[:acl_directories].empty?
      errors << "agncy.agent_directories" if @config.agency[:agent_directories].empty?

      unless errors.empty?
        raise MissingConfigItemError, errors
      end
    end

    # Check appropriate env vars and convert the string representation to Pathname
    # @return [ConfigHash] the config with coerced paths.
    def coerce_directories!
      @config.tap do |c|
        c.agency[:pid_directory] = path_from_env('SMITH_PID_DIRECTORY', c.agency[:pid_directory])
        c.agency[:cache_directory] = path_from_env('SMITH_CACHE_DIRECTORY', c.agency[:cache_directory])
        c.agency[:acl_directories] = paths_from_env('SMITH_ACL_DIRECTORIES', c.agency[:acl_directories])
        c.agency[:agent_directories] = paths_from_env('SMITH_AGENT_DIRECTORIES', c.agency[:agent_directories])
      end

      check_directories
      @config.agency[:acl_directories] = @config.agency[:acl_directories] + [smith_acl_directory]
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

    # Convert a string to a path
    #
    # @param path [String] the string to convert
    # @return [Pathname]
    def to_pathname(path)
      Pathname.new(path).expand_path
    end

    # Returns a path from the environment variable passed in. If the
    # environment variable is not set it returns nil.
    #
    # @param env_var [String] the name of the environment variable
    # @param default [String] the value to use if the environment variable is not set
    # @return [Pathname]
    def path_from_env(env_var, default)
      to_pathname(ENV.fetch(env_var, default))
    end

    # Returns an array of path from the environment variable passed in. If the
    # environment variable is not set it returns an empty array.
    #
    # @param env_var [String] the name of the environment variable
    # @param default [String] the value to use if the environment variable is not set
    # @return [Array<Pathnmae>]
    def paths_from_env(env_var, default)
      split_paths(ENV.fetch(env_var, default))
    end

    # Splits a string using PATH_SEPARATOR.
    #
    # @param paths to split
    # @return [Array<Pathnmae>]
    def split_paths(paths)
      (paths || '').split(File::PATH_SEPARATOR).map { |p| to_pathname(p) }
    end

    # @return [Pathnmae]
    def smith_acl_directory
      Pathname.new(__FILE__).dirname.join('messaging').join('acl').expand_path
    end

    # @return [Pathnmae]
    def default_config_file
      gem_root.join('config', 'smithrc.toml')
    end

    # Loads and merges multiple toml files.
    #
    # @param default [String] the default toml file
    # @param secondary [String] the user supplied toml file
    # @return [ConfigHash] the merge toml files.
    def load_tomls(default, secondary)
      load_toml(default).deep_merge(load_toml(secondary))
    end

    # Load the toml file specified
    #
    # @param path [Pathname] the path of the toml file
    # @return [ConfigHash] the toml file
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
