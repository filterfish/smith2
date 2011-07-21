module Smith
  class AgencyCommandProcessor

    include Logger

    def initialize(agency)
      @agency = agency
      @agent_processes = agency.agent_processes
    end

    def agents(args)
      agents = Pathname.new(@agent_processes.path).each_child.inject([]) do |acc,agent_path|
        acc.tap do |a|
          unless agent_path.directory?
            a << Extlib::Inflection.camelize(agent_path.basename('.rb'))
          end
        end
      end
      if agents.empty?
        logger.info("No agents available.")
      else
        logger.info("Agents available: #{agents.sort.join(", ")}.")
      end
    end

    def list(args)
      agents = @agent_processes.state(:running).map(&:name)
      if agents.empty?
        logger.info("No agents running.")
      else
        logger.info("Agents running: #{agents.sort.join(', ')}.")
      end
    end

    def kill(args)
      args.each { |agent_name| _kill(agent_name) }
    end

    def log_level(args)
      log_level = args.shift
      agent_names = args
      case agent_names.first
      when 'all'
        @agent_processes.each { |agent_process| Smith::Messaging.new("agent.#{agent_process.private_queue_name}").send_message(:command => :log_level, :args => log_level) }
      when 'agency'
        logger.info("Setting agency log level to: #{log_level}")
        Logger.level log_level
      when nil
        logger.warn("No log level set. Not changing log level")
      else
        agent_names.each do |agent_name|
          agent_process = @agent_processes[agent_name]
          Smith::Messaging.new(agent_process.private_queue_name).send_message(:command => :log_level, :args => log_level)
        end
      end
    end

    def start(args)
      args.each { |agent_name| _start(agent_name) }
    end

    def state(args)
      args.inject([]) do |acc,agent_name|
        states = acc.tap do |a|
          a << @agent_processes[agent_name].state
        end
        logger.info("Agent state for #{agent_name}: #{@agent_processes[agent_name].state}.")
      end
    end

    def stop(args)
      case args.first
      when 'agency'
        running_agents = @agent_processes.state(:running)

        if running_agents.empty?
          logger.info("Agency shutting down.")
          Smith.stop
        else
          logger.warn("Agents are still running: #{running_agents.map(&:name).join(", ")}.") unless running_agents.empty?
          logger.info("Agency not shutting down. Use force_stop if you really want to shut it down.")
        end
      when 'all'
        @agent_processes.each { |agent_process| _stop(agent_name) }
      else
        args.each { |agent_name| _stop(agent_name) }
      end
    end

    def verbose(args)
      @agency.verbose = true
    end

    def normal(args)
      @agency.verbose = false
    end

    def force_stop(args)
      logger.info("Agency shutting down with prejudice.")
      Smith.stop
    end

    def method_missing(method)
      pp method
      logger.warn("Agency command unknown: #{method.to_s}.")
    end

    private

    def _start(agent_name)
      @agent_processes[agent_name].tap do |agent_process|
        agent_process.name = agent_name
        agent_process.start
      end
    end

    def _kill(agent_name)
      @agent_processes[agent_name].tap do |agent_process|
        agent_process.kill
      end
    end

    def _stop(agent_name)
      @agent_processes[agent_name].tap do |agent_process|
        agent_process.stop
      end
    end
  end
end
