# -*- encoding: utf-8 -*-
require 'amqp'
require 'tmpdir'
require "socket"
require 'logging'
require 'pathname'
require 'fileutils'
require 'optimism'
require 'dm-core'
require 'securerandom'
require 'dm-yaml-adapter'
require 'extlib/string'
require 'extlib/inflection'
require 'daemons/pidfile'

require_relative 'smith/config'
require_relative 'smith/logger'
require_relative 'smith/acl_compiler'

module Smith
  include Logger

  class << self

    def connection
      raise RuntimeError, "You must run this in a Smith.start block" if @connection.nil?
      @connection
    end

    def environment
      ENV['SMITH_ENV'] || 'development'
    end

    def config
      Config.get
    end

    def root_path
      Pathname.new(File.dirname(__FILE__) + '/..').expand_path
    end

    def agent_paths
      path_to_pathnames(config.agency.agent_path)
    end

    # Convenience method to get the hostname
    def hostname
      Socket.gethostname
    end

    def acl_path
      path_to_pathnames(config.agency.acl_path)
    end

    # Return the acl cache path. If it's not specified in the config
    # generate a temporary path.
    def acl_cache_path
      @acl_cache_path ||= if Smith.config.agency._has_key?(:acl_cache_path)
        Pathname.new(Smith.config.agency.acl_cache_path).tap { |path| check_path(path) }
      else
        cache_dir = Pathname.new(ENV['HOME']).join('.smith').join('acl')
        if cache_dir.exist?
          cache_dir
        else
          FileUtils.mkdir_p(cache_dir)
          cache_dir
        end
      end
    end

    def compile_acls
      @compiler = ACLCompiler.new
      @compiler.compile
    end

    # Load all acls. This fucking horrible but for the time
    # being it's how it's going to be. This will really start
    # to be a problem when there are a lot of acls.
    def load_acls
      Pathname.glob(Smith.acl_cache_path.join("*.pb.rb"))do |acl_file|
        logger.verbose { "Loading acl file: #{acl_file}" }
        require acl_file
      end
    end

    def running?
      EM.reactor_running?
    end

    def start(opts={}, &block)
      EM.epoll if EM.epoll?
      EM.kqueue if EM.kqueue?
      EM.set_descriptor_table_size(opts[:fdsize] || 1024)

      connection_settings = config.amqp.broker._merge(
        :on_tcp_connection_failure => method(:tcp_connection_failure_handler),
        :on_possible_authentication_failure => method(:authentication_failure_handler))

      AMQP.start(connection_settings) do |connection|
        @connection = connection

        connection.on_connection do
          broker = connection.broker.properties
          endpoint = connection.broker_endpoint
          logger.debug { "Connected to: AMQP Broker: #{endpoint}, (#{broker['product']}/v#{broker['version']})" } unless opts[:quiet]
        end

        connection.on_tcp_connection_loss do |connection, settings|
          EM.next_tick do
            logger.error { "TCP connection error. Attempting restart" }
            connection.reconnect
          end
        end

        connection.after_recovery do
          logger.info { "Connection to AMQP server restored" }
        end

        connection.on_error do |connection, connection_close|
          case connection_close.reply_code
          when 320
            logger.warn { "AMQP server shutdown. Waiting." }
          else
            if @handler
              @handler.call(connection, reason)
            else
              logger.error { "AMQP Server error: #{connection_close.reply_code}: #{connection_close.reply_text}" }
              EM.stop_event_loop
            end
          end
        end

        # This will be the last thing run by the reactor.
        shutdown_hook { logger.debug { "Reactor Stopped" } }

        block.call
      end
    end

    def shutdown_hook(&block)
      EM.add_shutdown_hook(&block)
    end

    def stop(immediately=false, &blk)
      shutdown_hook(&blk) if blk

      if running?
        if immediately
          EM.next_tick do
            @connection.close { EM.stop_event_loop }
          end
        else
          EM.add_timer(1) do
            @connection.close { EM.stop_event_loop }
          end
        end
      else
        logger.fatal { "Eventmachine is not running, exiting with prejudice" }
        exit!
      end
    end

    private

    def tcp_connection_failure_handler(settings)
      # Only display the following settings.
      s = settings.select { |k,v| ([:user, :pass, :vhost, :host, :port, :ssl].include?(k)) }

      logger.fatal { "Cannot connect to the AMQP server." }
      logger.fatal { "Is the server running and are the connection details correct?" }
      logger.info { "Details:" }
      s.each do |k,v|
        logger.info { " Setting: %-7s%s" %  [k, v] }
      end
      EM.stop
    end

    def authentication_failure_handler(settings)
      # Only display the following settings.
      s = settings.select { |k,v| [:user, :pass, :vhost, :host].include?(k) }

      logger.fatal { "Authentication failure." }
      logger.info { "Details:" }
      s.each do |k,v|
        logger.info { " Setting: %-7s%s" %  [k, v] }
      end
      EM.stop
    end

    def path_to_pathnames(path)
      path ||= []
      path.split(':').map do |path|
        p = Pathname.new(path)
        ((p.absolute?) ? p : root_path.join(p)).tap { |path| check_path(path) }
      end
    end

    def check_path(path)
      logger.error("Path does not exist: #{path}") unless path.exist?
    end
  end
end

require_relative 'smith/object_count'
require_relative 'smith/cache'
require_relative 'smith/agent_cache'
require_relative 'smith/agent_process'
require_relative 'smith/agent_monitoring'
require_relative 'smith/command'
require_relative 'smith/command_base'
require_relative 'smith/exceptions'
require_relative 'smith/object_count'
require_relative 'smith/version'

require_relative 'smith/messaging/amqp_options'
require_relative 'smith/messaging/queue_factory'
require_relative 'smith/messaging/acl/default'
require_relative 'smith/messaging/payload'
require_relative 'smith/messaging/util'
require_relative 'smith/messaging/responder'
require_relative 'smith/messaging/receiver'
require_relative 'smith/messaging/sender'
