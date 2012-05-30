# -*- encoding: utf-8 -*-
require 'pp'
require 'state_machine'
require 'dm-observer'

module Smith

  class AgentProcess

    include Logger
    include Extlib
    include DataMapper::Resource

    property :id,               Serial
    property :path,             String, :required => true
    property :name,             String, :required => true
    property :state,            String, :required => true
    property :pid,              Integer
    property :started_at,       Integer
    property :last_keep_alive,  Integer
    property :metadata,         String
    property :monitor,          Boolean
    property :singleton,        Boolean

    state_machine :initial => :null do

      before_transition do |transition|
        logger.debug { "Transition [#{name}]: :#{transition.from} -> :#{transition.to}" }
      end

      after_failure do |transition|
        logger.debug { "Illegal state change [#{name}]: :#{transition.from} -> :#{transition.event}" }
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

    # Check to see if the agent is alive.
    def alive?
      if self.pid
        begin
          Process.kill(0, self.pid.to_i)
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
  end

  class AgentProcessObserver

    include Logger
    include DataMapper::Observer

    observe AgentProcess

    # Start an agent. This forks and execs the bootstrapper class
    # which then becomes responsible for managing the agent process.
    def self.start(agent_process)
      agent_process.started_at = Time.now
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
      Process.detach(agent_process.pid.to_i)
    end

    def self.acknowledge_start(agent_process)
    end

    def self.stop(agent_process)
      Messaging::Sender.new(agent_process.control_queue_name, :durable => false, :auto_delete => true).ready do |sender|
        callback = proc {|sender| sender.publish(ACL::Payload.new(:agent_command).content(:command => 'stop')) }
        errback = proc do
          logger.warn { "Agent is not listening. Setting state to dead." }
          agent_process.no_process_running
        end

        sender.consumers?(callback, errback)
      end
    end

    def self.acknowledge_stop(agent_process)
    end

    def self.kill(agent_process)
      if agent_process.pid
        logger.info { "Sending kill signal: #{agent_process.name}(#{agent_process.pid})" }
        begin
          Process.kill('TERM', agent_process.pid.to_i)
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
    after_transition :on => :acknowledge_start, :do => AgentProcessObserver.method(:acknowledge_start)
    after_transition :on => :stop, :do => AgentProcessObserver.method(:stop)
    after_transition :on => :kill, :do => AgentProcessObserver.method(:kill)
    after_transition :on => :acknowledge_stop, :do => AgentProcessObserver.method(:acknowledge_stop)
    after_transition :on => :not_responding, :do => AgentProcessObserver.method(:reap_agent)
  end
end
