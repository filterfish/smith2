require 'dm-core'

module Smith
  class Agency

    include Logger

    attr_reader :agents, :agent_processes

    def initialize(opts={})
      @agent_processes = AgentCache.new(:path => opts.delete(:path))
      @verbose = false
      @command_processor = AgencyCommandProcessor.new(self)

      DataMapper.setup(:default, "yaml:///var/tmp/smith")
    end

    def setup_queues
      Smith::Messaging.new(:acknowledge_start).receive_message do |header, agent_data|
        acknowledge_start(agent_data)
      end

      Smith::Messaging.new(:acknowledge_stop).receive_message do |header, agent_data|
        acknowledge_stop(agent_data)
      end

      Smith::Messaging.new(:dead).receive_message do |header, agent_data|
        dead(agent_data)
      end

      Smith::Messaging.new(:keep_alive).receive_message do |header, agent_data|
        keep_alive(agent_data)
      end

      Smith::Messaging.new(:ageny_control).receive_message do |header, payload|
        command = payload['command']
        args = payload['args']
        logger.debug("Agency command: #{command}#{(args.empty?) ? '' : " #{args.join(', ')}"}.")
        @command_processor.send(payload['command'], payload['args'])
      end
    end

    def start_monitoring
      @agent_monitor = AgentMonitoring.new(@agent_processes)
      @agent_monitor.start_monitoring
    end

    def verbose=(vebosity)
      @verbose = vebosity
      @agent_monitor.verbose = vebosity
    end

    private

    def acknowledge_start(agent_data)
      @agent_processes[agent_data['name']].tap do |agent_process|
        if agent_data['pid'] == agent_process.pid
          agent_process.monitor = agent_data['monitor']
          agent_process.singleton = agent_data['singleton']
          agent_process.acknowledge_start
        else
          logger.error("Agent reports different pid during acknowledge_start: #{agent_data['name']}")
        end
      end
    end

    def acknowledge_stop(agent_data)
      @agent_processes[agent_data['name']].tap do |agent_process|
        if agent_data['pid'] == agent_process.pid
          #delete_agent_process(agent_process.pid)
          agent_process.pid = nil
          agent_process.monitor = nil
          agent_process.singleton = nil
          agent_process.started_at = nil
          agent_process.last_keep_alive = nil
          agent_process.acknowledge_stop
        else
          if agent_process.pid
            logger.error("Agent reports different pid during acknowledge_stop: #{agent_data['name']}")
          end
        end
      end
    end

    def keep_alive(agent_data)
      @agent_processes[agent_data['name']].last_keep_alive = agent_data['time']
      logger.debug("Agent keep alive: #{agent_data['name']}: #{agent_data['time']}") if @verbose
    end

    def dead(agent_data)
      @agent_processes[agent_data['name']].no_process_running
      logger.debug("Agent is dead: #{agent_data['name']}")
    end

    # FIXME this doesn't work.
    def delete_agent_process(agent_pid)
      @agent_processes.invalidate(agent_pid)
      AgentProcess.first(:pid => agent_pid).destroy!
    end
  end
end
