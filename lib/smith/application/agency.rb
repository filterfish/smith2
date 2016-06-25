# -*- encoding: utf-8 -*-

require 'securerandom'
require 'daemons/pidfile'

require 'smith/command'
require 'smith/agent_process'
require 'smith/events/collector'

module Smith
  class Agency
    include Logger

    COLLECTOR_IDENTIFIER = :agency

    attr_reader :agents, :agent_processes

    def initialize
      @agent_processes = AgentCache.new
      @agency_stated_at = Time.now
      @agency_process_stats = Stats::Process.new

      @collector ||= Events::Collector.instance.tap do |c|
        c.register(COLLECTOR_IDENTIFIER) do |event|
          stats_queue.publish(event_acl(event))
        end
      end
    end

    def setup_queues
      Messaging::Receiver.new(QueueDefinitions::Agency_control.call, :auto_ack => false) do |receiver|
        receiver.subscribe do |payload, responder|
          completion = EM::Completion.new.tap do |c|
            c.completion do |value|
              responder.ack
              responder.reply(Smith::ACL::AgencyCommandResponse.new(:response => value))
            end
          end

          begin
            Command.run(payload.command, payload.args, :agency => self, :agents => @agent_processes, :responder => completion)
          rescue Command::UnknownCommandError
            responder.reply("Unknown command: #{payload.command}")
          end
        end
      end

      Messaging::Receiver.new(QueueDefinitions::Agent_lifecycle) do |queue|
        queue.subscribe do |payload|
          case payload
          when Smith::ACL::AgentDead
            dead(payload)
          when Smith::ACL::AgentAcknowledgeStart
            acknowledge_start(payload)
          when Smith::ACL::AgentAcknowledgeStop
            acknowledge_stop(payload)
          else
            logger.warn { "Unknown command received on #{QueueDefinitions::Agent_lifecycle.name} queue: #{payload.state}" }
          end
        end
      end

      Messaging::Receiver.new(QueueDefinitions::Agent_stats) do |queue|
        queue.subscribe(method(:agent_stats))
      end
    end

    # Stop the agency. This will wait for one second to ensure
    # that any messages are flushed.
    def stop(&blk)
      if blk
        Smith.stop(true, &blk)
      else
        Smith.stop(true)
      end
    end

    private

    def acknowledge_start(agent_data)
      agent_exists?(agent_data) do |agent_process|
        agent_process.pid = agent_data.pid
        agent_process.started_at = agent_data.started_at
        agent_process.singleton = agent_data.singleton
        agent_process.monitor = agent_data.monitor
        agent_process.metadata = agent_data.metadata
        agent_process.acknowledge_start
      end
    end

    def acknowledge_stop(agent_data)
      agent_exists?(agent_data, &:acknowledge_stop)
    end

    def dead(agent_data)
      agent_exists?(agent_data, &:no_process_running)
    end

    def agent_exists?(agent_data, error_proc=-> {}, &blk)
      agent = @agent_processes[agent_data.uuid]
      if agent
        blk.call(agent)
      else
        error_proc.call
      end
    end

    # Forwards all stats to a common queue. All agencies will send to the same
    # queue and will be collated.
    #
    # @param [Smith::ACL::AgentStats] payload ACL from the agent
    #
    def agent_stats(payload, _)
      if @agent_processes.exist?(payload.uuid)
        agent = @agent_processes[payload.uuid]
        logger.verbose { "Got stats from #{agent.name} [#{agent.uuid}]: #{payload.to_json}" }

        collector << ACL::Events::AgentStats.new do |s|
          s.uuid = payload.uuid
          s.timestamp = payload.timestamp
          s.queues = payload.queues

          process_stats = agent.process_stats
          s.process_stats = process_stats.to_acl
        end
      else
        logger.info { "Got stats from unknown agent: UUID: #{payload.uuid}. Discarding" }
      end
    end

    def agency_stats
      ACL::Events::AgencyStats.new do |m|
        s = @agency_process_stats.stats
        m.uuid = agency_uuid
        m.timestamp = Time.now.tv_sec
        m.host = Smith.hostname
        m.uptime = s.uptime
        m.process_stats = s.to_acl
      end
    end

    # Accessor for the events collector.
    #
    # @return [Smith::Events::Collector] the eventts collector
    def collector
      @collector
    end

    def event_acl(event)
      field_name = Utils.name_from_class(event, true).last.snake_case.to_sym
      ACL::Events::Event.new(:agency_stats => agency_stats, field_name => event)
    end

    def agency_uuid
      @eb24bc ||= SecureRandom.uuid
    end

    def stats_queue
      @bd8472 ||= Messaging::Sender.new(QueueDefinitions::Cluster_stats)
    end
  end
end
