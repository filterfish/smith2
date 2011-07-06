require 'pp'
require 'state_machine'
require 'dm-core'
require 'dm-yaml-adapter'
require 'smith/agent_state'

module Smith
  class Agency

    attr_reader :agents

    def initialize(opts={})
      @agent_processes = Cache.new
      @agent_processes.operator ->(agent_name){AgentProcess.first(:name => agent_name) || AgentProcess.new(:name => agent_name)}

      @verbose = false

      DataMapper.setup(:default, "yaml:///var/tmp/smith")

      @agent_monitor = AgentMonitoring.new(@agent_processes)
      @agent_monitor.start_monitoring
    end

    def setup_queues
      Smith::Messaging.new(:start).receive_message do |header, agent|
        start(agent)
      end

      Smith::Messaging.new(:acknowledge_start).receive_message do |header, agent_data|
        acknowledge_start(agent_data)
      end

      Smith::Messaging.new(:stop).receive_message do |header, agent|
        stop(agent)
      end

      Smith::Messaging.new(:acknowledge_stop).receive_message do |header, agent_data|
        acknowledge_stop(agent_data)
      end

      Smith::Messaging.new(:keep_alive).receive_message do |header, agent_data|
        do_keep_alive(agent_data)
      end

      # TODO do this properly.
      Smith::Messaging.new(:ageny_control).receive_message do |header, command|
        case command
        when 'verbose'
          @verbose = true
          @agent_monitor.verbose = true
        when 'normal'
          @verbose = false
        when 'stop'
          pp @agent_processes
          running_agents = @agent_processes.select {|a| a.state == :running }
          pp running_agents

          if running_agents.empty?
            Logger.info("Agency shutting down")
            Smith.stop
          else
            Logger.warn("Agents are still running: #{running_agents.join(", ")}") unless running_agents.empty?
            Logger.info("Agency not shutting down. Use force_stop if you really want to shut it down.")
          end
        when 'force_stop'
          Logger.info("Agency shutting down with predudice")
          Smith.stop
        else
          Logger.warn("Agency command unknown: #{command}")
        end
      end

      Smith::Messaging.new(:state).receive_message do |header, agent_name|
        Logger.info("Agent state for #{agent_name}: #{agent_process(agent_name).state}")
      end
    end

    private

    attr_reader :agent_states

    def start(agent_name)
      agent_process(agent_name).start
    end

    def stop(agent_name)
      agent_process(agent_name).stop
    end

    def acknowledge_start(agent_data)
      agent_process = agent_process(agent_data['name'])
      if agent_data['pid'] == agent_process.pid
        agent_process.acknowledge_start
      else
        Logger.error("Agent reports different pid during acknowledge_start: #{agent_data['name']}")
      end
    end

    def acknowledge_stop(agent_data)
      agent_process = agent_process(agent_data['name'])
      if agent_data['pid'] == agent_process.pid
        #delete_agent_process(agent_process.pid)
        agent_process.acknowledge_stop
      else
        if agent_process.pid
          Logger.error("Agent reports different pid during acknowledge_stop: #{agent_data['name']}")
        end
      end
    end

    def do_keep_alive(agent_data)
      agent_process(agent_data['name']).last_keep_alive = agent_data['time']
      Logger.debug("Agent keep alive: #{agent_data['name']}: #{agent_data['time']}") if @verbose
    end

    def agent_process(agent_name)
      @agent_processes.entry(agent_name)
    end

    # FIXME this doesn't work.
    def delete_agent_process(agent_pid)
      @agent_processes.invalidate(agent_pid)
      AgentProcess.first(:pid => agent_pid).destroy!
    end
  end
end
