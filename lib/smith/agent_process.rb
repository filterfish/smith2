# -*- encoding: utf-8 -*-
require 'state_machine'
require 'securerandom'
require 'forwardable'

require 'protobuf/message/enum'
require 'protobuf/message/message'

module Smith

  class AgentProcess

    include Logger
    extend Forwardable

    class AgentState < ::Protobuf::Message
      required :string,   :_state, 0
      required :string,   :path, 1
      required :string,   :name, 2
      required :string,   :uuid, 3
      optional :int32,    :pid, 4
      optional :int32,    :started_at, 5
      optional :int32,    :last_keep_alive, 6
      optional :string,   :metadata, 7
      optional :bool,     :monitor, 8
      optional :bool,     :singleton, 9
    end

    def_delegators :@agent_state, :path, :name, :uuid, :pid, :last_keep_alive, :metadata, :monitor, :singleton
    def_delegators :@agent_state, :path=, :name=, :uuid=, :pid=, :last_keep_alive=, :metadata=, :monitor=, :singleton=

    state_machine :initial => lambda {|o| o.send(:_state)}, :action => :save  do

      before_transition do |_, transition|
        puts { "Transition [#{name}]: :#{transition.from} -> :#{transition.to}" }
      end

      after_failure do |_, transition|
        puts { "Illegal state change [#{name}]: :#{transition.from} -> :#{transition.event}" }
      end

      event :instantiate do
        transition [:null] => :stopped
      end

      event :start do
        transition [:null, :stopped, :dead] => :starting
      end

      event :acknowledge_start do
        transition [:starting] => :running
      end

      event :stop do
        transition [:running, :unknown] => :stopping
      end

      event :acknowledge_stop do
        transition [:stopping] => :stopped
      end

      event :null do
        transition [:stopped] => :null
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
    def control_queue_name
      "agent.#{name.sub(/Agent$/, '').snake_case}.control"
    end

    def initialize(db, attributes={})
      @db = db
      if attributes.is_a?(String)
        @agent_state = AgentState.new.parse_from_string(attributes)
      else
        attr = attributes.merge(:_state => 'null', :uuid => SecureRandom.uuid)
        @agent_state = AgentState.new(attr)
        pp @agent_state
      end

      super()
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
      @db.put(name, @agent_state.to_s)
    end
  end

  module AgentProcessObserver

    include Logger

    # Start an agent. This forks and execs the bootstrapper class
    # which then becomes responsible for managing the agent process.
    def self.start(agent_process)
      agent_process.started_at = Time.now.to_i
      agent_process.pid = fork do

        # Detach from the controlling terminal
        unless Process.setsid
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
        STDERR.reopen(STDOUT)

        bootstrapper = File.expand_path(File.join(File.dirname(__FILE__), 'bootstrap.rb'))

        exec('ruby', bootstrapper, agent_process.path, agent_process.name, Smith.acl_cache_path.to_s)
      end

      # We don't want any zombies.
      Process.detach(agent_process.pid)
    end

    def self.acknowledge_start(agent_process)
      pp :acknowledge_start
    end

    def self.stop(agent_process)
      Messaging::Sender.new(agent_process.control_queue_name, :durable => false, :auto_delete => true) do |sender|
        sender.consumer_count do |count|
          if count > 0
            sender.publish(ACL::Factory.create(:agent_command, :command => 'stop'))
          else
            logger.warn { "Agent is not listening. Setting state to dead." }
            agent_process.no_process_running
          end
        end
      end
    end

    def self.acknowledge_stop(agent_process)
      pp :stopped
    end

    def self.kill(agent_process)
      if agent_process.pid
        logger.info { "Sending kill signal: #{agent_process.name}(#{agent_process.pid})" }
        begin
          Process.kill('TERM', agent_process.pid)
        rescue
          logger.error { "Process does not exist. PID is stale: #{agent_process.pid}: #{agent_process.name}" }
        end
      else
        logger.error { "Not sending kill signal, agent pid is not set: #{agent_process.name}" }
      end
    end

    # If an agent is in an unknown state then this will check to see
    # if the process is still alive and if it is kill it, otherwise
    # log a message. TODO this is not really a reaper but I haven't
    # quite worked out what I'm going to do with it so I'll leave it
    # as is
    def self.reap_agent(agent_process)
      logger.info { "Reaping agent: #{agent_process.name}" }
      if Pathname.new('/proc').join(agent_process.pid.to_s).exist?
        logger.warn { "Agent is still alive: #{agent_process.name}" }
      else
        logger.warn { "Agent is already dead: #{agent_process.name}" }
      end
    end
  end

  AgentProcess.state_machine do
    after_transition :on => :start, :do => AgentProcessObserver.method(:start)
    after_transition :on => :stop, :do => AgentProcessObserver.method(:stop)
    after_transition :on => :kill, :do => AgentProcessObserver.method(:kill)
    after_transition :on => :not_responding, :do => AgentProcessObserver.method(:reap_agent)
  end
end
