# -*- encoding: utf-8 -*-
module Smith
  class Agent

    include Logger

    @@agent_options = Smith.config.agent

    attr_accessor :name

    def initialize(options={})
      @name = self.class.to_s
      @queues = Cache.new
      @queues.operator ->(name, option){(option == :sender) ? Messaging::Sender.new(name) : Messaging::Receiver.new(name)}

      setup_control_queue
      acknowledge_start
      start_keep_alive
    end

    def run
      raise ArgumentError, "You need to call Agent.task(&block)" if @@task.nil?

      EM.threadpool_size = 1
      default_queue.subscribe(:ack => false) do |metadata,payload|
        EM.defer do
          @@task.call(payload)
        end
      end

      logger.info("Starting #{name}:[#{$$}]")
    end

    def listen(queue, options={}, &block)
      queues(queue, :receiver).receive(options) do |header,payload|
        block.call(header, payload)
      end
    end

    class << self
      def task(&blk)
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

    private

    def acknowledge_start
      agent_data = agent_options.merge(:pid => $$, :name => self.class.to_s, :started_at => Time.now.utc)
      Messaging::Sender.new(:acknowledge_start).publish(agent_data)
    end

    def acknowledge_stop(&block)
      agent_data = {:pid => $$, :name => self.class.to_s}
      Messaging::Sender.new(:acknowledge_stop).publish(agent_data, {:persistent => true}, &block)
    end

    def start_keep_alive
      if agent_options[:monitor]
        send_keep_alive(queues(:keep_alive, :sender))
        EventMachine::add_periodic_timer(1) do
          send_keep_alive(queues(:keep_alive, :sender))
        end
      else
        logger.debug("Not initiating keep alive agent is not being monitored: #{@name}")
      end
    end

    def send_keep_alive(queue)
      queue.consumers? do |queue|
        queue.publish({:name => self.class.to_s, :time => Time.now.utc}, :durable => false)
      end
    end

    def setup_control_queue
      control_queue.subscribe do |header, payload|
        command = payload[:command]
        args = payload[:args]

        logger.debug("Command received on agent control queue: #{command} #{args}")

        case command
        when :stop
          acknowledge_stop { Smith.stop }
        when :log_level
          begin
            logger.info("Setting log level to #{args} for: #{name}")
            log_level(args)
          rescue ArgumentError => e
            logger.error("Incorrect log level: #{args}")
          end
        else
          logger.warn("Unknown command: #{command} -> #{args.inspect}")
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
      logger.debug("Setting up default queue: #{agent_queue_name}") unless @queues.exist?(agent_queue_name)
      queues(agent_queue_name, :receiver)
    end

    def control_queue
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
