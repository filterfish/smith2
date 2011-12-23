# -*- encoding: utf-8 -*-

module Smith
  class Agent

    include Logger

    @@agent_options = Smith.config.agent

    attr_reader :name, :pid

    def initialize(options={})
      @name = self.class.to_s
      @pid = $$

      @signal_handlers = Hash.new { |h,k| h[k] = Array.new }
      @queues = Cache.new
      @queues.operator ->(name, options={}) {
        type = options.delete(:type) || :sender # Default to creating a Sender.
        (type == :sender) ? Messaging::Sender.new(name, options) : Messaging::Receiver.new(name, options)
      }

      setup_control_queue
      #setup_stats

      @start_time = Time.now

      EM.threadpool_size = 1
    end

    def run
      raise ArgumentError, "You need to call Agent.task(&block)" if @@task.nil?

      logger.debug("Setting up default queue: #{agent_queue_name}")
      default_queue(:auto_delete => false).ready do |receiver|
        receiver.subscribe do |metadata,payload,responder|
          @@task.call(payload, responder)
        end
      end

      acknowledge_start
      start_keep_alive

      logger.info("Starting #{name}:[#{pid}]")
    end

    def subscribe(queue, options={}, &block)
      threading = options.delete(:threading)
      queue(queue, :type => :receiver, :threading => threading, :auto_delete => false).ready do |receiver|
        logger.debug("Queue handler for #{queue} is #{(receiver.threading) ? "using" : "not using"} threads.")
        receiver.subscribe(options) do |header,payload,responder|
          block.call(header, payload, responder)
        end
      end
    end

    def subscribe_and_reply(queue, options={}, &block)
      threading = options.delete(:threading)
      queue(queue, :type => :receiver, :threading => threading, :auto_delete => false).ready do |receiver|
        logger.debug("Queue handler for #{queue} is #{(receiver.threading) ? "using" : "not using"} threads.")
        receiver.subscribe_and_reply(options) do |metadata,payload,responder|
          block.call(metadata, payload, responder)
        end
      end
    end

    def publish(queue, payload, opts={}, &block)
      queue(queue, :type => :sender, :auto_delete => false).ready do |sender|
        sender.publish(payload, opts)
      end
    end

    def publish_and_receive(queue, opts={}, payload, &block)
      queue(queue, :type => :sender, :auto_delete => false).ready do |sender|
        sender.publish_and_receive(payload, {:persistent => true, :nowait => false}.merge(opts)) do |metadata,payload|
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
        # TODO is this neeeded? I think not.
        @@threading = opts[:threading] || false
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

    def setup_control_queue
      logger.debug("Setting up control queue: #{agent_control_queue_name}")
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

    def setup_stats_queue
      Messaging::Sender.new('agent.stats').ready do |sender|
        EventMachine.add_timer(2) do
          sender.consumers? do |consumers|
            if consumers > 0
              payload = ACL::Payload.new(:agent_stats) do |p|
                p.pid = self.pid
                p.rss = (File.read("/proc/#{pid}/statm").split[1].to_i * 4) / 1024 # This assums the page size is 4K & is MB
                p.up_time = (Time.now - @start_time).to_i
              end

              sender.publish(payload)
            end
          end
        end
      end
    end

    def acknowledge_start
      message = {:state => 'acknowledge_start', :pid => $$.to_s, :name => self.class.to_s, :started_at => Time.now.utc.to_i.to_s}
      Messaging::Sender.new('agent.lifecycle').ready do |sender|
        sender.publish(ACL::Payload.new(:agent_lifecycle).content(agent_options.merge(message)))
      end
    end

    def acknowledge_stop(&block)
      message = {:state => 'acknowledge_stop', :pid => $$.to_s, :name => self.class.to_s}
      Messaging::Sender.new('agent.lifecycle').ready do |sender|
        sender.publish(ACL::Payload.new(:agent_lifecycle).content(message), :persistent => true, &block)
      end
    end

    def start_keep_alive
      if agent_options[:monitor]
        EventMachine::add_periodic_timer(1) do
          message = {:name => self.class.to_s, :pid => $$.to_s, :time => Time.now.utc.to_i.to_s}
          queue('agent.keepalive', :type => :sender).ready do |sender|
            sender.consumers? do |sender|
              sender.publish(ACL::Payload.new(:agent_keepalive).content(message), :durable => false)
            end
          end
        end
      else
        logger.info("Not initiating keep alive, agent is not being monitored: #{@name}")
      end
    end

    def message_opts(options={})
      options.merge(@default_message_options)
    end

    def agent_options
      @@agent_options._child
    end

    def queues
      @queues
    end

    def queue(queue_name, options={})
      @queues.entry(queue_name, options)
    end

    def default_queue(options={})
      queue(agent_queue_name, {:type => :receiver}.merge(options))
    end

    def control_queue
      queue(agent_control_queue_name, :type => :receiver)
    end

    def agent_control_queue_name
      "#{agent_queue_name}.control"
    end

    def agent_queue_name
      "agent.#{name.sub(/Agent$/, '').snake_case}"
    end
  end
end
