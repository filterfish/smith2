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
        keep_alives(agent_data)
      end

      Smith::Messaging.new(:state).receive_message do |header, agent_name|
        logger.info("Agent state for #{agent_name}: #{(AgentState.first(:name => agent_name) || AgentState.new(:name => agent_name)).state}")
      end
    end

    private

    [:stop, :start].each do |event_name|
      define_method(event_name) do |agent_name|
        logger.debug("Received #{event_name} for #{agent_name}")
        as = AgentState.first(:name => agent_name) || AgentState.new(:name => agent_name)
        logger.debug("Changing to state: #{as.state}")
        logger.debug("Received state change: #{event_name}")
        if as.send(event_name)
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

      as = AgentState.first(:name => agent_name) || AgentState.new(:name => agent_name)
      if as.send(event_name)
        logger.info("#{Extlib::Inflection.humanize("#{event_name}ing")}: #{agent_name}")
      else
        logger.error("Cannot: #{event_name} when existing state is: #{as.state}")
      end
    end

    def acknowledge_start(agent_data)
      event_name = :acknowledge_start
      agent_name = agent_data['name']

      as = AgentState.first(:name => agent_name) || AgentState.new(:name => agent_name)
      if as.send(event_name)
        as.attributes = agent_data
        logger.info("#{Extlib::Inflection.humanize("#{event_name}ing")}: #{agent_name}")
      else
        logger.error("Cannot: #{event_name} when existing state is: #{as.state}")
      end
    end

    attr_reader :logger

    def keep_alives(agent)
      logger.debug("Agent keep alive: #{agent}")
    end

    def do_start(agent)

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

        exec('ruby', @bootstraper, @base_path, agent, @logging_path)
      end
      # We don't want any zombies.
      Process.detach(pid)
    end

    def do_stop(agent)
      Smith::Messaging.new("agent.#{agent.snake_case}").send_message("stop")
    end
  end
end
