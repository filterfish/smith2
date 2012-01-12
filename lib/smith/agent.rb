# -*- encoding: utf-8 -*-

module Smith
  class Agent

    include Logger

    @@agent_options = Smith.config.agent

    attr_reader :factory, :name, :pid

    def initialize(options={})
      @name = self.class.to_s
      @pid = $$

      @factory = QueueFactory.new

      @signal_handlers = Hash.new { |h,k| h[k] = Array.new }

      setup_control_queue
      setup_stats_queue

      @start_time = Time.now

      EM.threadpool_size = 1

      acknowledge_start
      start_keep_alive

      logger.info("Starting #{name}:[#{pid}]")
    end

    def run
      raise ArgumentError, "You need to call Agent.task(&block)" if @@task.nil?

      logger.debug("Setting up default queue: #{default_queue_name}")

      subscribe(default_queue_name, :auto_delete => false) do |r|
        @@task.call(r.payload)
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

    def receiver(queue_name, opts={})
      queues.receiver(queue_name, opts) do |receiver|
        receiver.subscribe do |r|
          yield r
        end
      end
    end

    def sender(queue_name, opts={})
      queues.sender(queue_name, opts) { |sender| yield sender }
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
      logger.debug("Setting up control queue: #{control_queue_name}")
      receiver(control_queue_name, :auto_delete => true, :durable => false) do |r|
        logger.debug("Command received on agent control queue: #{r.payload.command} #{r.payload.options}")

        case r.payload.command
        when 'stop'
          acknowledge_stop { Smith.stop }
        when 'log_level'
          begin
            level = r.payload.options.first
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

    def setup_stats_queue
      # instantiate this queue without using the factory so it doesn't show
      # up in the stats.
      sender('agent.stats', :dont_cache => true, :durable => false, :auto_delete => false) do |stats_queue|
        EventMachine.add_periodic_timer(2) do
          callback = proc do |consumers|
            payload = ACL::Payload.new(:agent_stats).content do |p|
              p.agent_name = self.name
              p.pid = self.pid
              p.rss = (File.read("/proc/#{pid}/statm").split[1].to_i * 4) / 1024 # This assums the page size is 4K & is MB
              p.up_time = (Time.now - @start_time).to_i
              factory.each_queue do |q|
                p.queues << ACL::AgentStats::QueueStats.new(:name => q.denomalized_queue_name, :type => q.class.to_s, :length => q.counter)
              end
            end

            stats_queue.publish(payload)
          end

          # The errback argument is set to nil so as to suppres the default message.
          stats_queue.consumers?(callback, nil)
        end
      end
    end

    def acknowledge_start
      sender('agent.lifecycle', :auto_delete => true, :durable => false, :dont_cache => true) do |ack_start_queue|
        message = {:state => 'acknowledge_start', :pid => $$.to_s, :name => self.class.to_s, :started_at => Time.now.utc.to_i.to_s}
        ack_start_queue.publish(ACL::Payload.new(:agent_lifecycle).content(agent_options.merge(message)))
      end
    end

    def acknowledge_stop(&block)
      sender('agent.lifecycle', :auto_delete => true, :durable => false, :dont_cache => true) do |ack_stop_queue|
        message = {:state => 'acknowledge_stop', :pid => $$.to_s, :name => self.class.to_s}
        ack_stop_queue.publish(ACL::Payload.new(:agent_lifecycle).content(message), &block)
      end
    end

    def start_keep_alive
      if agent_options[:monitor]
        EventMachine::add_periodic_timer(1) do
          sender('agent.keepalive', :auto_delete => true, :durable => false, :dont_cache => true) do |keep_alive_queue|
            message = {:name => self.class.to_s, :pid => $$.to_s, :time => Time.now.utc.to_i.to_s}
            keep_alive_queue.consumers? do |sender|
              keep_alive_queue.publish(ACL::Payload.new(:agent_keepalive).content(message))
            end
          end
        end
      else
        logger.info("Not initiating keep alive, agent is not being monitored: #{@name}")
      end
    end

    def queues
      @factory
    end

    def agent_options
      @@agent_options._child
    end

    def control_queue_name
      "#{default_queue_name}.control"
    end

    def default_queue_name
      "agent.#{name.sub(/Agent$/, '').snake_case}"
    end
  end
end
