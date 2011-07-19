require 'pp'
require 'state_machine'
require 'dm-core'
require 'dm-yaml-adapter'

module Smith
  class Agency

    include Logger

    attr_reader :agents

    def initialize(opts={})
      @agent_processes = AgentCache.new(:path => opts.delete(:path))
      @verbose = false

      DataMapper.setup(:default, "yaml:///var/tmp/smith")
    end

    def setup_queues
      Smith::Messaging.new(:start).receive_message do |header, agent|
        start(agent)
      end

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

      # TODO do this properly.
      # TODO check the command and arguments. Maybe use json schema.
      Smith::Messaging.new(:ageny_control).receive_message do |header, payload|
        command = payload['command']
        args = payload['args']
        logger.debug("Agency command: #{command}#{(args.empty?) ? '' : " #{args.join(', ')}"}.")

        case command
        when 'agents'
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
        when 'list'
          agents = @agent_processes.names
          if agents.empty?
            logger.info("No agents running.")
          else
            logger.info("Agents running: #{agents.sort.join(', ')}.")
          end
        when 'kill'
          args.each { |agent_name| kill(agent_name) }
        when 'log-level'
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
        when 'start'
          args.each { |agent_name| start(agent_name) }
        when 'state'
          args.inject([]) do |acc,agent_name|
            states = acc.tap do |a|
              a << @agent_processes[agent_name].state
            end
            logger.info("Agent state for #{agent_name}: #{@agent_processes[agent_name].state}.")
          end
        when 'stop'
          if args.first == 'all'
            @agent_processes.each { |agent_process| stop(agent_name) }
          else
            args.each { |agent_name| stop(agent_name) }
          end
        when 'verbose'
          @verbose = true
          @agent_monitor.verbose = true
        when 'normal'
          @verbose = false
          @agent_monitor.verbose = false
        when 'stop_agency'
          running_agents = @agent_processes.state(:running)

          if running_agents.empty?
            logger.info("Agency shutting down.")
            Smith.stop
          else
            logger.warn("Agents are still running: #{running_agents.join(", ")}.") unless running_agents.empty?
            logger.info("Agency not shutting down. Use force_stop if you really want to shut it down.")
          end
        when 'force_stop'
          logger.info("Agency shutting down with prejudice.")
          Smith.stop
        else
          logger.warn("Agency command unknown: #{command}.")
        end
      end
    end

    def start_monitoring
      @agent_monitor = AgentMonitoring.new(@agent_processes)
      @agent_monitor.start_monitoring
    end

    private

    attr_reader :agent_states

    def start(agent_name)
      @agent_processes[agent_name].tap do |agent_process|
        agent_process.name = agent_name
        agent_process.start
      end
    end

    def kill(agent_name)
      @agent_processes[agent_name].tap do |agent_process|
        agent_process.kill
      end
    end

    def stop(agent_name)
      @agent_processes[agent_name].tap do |agent_process|
        agent_process.stop
      end
    end

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
