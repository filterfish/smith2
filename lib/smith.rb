# -*- encoding: utf-8 -*-
require 'amqp'
require 'tmpdir'
require "socket"
require 'logging'
require 'pathname'
require 'protobuf'
require 'fileutils'
require 'multi_json'
require 'securerandom'
require 'extlib/string'
require 'extlib/inflection'
require 'daemons/pidfile'

require_relative 'smith/config'
require_relative 'smith/logger'
require_relative 'smith/acl_compiler'

MultiJson.use(:oj)

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

    def config_path
      Smith.config.path
    end

    def root_path
      Pathname.new(__FILE__).dirname.parent.expand_path
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

    def cache_path
      Pathname.new(config.agency.cache_path).expand_path
    end

    # Return the acl cache path.
    def acl_cache_path
      @acl_cache_path = Pathname.new(Smith.config.agency.acl_cache_path).tap do |path|
        check_path(path, true)
      end
    end

    def compile_acls
      @compiler = ACLCompiler.new
      @compiler.compile
    end

    def running?
      EM.reactor_running?
    end

    def start(opts={}, &block)

      if EM.epoll? && Smith.config.eventmachine.epoll
        logger.debug { "Using epoll for I/O event notification." }
        EM.epoll
      end

      if EM.kqueue? && Smith.config.eventmachine.kqueue
        logger.debug { "Using kqueue for I/O event notification." }
        EM.kqueue
      end

      connection_settings = config.amqp.broker.merge(
        :on_tcp_connection_failure => method(:tcp_connection_failure_handler),
        :on_possible_authentication_failure => method(:authentication_failure_handler))

      AMQP.start(connection_settings) do |connection|
        @connection = connection

        connection.on_connection do
          logger.info { "Connected to: AMQP Broker: #{broker_identifier(connection)}" } unless opts[:quiet]
        end

        # FIXME This should go in the config.
        reconnection_delay = 5

        connection.on_tcp_connection_loss do |connection, settings|
          logger.info { "Reconnecting to AMQP Broker: #{broker_identifier(connection)} in #{reconnection_delay}s" }
          connection.reconnect(false, reconnection_delay)
        end

        connection.after_recovery do |connection|
          logger.info { "Connection with AMQP Broker restored: #{broker_identifier(connection)}" } unless opts[:quiet]
        end

        connection.on_error do |connection, connection_close|
          # If the broker is gracefully shutdown we get a 320. Log a nice message.
          if connection_close.reply_code == 320
            logger.warn { "AMQP Broker shutdown: #{broker_identifier(connection)}" }
          else
            logger.warn {  connection_close.reply_text }
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

    def broker_identifier(connection)
      broker = connection.broker.properties
      "#{connection.broker_endpoint}, (#{broker['product']}/v#{broker['version']})"
    end

    def check_path(path, create=false)
      unless path.exist?
        error_message = "Path does not exist: #{path}"
        if create
          logger.info { "#{error_message}. Creating" }
          path.mkpath
        else
          logger.warn { error_message }
        end
      end
    end

  end
end

require 'smith/utils'
require 'smith/self_pipe'
require 'smith/amqp_errors'
require 'smith/object_count'
require 'smith/cache'
require 'smith/exceptions'
require 'smith/object_count'
require 'smith/version'
require 'smith/acl_parser'

require 'smith/messaging/acl_type_cache'
require 'smith/messaging/queue_definition'
require 'smith/messaging/amqp_options'
require 'smith/messaging/queue_factory'
require 'smith/messaging/factory'
require 'smith/messaging/acl/default'
require 'smith/messaging/util'
require 'smith/messaging/responder'
require 'smith/messaging/receiver'
require 'smith/messaging/sender'

require 'smith/queue_definitions'
