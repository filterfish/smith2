# -*- encoding: utf-8 -*-

module Smith
  class Agent

    include Logger
    include Smith::ObjectCount

    attr_reader :name, :pid, :uuid

    def initialize(uuid)
      @name = self.class.to_s
      @pid = $$
      @uuid = uuid

      @factory = QueueFactory.new

      @signal_handlers = Hash.new { |h,k| h[k] = Array.new }

      setup_control_queue

      @start_time = Time.now

      @state = :starting

      @on_stopping = proc {|completion| completion.succeed }
      @on_starting = proc {|completion| completion.succeed }
      @on_running = proc {|completion| completion.succeed }

      @on_starting_completion = EM::Completion.new.tap do |c|
        c.completion do |completion|
          acknowledge_start do
            @on_running.call(@on_running_completion)
            logger.info { "Agent started: #{name}:[#{pid}]." }
          end
        end
      end

      @on_running_completion = EM::Completion.new.tap do |c|
        c.completion do |completion|
          start_keep_alive
          setup_stats_queue
          @state = :running
        end
      end

      @on_stopping_completion = EM::Completion.new.tap do |c|
        c.completion do |completion|
          acknowledge_stop do
            @state = :stopping
            Smith.stop do
              logger.info { "Agent stopped: #{name}:[#{pid}]." }
            end
          end
        end
      end

      EM.threadpool_size = 1

      @on_starting.call(@on_starting_completion)
    end

    def on_stopping(&blk)
      @on_stopping = blk
    end

    def on_running(&blk)
      @on_running = blk
    end

    # Override this method to implement your own agent.
    def run
      raise ArgumentError, "You must override this method"
    end

    def install_signal_handler(signal, position=:end, &blk)
      raise ArgumentError, "Unknown position: #{position}" if ![:beginning, :end].include?(position)

      logger.verbose { "Installing signal handler for #{signal}" }
      @signal_handlers[signal].insert((position == :beginning) ? 0 : -1, blk)
      @signal_handlers.each do |sig, handlers|
        trap(sig, proc { |sig| run_signal_handlers(sig, handlers) })
      end
    end

    def state
      @state
    end

    # Set convenience state methods.
    [:starting, :stopping, :running].each do |method|
      define_method("#{method}?", proc { state == method })
    end

    def receiver(queue_name, opts={}, &blk)
      queues.receiver(queue_name, opts, &blk)
    end

    def sender(queue_name, opts={}, &blk)
      queues.sender(queue_name, opts, &blk)
    end

    class << self
      # Options supported:
      # :monitor,   the agency will monitor the agent & if dies restart.
      # :singleton, only every have one agent. If this is set to false
      #             multiple agents are allowed.
      def options(opts)
        opts.each do |k, v|
          Smith.config.agent.send("#{k}=", v)
        end
      end
    end

    protected

    def run_signal_handlers(sig, handlers)
      logger.debug { "Running signal handlers for agent: #{name}: #{sig}" }
      handlers.each { |handler| handler.call(sig) }
    end

    def setup_control_queue
      logger.debug { "Setting up control queue: #{control_queue_name}" }

      Messaging::Receiver.new(control_queue_name, :durable => false, :auto_delete => true) do |receiver|
        receiver.subscribe do |payload|
          logger.debug { "Command received on agent control queue: #{payload.command} #{payload.options}" }

          case payload.command
          when 'object_count'
            object_count(payload.options.first.to_i).each{|o| logger.info{o}}
          when 'stop'
            @on_stopping.call(@on_stopping_completion)
          when 'log_level'
            begin
              level = payload.options.first
              logger.info { "Setting log level to #{level} for: #{name} (#{uuid})" }
              log_level(level)
            rescue ArgumentError => e
              logger.error { "Incorrect log level: #{level}" }
            end
          else
            logger.warn { "Unknown command: #{level} -> #{level.inspect}" }
          end
        end
      end
    end

    def setup_stats_queue
      # instantiate this queue without using the factory so it doesn't show
      # up in the stats.
      Messaging::Sender.new('agent.stats', :dont_cache => true, :durable => false, :auto_delete => false) do |stats_queue|
        EventMachine.add_periodic_timer(2) do
          stats_queue.number_of_consumers do |consumers|
            if consumers > 0
              payload = ACL::Factory.create(:agent_stats) do |p|
                p.uuid = uuid
                p.agent_name = self.name
                p.pid = self.pid
                p.rss = (File.read("/proc/#{pid}/statm").split[1].to_i * 4) / 1024 # This assumes the page size is 4K & is MB
                p.up_time = (Time.now - @start_time).to_i
                queues.each_queue do |q|
                  p.queues << ACL::Factory.create('agent_stats::queue_stats', :name => q.denormalised_queue_name, :type => q.class.to_s, :length => q.counter)
                end
              end

              stats_queue.publish(payload)
            end
          end
        end
      end
    end

    def acknowledge_start(&blk)
      Messaging::Sender.new('agent.lifecycle', :auto_delete => false, :durable => false) do |queue|
        payload = ACL::Factory.create(:agent_acknowledge_start) do |p|
          p.uuid = uuid
          p.pid = $$
          p.singleton = Smith.config.agent.singleton
          p.started_at = Time.now.to_i
          p.metadata = Smith.config.agent.metadata
          p.monitor = Smith.config.agent.monitor
        end
        queue.publish(payload)
      end
    end

    def acknowledge_stop(&blk)
      Messaging::Sender.new('agent.lifecycle', :auto_delete => false, :durable => false) do |queue|
        message = {:state => 'acknowledge_stop', :pid => $$, :name => self.class.to_s}
        queue.publish(ACL::Factory.create(:agent_acknowledge_stop, :uuid => uuid), &blk)
      end
    end

    def start_keep_alive
      if Smith.config.agent.monitor
        EventMachine::add_periodic_timer(1) do
          Messaging::Sender.new('agent.keepalive', :auto_delete => false, :durable => false) do |queue|
            message = {:name => self.class.to_s, :uuid => uuid, :time => Time.now.to_i}
            queue.consumers do |consumers|
              if consumers > 0
                queue.publish(ACL::Factory.create(:agent_keepalive, message))
              end
            end
          end
        end
      else
        logger.info { "Not initiating keep alive, agent is not being monitored: #{@name}" }
      end
    end

    def queues
      @factory
    end

    def control_queue_name
      "agent.control.#{uuid}"
    end
  end
end
