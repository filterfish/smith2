$:.unshift(File.dirname(__FILE__))

require 'pp'
require 'amqp'
require 'tmpdir'
require 'pathname'
require 'extlib/inflection'
require 'smith/logger'
require 'smith/cache'
require 'smith/agent'
require 'smith/agent_cache'
require 'smith/agent_process'
require 'smith/agent_monitoring'
require 'smith/messaging'
require 'daemons/pidfile_mp'

module Smith
  include Logger

  class << self

    def start(opts={}, &block)

      EM.epoll
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

    def stop
      EM.add_timer(1) {
        connection.close {
          EM.stop
        }
      }
    end
  end
end
