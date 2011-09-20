# -*- encoding: utf-8 -*-
module Smith
  class AgentMonitoring

    include Logger

    def initialize(agent_processes)
      @agent_processes = agent_processes
    end

    def start_monitoring
      EventMachine::add_periodic_timer(1) do
        @agent_processes.each do |agent_process|
          if agent_process.monitor
            logger.verbose("Agent state for #{agent_process.name}: #{agent_process.state}")
            case agent_process.state
            when 'running'
              if agent_process.last_keep_alive
                if agent_process.last_keep_alive > agent_process.started_at
                  if (Time.now.utc - agent_process.last_keep_alive) > 10
                    logger.fatal("Agent not responding: #{agent_process.name}")
                    agent_process.no_process_running
                  end
                else
                  logger.warn("Discarding keep_alives with timestamp before agent started: #{agent_process.started_at} > #{agent_process.last_keep_alive}")
                end
              end
            when 'starting'
              if (Time.now.utc - agent_process.started_at) > 10
                logger.error("No response from agent for > 10 seconds. Agent probably didn't start")
                agent_process.not_responding
              else
                logger.debug("no keep alive from #{agent_process.name}")
              end
            when 'stoping'
              logger.info("Agent is shutting down: #{agent_process.name}")
            when 'dead'
              logger.info("Restarting dead agent: #{agent_process.name}")
              Messaging::Sender.new('agency.control').publish(Messaging::Payload.new(:agency_command).content(:command => :start, :options => [agent_process.name]))
            when 'unknown'
              logger.info("Agent is in an unknown state: #{agent_process.name}")
            end
          end
        end
      end
    end
  end
end
