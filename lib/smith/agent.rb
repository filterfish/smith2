# -*- encoding: utf-8 -*-
module Smith
  class Agent

    include Logger

    @@agent_options = Smith.config.agent

    attr_accessor :name

    def initialize(options={})
      @name = self.class.to_s
      @signal_handlers = Hash.new { |h,k| h[k] = Array.new }
      @queues = Cache.new
      @queues.operator ->(name, option=nil){(option == :sender) ? Messaging::Sender.new(name) : Messaging::Receiver.new(name)}

      setup_control_queue

      EM.threadpool_size = 1
    end

    def run
      raise ArgumentError, "You need to call Agent.task(&block)" if @@task.nil?

      default_queue.ready do |receiver|
        receiver.subscribe(:ack => false) do |metadata,payload|
          if @@threads
            EM.defer do
              @@task.call(payload)
            end
          else
            @@task.call(payload)
          end
        end
      end

      acknowledge_start
      start_keep_alive

      logger.info("Starting #{name}:[#{$$}]")
    end

    def listen(queue, options={}, &block)
      queues(queue, :receiver).ready do |receiver|
        receiver.subscribe(options) do |header,payload|
          block.call(header, payload)
        end
      end
    end

    def listen_and_reply(queue, options={}, &block)
      queues(queue, :receiver).ready do |receiver|
        receiver.subscribe_and_reply(options) do |metadata,payload,responder|
          block.call(metadata, payload, responder)
        end
      end
    end

    def install_signal_handler(signal, position=:end, &blk)
      raise ArgumentError, "Unknown position: #{position}" if ![:beginning, :end].include?(position)

      logger.debug("Installing signal handler for #{signal}")
      @signal_handlers[signal].insert((position == :beginning) ? 0 : -1, blk)
      @signal_handlers.each do |sig, handlers|
        trap(sig, proc { |sig| run_signal_handlers(sig, handlers) })
      end
    end

    class << self
      def task(opts={}, &blk)
        @@threads = opts[:threads] || false
        @@task = blk
      end

      # Options supported:
      # :monitor,   the agency will monitor the agent & if dies restart.
      # :singleton, only every have one agent. If this is set to false
      #             multiple agents are allow.
      def options(opts)
        opts.each { |k,v| merge_options(k, v) }
      end

      def merge_options(option, value)
        if @@agent_options[option]
          @@agent_options[option] = value
        else
          raise ArgumentError, "Unknown option: #{option}"
        end
      end
      private :merge_options
    end

    protected

    def run_signal_handlers(sig, handlers)
      logger.debug("Running signal handlers for agent: #{name}: #{sig}")
      handlers.each { |handler| handler.call(sig) }
    end

    def acknowledge_start
      message = {:state => 'acknowledge_start', :pid => $$.to_s, :name => self.class.to_s, :started_at => Time.now.utc.to_i.to_s}
      Messaging::Sender.new('agent.lifecycle').ready do |sender|
        sender.publish(Messaging::Payload.new(:agent_lifecycle).content(agent_options.merge(message)))
      end
    end

    def acknowledge_stop(&block)
      message = {:state => 'acknowledge_stop', :pid => $$.to_s, :name => self.class.to_s}
      Messaging::Sender.new('agent.lifecycle').ready do |sender|
        sender.publish(Messaging::Payload.new(:agent_lifecycle).content(message), :persistent => true, &block)
      end
    end

    def start_keep_alive
      if agent_options[:monitor]
        EventMachine::add_periodic_timer(1) do
          message = {:name => self.class.to_s, :pid => $$.to_s, :time => Time.now.utc.to_i.to_s}
          queues('agent.keepalive', :sender).ready do |sender|
            sender.consumers? do |sender|
              sender.publish(Messaging::Payload.new(:agent_keepalive).content(message), :durable => false)
            end
          end
        end
      else
        logger.info("Not initiating keep alive, agent is not being monitored: #{@name}")
      end
    end

    def setup_control_queue
      control_queue.ready do |receiver|
        receiver.subscribe do |header, payload|
          logger.debug("Command received on agent control queue: #{payload.command} #{payload.options}")

          case payload.command
          when 'stop'
            acknowledge_stop { Smith.stop }
          when 'log_level'
            begin
              level = payload.options.first
              logger.info("Setting log level to #{level} for: #{name}")
              log_level(level)
            rescue ArgumentError => e
              logger.error("Incorrect log level: #{level}")
            end
          else
            logger.warn("Unknown command: #{level} -> #{level.inspect}")
          end
        end
      end
    end

    def message_opts(options={})
      options.merge(@default_message_options)
    end

    def agent_options
      @@agent_options
    end

    def queues(queue_name, option=nil)
      @queues.entry(queue_name, option)
    end

    def default_queue
      # FIXME. This debug should go in the block.
      logger.debug("Setting up default queue: #{agent_queue_name}") unless @queues.exist?(agent_queue_name)
      queues(agent_queue_name, :receiver)
    end

    def control_queue
      # FIXME. This debug should go in the block.
      logger.debug("Setting up control queue: #{agent_control_queue_name}") unless @queues.exist?(agent_control_queue_name)
      queues(agent_control_queue_name, :receiver)
    end

    def agent_control_queue_name
      "#{agent_queue_name}.control"
    end

    def agent_queue_name
      "agent.#{name.sub(/Agent$/, '').snake_case}"
    end
  end
end
