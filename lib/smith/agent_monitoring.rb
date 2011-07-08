module Smith
  class AgentMonitoring

    include Logger

    def initialize(agent_processes)
      @verbose = false
      @agent_processes = agent_processes
    end

    def start_monitoring
      EventMachine::add_periodic_timer(1) do
        @agent_processes.each do |agent_process|
          if agent_process.running?
            if agent_process.last_keep_alive
              if agent_process.last_keep_alive > agent_process.started_at
                if (Time.now.utc - agent_process.last_keep_alive) > 10
                  logger.warn("#{agent_process.name} is not responding")
                  logger.info("Agent dead: #{agent_process.name}")
                  agent_process.no_process_running
                end
              else
                logger.warn("Discarding keep_alives with timestamp before agent started: #{agent_process.started_at} > #{agent_process.last_keep_alive}")
              end
            else
              if (Time.now.utc - agent_process.started_at) > 10
                logger.error("No response from agent for > 10 seconds. Agent probably didn't start")
              else
                logger.debug("no keep alive from #{agent_process.name}")
              end
            end
          end
        end
      end
    end

    def setup_agent_restart
      EventMachine::add_periodic_timer(1) do
        @agent_processes.each do |agent_process|
          if agent_process.dead?
            logger.info("Restarting agent: #{agent_process.name}")
            Smith::Messaging.new(:start).send_message(agent_process.name)
          end
        end
      end
    end

    def verbose=(flag)
      @verbose = flag
    end

    private

    def agent_process(agent_name)
      @agent_processes.entry(agent_name)
    end
  end
end
