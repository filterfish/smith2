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

      @signal_handler = SelfPipe.new(self)

      setup_control_queue

      @start_time = Time.now

      @state = :starting

      @on_stopping = proc { |completion| completion.succeed }
      @on_starting = proc { |completion| completion.succeed }
      @on_running = proc { |completion| completion.succeed }
      @on_exception = proc {}

      @on_starting_completion = EM::Completion.new.tap do |c|
        c.completion do |completion|
          acknowledge_start do
            @on_running.call(@on_running_completion)
            logger.info { "Agent started: #{name}, UUID: #{uuid}, PID: #{pid}" }
          end
        end
      end

      @on_running_completion = EM::Completion.new.tap do |c|
        c.completion do |completion|
          setup_stats_queue
          @state = :running
        end
      end

      @on_stopping_completion = EM::Completion.new.tap do |c|
        c.completion do |completion|
          acknowledge_stop do
            @state = :stopping
            Smith.stop
          end
        end
      end

      @on_starting.call(@on_starting_completion)
    end

    def on_stopping(&blk)
      @on_stopping = blk
    end

    def on_running(&blk)
      @on_running = blk
    end

    # The agent may hook into this if they want to do something on exception.
    # It should be noted that, since an exception has occured, the reactor will
    # not be running at this point. Even if we restarted the reactor before
    # calling this it would be a different reactor than existed when assigning
    # the block so this would potentially lead to confusion. If the agent
    # really needs the reactor to do something it can always restart the
    # reactor itself.
    #
    # @param blk [Block] This block will be passed the exception as an
    #   argument.
    def on_exception(&blk)
      @on_exception = blk
    end

    # Override this method to implement your own agent.
    def run
      raise ArgumentError, "You must override the run method"
    end

    def install_signal_handler(signal, position=:end, &blk)
      @signal_handler.install_signal_handler(signal, position=:end, &blk)
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

    def sender(queue_names, opts={}, &blk)
      Array(queue_names).each { |queue_name| queues.sender(queue_name, opts, &blk) }
    end

    class << self
      # Options supported:
      # :monitor,     the agency will monitor the agent & if dies restart.
      # :singleton,   only every have one agent. If this is set to false
      #               multiple agents are allowed.
      # :statistics,  sends queue details to the agency
      def options(opts)
        opts.each do |k, v|
          Smith.config.agent[k] = v
        end
      end
    end

    private

    def setup_control_queue
      logger.debug { "Setting up control queue: #{control_queue_def.denormalise}" }

      Messaging::Receiver.new(control_queue_def) do |receiver|
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
            rescue ArgumentError
              logger.error { "Incorrect log level: #{level}" }
            end
          else
            logger.warn { "Unknown command: #{level} -> #{level.inspect}" }
          end
        end
      end
    end

    def acknowledge_start(&blk)
      Messaging::Sender.new(QueueDefinitions::Agent_lifecycle) do |queue|
        queue.publish(acknowledge_start_acl, &blk)
      end
    end

    def acknowledge_stop(&blk)
      Messaging::Sender.new(QueueDefinitions::Agent_lifecycle) do |queue|
        queue.publish(acknowledge_stop_acl, &blk)
      end
    end

    def setup_stats_queue
      if Smith.config.agent.statistics
        Messaging::Sender.new(QueueDefinitions::Agent_stats) do |stats_queue|
          EventMachine.add_periodic_timer(2) do
            stats_queue.number_of_consumers do |consumers|
              if consumers > 0
                stats_queue.publish(agent_stats_acl)
              end
            end
          end
        end
      end
    end

    def queues
      @factory
    end

    def control_queue_def
      @control_queue_def ||= QueueDefinitions::Agent_control.call(uuid)
    end

    def __exception_handler(exception)
      @on_exception.call(exception)
    end

    def uptime
      (Time.now - @start_time).to_i
    end

    def acknowledge_stop_acl
      ACL::AgentAcknowledgeStop.new(:uuid => uuid)
    end

    def agent_stats_acl
      ACL::AgentStats.new do |p|
        p.timestamp = Time.now.tv_sec
        p.uuid = uuid
        p.uptime = uptime
        queues.each do |q|
          p.queues << ACL::QueueStats.new(:name => q.queue_name, :type => q.class.to_s, :count => q.counter)
        end
      end
    end

    def acknowledge_start_acl
      ACL::AgentAcknowledgeStart.new do |p|
        p.uuid = uuid
        p.pid = pid
        p.singleton = Smith.config.agent.singleton
        p.started_at = Time.now.to_i
        p.metadata = Smith.config.agent.metadata
        p.monitor = Smith.config.agent.monitor
      end
    end
  end
end
