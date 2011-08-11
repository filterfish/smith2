require 'pp'
require 'amqp'
require 'tmpdir'
require 'pathname'
require 'optimism'
require 'dm-core'
require 'dm-yaml-adapter'
require 'extlib/string'
require 'extlib/inflection'
require 'daemons/pidfile_mp'

require_relative 'smith/logger'
require_relative 'smith/config'
require_relative 'smith/cache'
require_relative 'smith/agent'
require_relative 'smith/agent_cache'
require_relative 'smith/agent_process'
require_relative 'smith/agent_monitoring'
require_relative 'smith/agency_command_processor'
require_relative 'smith/messaging'

module Smith
  include Logger

  class << self

    def config
      Smith::Config.get
    end

    def root_path
      Pathname.new(File.dirname(__FILE__) + '/..').expand_path
    end

    def start(opts={}, &block)

    def start(opts={}, &block)
      EM.epoll if EM.epoll?
      EM.kqueue if EM.kqueue?
      EM.set_descriptor_table_size(opts[:fdsize] || 1024)

      handler = Proc.new { |settings| puts "Cannot connect to the AMQP server."; EM.stop }

      connection_settings = {:on_tcp_connection_failure => handler}

      AMQP.start(connection_settings) do |connection|
        @connection = connection

        @connection.on_error do |conn, reason|
          if @handler
            @handler.call(conn, reason)
          else
            logger.error("Shutting down: #{reason.reply_code}: #{reason.reply_text}")
            EM.stop
          end
        end

        block.call
      end
    end

    def on_error=(handler)
      @handler = handler
    end

    def running?
      EM.reactor_running?
    end
    def connection
      raise RuntimeError, "You must run this in a Smith.start block" if @connection.nil?
      @connection
    end

    def stop(immediately=false)
      if immediately
        connection.close { EM.stop }
      else
        EM.add_timer(1) { connection.close { EM.stop } }
      end
    end
  end
end
