# -*- encoding: utf-8 -*-
require 'amqp'
require 'tmpdir'
require 'logging'
require 'beefcake'
require 'pathname'
require 'optimism'
require 'dm-core'
require 'securerandom'
require 'dm-yaml-adapter'
require 'extlib/string'
require 'extlib/inflection'
require 'daemons/pidfile'

require_relative 'smith/config'
require_relative 'smith/logger'

module Smith
  include Logger

  class << self

    def channel
      raise RuntimeError, "You must run this in a Smith.start block" if @channel.nil?
      @channel
    end

    def on_error=(handler)
      @handler = handler
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

    def pb_path
      path_to_pathnames(config.agency.protocol_buffer_path)
    end

    # Return the protocol cache path. If it's not specified in the config
    # generate a temporary path.
    def pb_cache_path
      if Smith.config.agency._has_key?(:protocol_buffer_cache_path)
        Pathname.new(Smith.config.agency.protocol_buffer_cache_path)
      else
        pre_existing_cache_dir = Pathname.glob(Pathname.new(Dir.tmpdir).join("smith-pb*"))
        if pre_existing_cache_dir.empty?
          Pathname.new(Dir.mktmpdir("smith-pb-"))
        else
          pre_existing_cache_dir.first
        end
      end
    end

    def running?
      EM.reactor_running?
    end

    def start(opts={}, &block)
      EM.epoll if EM.epoll?
      EM.kqueue if EM.kqueue?
      EM.set_descriptor_table_size(opts[:fdsize] || 1024)

      connection_settings = config.amqp.broker._child.merge({
        :on_tcp_connection_failure => method(:tcp_connection_failure_handler),
        :on_possible_authentication_failure => method(:authentication_failure_handler)
      })

      AMQP.start(connection_settings) do |connection|
        @connection = connection

        connection.on_connection do
          broker = connection.broker.properties
          endpoint = connection.broker_endpoint
          logger.debug("Connected to: AMQP Broker: #{endpoint}, (#{broker['product']}/v#{broker['version']})") unless opts[:quiet]
        end

        connection.on_tcp_connection_loss do |connection, settings|
          logger.error("TCP connection error. Attempting restart")
          connection.reconnect
        end

        connection.after_recovery do
          logger.info("Connection to AMQP server restored")
        end

        connection.on_error do |connection, reason|
          case reason.reply_code
          when 320
            logger.warn("AMQP server shutdown. Waiting.")
          else
            if @handler
              @handler.call(connection, reason)
            else
              logger.error("AMQP Server error: #{reason.reply_code}: #{reason.reply_text}")
            end
          end
        end

        AMQP::Channel.new(connection) do |channel,ok|
          @channel = channel
          # Set up QOS. If you do not do this then the subscribe in receive_message
          # will get overwelmd and the whole thing will collapse in on itself.
          channel.prefetch(1)

          # Log the error and stop the agency when there are channel errors.
          # TODO Add recovery instead of stopping the agency.
          channel.on_error do |ch,channel_close|
            logger.fatal("Channel level exception: #{channel_close.reply_text}. Class id: #{channel_close.class_id}, Method id: #{channel_close.method_id}, Status code : #{channel_close.reply_code}")
            logger.fatal("Agency is exiting")
            Smith.stop(true)
          end

          # Set up auto-recovery. This will ensure that the AMQP gem reconnects each
          # channel and sets up the various exchanges & queues.
          channel.auto_recovery = true

          block.call
        end
      end
    end

    def stop(immediately=false, &blk)
      if immediately
        @connection.close { EM.stop { logger.debug("Reactor Stopped") } }
      else
        if running?
          EM.add_timer(1) do
            @connection.close do
              EM.stop do
                logger.debug("Reactor Stopped")
                blk.call if blk
              end
            end
          end
        else
          logger.fatal("Eventmachine is not running, exiting with prejudice")
          exit!
        end
      end
    end

    private

    def tcp_connection_failure_handler(settings)
      # Only display the following settings.
      s = settings.select { |k,v| ([:user, :pass, :vhost, :host, :port, :ssl].include?(k)) }

      logger.fatal("Cannot connect to the AMQP server.")
      logger.fatal("Is the server running and are the connection details correct?")
      logger.info("Details:")
      s.each do |k,v|
        logger.info(" Setting: %-7s%s" %  [k, v])
      end
      EM.stop
    end

    def authentication_failure_handler(settings)
      # Only display the following settings.
      s = settings.select { |k,v| [:user, :pass, :vhost, :host].include?(k) }

      logger.fatal("Authenticaton failure.")
      logger.info("Details:")
      s.each do |k,v|
        logger.info(" Setting: %-7s%s" %  [k, v])
      end
      EM.stop
    end

    def path_to_pathnames(path)
      path ||= []
      path.split(':').map do |path|
        p = Pathname.new(path)
        (p.absolute?) ? p : root_path.join(p)
      end
    end
  end
end

require_relative 'smith/cache'
require_relative 'smith/agent'
require_relative 'smith/agent_cache'
require_relative 'smith/agent_process'
require_relative 'smith/agent_monitoring'
require_relative 'smith/command'
require_relative 'smith/messaging/encoders/default'
require_relative 'smith/messaging/encoders/agency_command'
require_relative 'smith/messaging/encoders/agent_command'
require_relative 'smith/messaging/encoders/agent_lifecycle'
require_relative 'smith/messaging/encoders/agent_keepalive'
require_relative 'smith/messaging/payload'
require_relative 'smith/messaging/endpoint'
require_relative 'smith/messaging/exceptions'
require_relative 'smith/messaging/responder'
require_relative 'smith/messaging/receiver'
require_relative 'smith/messaging/sender'
