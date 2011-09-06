# -*- encoding: utf-8 -*-
require 'dm-core'

module Smith
  class Agency

    include Logger

    attr_reader :agents, :agent_processes

    def initialize(opts={})
      DataMapper.setup(:default, "yaml:///var/tmp/smith")

      @agent_processes = AgentCache.new(:path => opts.delete(:path))
    end

    def setup_queues
      Messaging::Receiver.new('agency.control').subscribe_and_reply do |header, payload|
        begin
          Command.run(payload[:command], payload[:args], :agency => self,  :agents => @agent_processes)
        rescue Command::UnkownCommandError => e
          logger.warn("Unknown command: #{payload[:command]}")
          "Command not known: #{payload[:command]}"
        end
      end

      Messaging::Receiver.new('agent.lifecycle').subscribe do |header, payload|
        pp payload
        case payload[:state]
        when :dead
          dead(payload[:data])
        when :acknowledge_start
          acknowledge_start(payload[:data])
        when :acknowledge_stop
          acknowledge_stop(payload[:data])
        else
          logger.warn("Unkown command received on agent.lifecycle queue")
        end
      end

      Messaging::Receiver.new('agent.keepalive').subscribe do |header, agent_data|
        keep_alive(agent_data)
      end
    end

    def start_monitoring
      @agent_monitor = AgentMonitoring.new(@agent_processes)
      @agent_monitor.start_monitoring
    end

    private

    def acknowledge_start(agent_data)
      @agent_processes[agent_data[:name]].tap do |agent_process|
        if agent_data[:pid] == agent_process.pid
          agent_process.monitor = agent_data[:monitor]
          agent_process.singleton = agent_data[:singleton]
          agent_process.acknowledge_start
        else
          logger.error("Agent reports different pid during acknowledge_start: #{agent_data[:name]}")
        end
      end
    end

    def acknowledge_stop(agent_data)
      @agent_processes[agent_data[:name]].tap do |agent_process|
        if agent_data[:pid] == agent_process.pid
          #delete_agent_process(agent_process.pid)
          agent_process.pid = nil
          agent_process.monitor = nil
          agent_process.singleton = nil
          agent_process.started_at = nil
          agent_process.last_keep_alive = nil
          agent_process.acknowledge_stop
        else
          if agent_process.pid
            logger.error("Agent reports different pid during acknowledge_stop: #{agent_data[:name]}")
          end
        end
      end
    end

    def keep_alive(agent_data)
      @agent_processes[agent_data[:name]].last_keep_alive = agent_data[:time]
      logger.verbose("Agent keep alive: #{agent_data[:name]}: #{agent_data[:time]}")
    end

    def dead(agent_data)
      @agent_processes[agent_data[:name]].no_process_running
      logger.fatal("Agent is dead: #{agent_data[:name]}")
    end

    # FIXME this doesn't work.
    def delete_agent_process(agent_pid)
      @agent_processes.invalidate(agent_pid)
      AgentProcess.first(:pid => agent_pid).destroy!
    end
  end
end
