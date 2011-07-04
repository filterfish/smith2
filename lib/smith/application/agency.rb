require 'pp'
require 'state_machine'
require 'dm-core'
require 'dm-yaml-adapter'
require 'smith/agent_state'

module Smith
  class Agency

    attr_reader :agents

    def initialize(opts={})
      @logger = opts[:logger] || Logging.logger(STDOUT)
      @base_path = opts[:agents_path] or raise ArgumentError, "no agents path supplied"
      @bootstraper = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bootstrap.rb'))
      @logging_path = opts[:logging] || ''

      @agent_states = Cache.new
      @agent_states.operator ->(agent_name){AgentState.first(:name => agent_name) || AgentState.new(:name => agent_name)}

      @verbose = false

      DataMapper.setup(:default, "yaml:///var/tmp/smith" )
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

      Smith::Messaging.new(:verbose).receive_message do |header, verbose|
        @verbose = (verbose == "true") ? true : false
      end

      Smith::Messaging.new(:state).receive_message do |header, agent_name|
        logger.info("Agent state for #{agent_name}: #{agent_state(agent_name).state}")
      end
    end

    def setup_monitoring
      EventMachine::add_periodic_timer(1) do
        agent_states.each do |agent_state|
          if agent_state.running?
            if agent_state.last_keep_alive
              if (Time.now.utc - agent_state.last_keep_alive) > 10
                logger.warn("#{agent_state.name} is not responding")
                logger.info("Agent dead: #{agent_state.name}")
                agent_state.no_process_running
              else
                logger.debug("#{agent_state.name} responding") if @verbose
              end
            else
              logger.debug("no keep alive from #{agent_state.name}")
            end
          end
        end
      end
    end

    def setup_agent_restart
      EventMachine::add_periodic_timer(1) do
        agent_states.each do |agent_state|
          if agent_state.dead?
            logger.info("Restarting agent: #{agent_state.name}")
            Smith::Messaging.new(:start).send_message(agent_state.name)
          end
        end
      end
    end

    private

    [:stop, :start].each do |event_name|
      define_method(event_name) do |agent_name|
        logger.debug("Received #{event_name} for #{agent_name}")
        as = agent_state(agent_name)
        logger.debug("Changing to state: #{as.state}")
        logger.debug("Received state change: #{event_name}")
        if as.send(event_name)
          if event_name == :stop
            as.pid = nil
            as.last_keep_alive = nil
          end
          logger.debug("Current state: #{as.state}")
          logger.info("#{Extlib::Inflection.humanize("#{event_name}ing")} #{agent_name}")
          self.send("do_#{event_name}", agent_name)
        else
          logger.error("Cannot change state to #{event_name} when existing state is: #{as.state}")
        end
      end
    end

    def acknowledge_stop(agent_data)
      event_name = :acknowledge_stop
      agent_name = agent_data['name']

      as = agent_state(agent_name)
      as.attributes = {:pid => nil, :last_keep_alive => nil, :started_at => nil}
      if as.send(event_name)
        logger.info("#{Extlib::Inflection.humanize("#{event_name}ing")}: #{agent_name}")
      else
        logger.error("Cannot: #{event_name} when existing state is: #{as.state}")
      end
    end

    def acknowledge_start(agent_data)
      event_name = :acknowledge_start
      agent_name = agent_data['name']

      as = agent_state(agent_name)
      as.attributes = agent_data
      if as.send(event_name)
        logger.info("#{Extlib::Inflection.humanize("#{event_name}ing")}: #{agent_name}")
      else
        logger.error("Cannot: #{event_name} when existing state is: #{as.state}")
      end
    end

    attr_reader :logger, :agent_states

    def do_keep_alive(agent_data)
      agent_state(agent_data['name']).last_keep_alive = agent_data['time']
      logger.debug("Agent keep alive: #{agent_data['name']}: #{agent_data['time']}") if @verbose
    end

    def do_start(agent_name)
      start_agent(agent_name)
      EventMachine::add_timer(10) do
        pp agent_state(agent_name).state
        unless agent_state(agent_name).running?
          logger.error("Agent didn't start: #{agent_name}")
          agent_state(agent_name).no_process_running
        else
          logger.debug("The agent started properly: #{agent_name}")
        end
      end
    end

    def start_agent(agent_name)
      pid = fork do
        # Detach from the controlling terminal
        unless sess_id = Process.setsid
          raise 'Cannot detach from controlling terminal'
        end

        # Close all file descriptors apart from stdin, stdout, stderr
        ObjectSpace.each_object(IO) do |io|
          unless [STDIN, STDOUT, STDERR].include?(io)
            io.close rescue nil
          end
        end

        # Sort out the remaining file descriptors. Don't do anything with
        # stdout (and by extension stderr) as want the agency to manage it.
        STDIN.reopen("/dev/null")
        STDERR.reopen("/dev/null")
        STDERR.reopen(STDOUT)

        exec('ruby', @bootstraper, @base_path, agent_name, @logging_path)
      end
      # We don't want any zombies.
      Process.detach(pid)
    end

    def do_stop(agent_name)
      Smith::Messaging.new("agent.#{agent_name.snake_case}").send_message("stop")
    end

    def agent_state(agent_name)
      @agent_states.entry(agent_name)
    end
  end
end
