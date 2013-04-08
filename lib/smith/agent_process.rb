# -*- encoding: utf-8 -*-
require 'state_machine'
require 'forwardable'

require 'protobuf/message'

module Smith

  class AgentProcess

    include Smith::Logger
    extend Forwardable

    class AgentState < ::Protobuf::Message
      required ::Protobuf::Field::StringField,   :_state, 0
      required ::Protobuf::Field::StringField,   :name, 2
      required ::Protobuf::Field::StringField,   :uuid, 3
      optional ::Protobuf::Field::Int32Field,    :pid, 4
      optional ::Protobuf::Field::Int32Field,    :started_at, 5
      optional ::Protobuf::Field::Int32Field,    :last_keep_alive, 6
      optional ::Protobuf::Field::BoolField,     :singleton, 7
      optional ::Protobuf::Field::StringField,   :metadata, 8
      optional ::Protobuf::Field::BoolField,     :monitor, 9
    end

    def_delegators :@agent_state, :name, :uuid, :pid, :last_keep_alive, :metadata, :monitor, :singleton
    def_delegators :@agent_state, :name=, :uuid=, :pid=, :last_keep_alive=, :metadata=, :monitor=, :singleton=

    state_machine :initial => lambda {|o| o.send(:_state)}, :action => :save  do

      before_transition do |_, transition|
        logger.debug { "Transition [#{name}]: :#{transition.from} -> :#{transition.to}" }
      end

      after_failure do |_, transition|
        logger.debug { "Illegal state change [#{name}]: :#{transition.from} -> :#{transition.event}" }
      end

      event :start do
        transition [:null] => :checked
      end

      # I'm not terribly keen on this. On the one hand it means that the code
      # for checking the existance of the agent is contained here on the other
      # hand if the agent does not exist the state is checked which is not very
      # indicative that a failure has occurred! It does work but not very nice.
      # FIXME

      event :check do
        transition [:checked] => :starting
      end

      event :acknowledge_start do
        transition [:starting] => :running
      end

      event :stop do
        transition [:running, :unknown] => :stopping
      end

      event :acknowledge_stop do
        transition [:stopping] => :null
      end

      event :null do
        transition [:check, :stopped] => :null
      end

      event :no_process_running do
        transition [:unknown, :starting, :running, :stopping] => :dead
      end

      event :not_responding do
        transition [:starting, :acknowledge_start, :acknowledge_stop, :running, :stopping] => :unknown
      end

      event :kill do
        transition [:null, :unknown, :starting, :acknowledge_start, :stopping, :acknowledge_stop, :running, :dead] => :null
      end
    end

    def started_at
      Time.at(@agent_state.started_at)
    end

    def started_at=(time)
      @agent_state.started_at = time.to_i
    end

    def add_callback(state, &blk)
      AgentProcess.state_machine do
        puts "changing callback: :on => #{state}, :do => #{blk}"
        after_transition :on => state, :do => blk
      end
    end

    def delete
      @db.delete(@agent_state.uuid)
    end

    # Check to see if the agent is alive.
    def alive?
      if self.pid
        begin
          Process.kill(0, self.pid)
          true
        rescue Exception
          false
        end
      else
        false
      end
    end

    # Return the agent control queue.
    def control_queue_def
      QueueDefinitions::Agent_control.call(uuid)
    end

    def initialize(db, attributes={})
      @db = db
      if attributes.is_a?(String)
        @agent_state = AgentState.new.parse_from_string(attributes)
      else
        raise ArgumentError, "missing uuid option" if attributes[:uuid].nil?
        attr = attributes.merge(:_state => 'null')
        @agent_state = AgentState.new(attr)
      end

      super()
    end

    def exists?
      Smith.agent_paths.detect do |path|
        Pathname.new(path).join("#{name.snake_case}.rb").exist?
      end
    end

    def to_s
      @agent_state.to_hash.tap do |h|
        h[:state] = h.delete(:_state)
      end
    end

    private

    def _state
      @agent_state._state || "null"
    end

    def save
      @agent_state._state = state
      # TODO This *must* change to uuid when I've worked out how to manage them.
      @db.put(uuid, @agent_state.to_s)
    end
  end

  module AgentProcessObserver

    include Logger

    def self.start(agent_process)
      if agent_process.exists?
        agent_process.check
      else
        agent_process.delete
      end
    end

    # Start an agent. This forks and execs the bootstrapper class
    # which then becomes responsible for managing the agent process.
    def self.start_process(agent_process)
      fork do
        # Detach from the controlling terminal
        unless Process.setsid
          raise 'Cannot detach from controlling terminal'
        end

        # Close all file descriptors apart from stdin, stdout, stderr
        ObjectSpace.each_object(IO) do |io|
          unless [STDIN, STDOUT, STDERR].include?(io)
            io.close unless io.closed?
          end
        end

        # Sort out the remaining file descriptors. Don't do anything with
        # stdout (and by extension stderr) as want the agency to manage it.
        STDIN.reopen("/dev/null")
        STDERR.reopen(STDOUT)

        bootstrapper = Pathname.new(__FILE__).dirname.join('bootstrap.rb').expand_path

        binary = Smith.config.ruby[agent_process.name]
        logger.debug { "Launching #{agent_process.name} with: #{binary}" }
        exec(binary, bootstrapper.to_s, agent_process.name, agent_process.uuid)
      end

      # We don't want any zombies.
      Process.detach(agent_process.pid)
    end

    def self.acknowledge_start(agent_process, &blk)
      logger.info { "Agent started: #{agent_process.uuid}" }
    end

    def self.stop(agent_process)
      Messaging::Sender.new(agent_process.control_queue_def) do |sender|
        sender.consumer_count do |count|
          if count > 0
            sender.publish(ACL::AgentCommand.new(:command => 'stop'))
          else
            logger.warn { "Agent is not listening. Setting state to dead." }
            agent_process.no_process_running
          end
        end
      end
    end

    def self.no_process_running(agent_process)
      agent_process.delete
    end


    def self.acknowledge_stop(agent_process)
      agent_process.delete
      logger.info { "Agent stopped: #{agent_process.uuid}" }
    end

    # This needs to use the PID class to verify if an agent is still running.
    # FIXME
    def self.kill(agent_process)
      if agent_process.pid
        if agent_process.pid == 0
          logger.info { "Agent's pid is 0. The agent probably didn't start correctly. Cleaning up." }
          agent_process.delete
        else
          logger.info { "Sending kill signal: #{agent_process.pid}: #{agent_process.uuid}" }
          begin
            Process.kill('TERM', agent_process.pid)
          rescue
            logger.error { "Process does not exist. PID is stale: #{agent_process.pid}: #{agent_process.uuid}" }
          end
        end
      else
        logger.error { "Not sending kill signal, agent pid is not set: #{agent_process.uuid}" }
      end
      agent_process.delete
    end

    # If an agent is in an unknown state then this will check to see
    # if the process is still alive and if it is kill it, otherwise
    # log a message. TODO this is not really a reaper but I haven't
    # quite worked out what I'm going to do with it so I'll leave it
    # as is
    def self.reap_agent(agent_process)
      logger.info { "Reaping agent: #{agent_process.uuid}" }
      if Pathname.new('/proc').join(agent_process.pid.to_s).exist?
        logger.warn { "Agent is still alive: #{agent_process.uuid}" }
      else
        logger.warn { "Agent is already dead: #{agent_process.uuid}" }
      end
    end
  end

  AgentProcess.state_machine do |state_machine|
    # Make sure the state machine gets a logger.
    state_machine.class_eval { include Smith::Logger }

    after_transition :on => :start, :do => AgentProcessObserver.method(:start)
    after_transition :on => :check, :do => AgentProcessObserver.method(:start_process)
    after_transition :on => :stop, :do => AgentProcessObserver.method(:stop)
    after_transition :on => :kill, :do => AgentProcessObserver.method(:kill)
    after_transition :on => :not_responding, :do => AgentProcessObserver.method(:reap_agent)
    after_transition :on => :acknowledge_start, :do => AgentProcessObserver.method(:acknowledge_start)
    after_transition :on => :acknowledge_stop, :do => AgentProcessObserver.method(:acknowledge_stop)
    after_transition :on => :no_process_running, :do => AgentProcessObserver.method(:no_process_running)
  end
end
