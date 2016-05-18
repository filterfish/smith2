# -*- encoding: utf-8 -*-

require 'daemons/pidfile'

require 'smith/command'
require 'smith/agent_process'

module Smith
  class Agency

    include Logger

    attr_reader :agents, :agent_processes

    def initialize(opts={})
      @agent_processes = AgentCache.new
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
            Command.run(payload.command, payload.args, :agency => self,  :agents => @agent_processes, :responder => completion)
          rescue Command::UnknownCommandError => e
            responder.reply("Unknown command: #{payload.command}")
          end
        end
      end

      Messaging::Receiver.new(QueueDefinitions::Agent_lifecycle) do |receiver|
        receiver.subscribe do |payload, r|
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

      Messaging::Receiver.new(QueueDefinitions::Agent_keepalive) do |receiver|
        receiver.subscribe do |payload, r|
          keep_alive(payload)
        end
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
      agent_exists?(agent_data.uuid) do |agent_process|
        agent_process.pid = agent_data.pid
        agent_process.started_at = agent_data.started_at
        agent_process.singleton = agent_data.singleton
        agent_process.monitor = agent_data.monitor
        agent_process.metadata = agent_data.metadata
        agent_process.acknowledge_start
      end
    end

    def acknowledge_stop(agent_data)
      agent_exists?(agent_data.uuid) do |agent_process|
        agent_process.acknowledge_stop
      end
    end

    def dead(agent_data)
      agent_exists?(agent_data.uuid) do |agent_process|
        if agent_process.no_process_running
          logger.fatal { "Agent is dead: #{agent_process.name}, UUID: #{agent_process.uuid}, PID: #{agent_process.pid}" }
        end
      end
    end

    def agent_exists?(uuid, error_proc=->{}, &blk)
      agent = @agent_processes[uuid]
      if agent
        blk.call(agent)
      else
        error_proc.call
      end
    end
  end
end
