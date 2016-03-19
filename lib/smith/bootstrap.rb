# -*- encoding: utf-8 -*-
#
# This should never be run directly it should only ever be run by
# the agency.

require 'pathname'
$:.unshift(Pathname.new(__FILE__).dirname.parent.expand_path)

require 'smith'
require 'smith/agent'

module Smith
  class AgentBootstrap

    attr_reader :agent

    include Logger
    include Utils

    def initialize(name, uuid)
      Dir.chdir('/')

      # FIXME
      # This doesn't do what I think it should. If an exception is
      # thrown in setup_control_queue, for example, it just kills
      # the agent without it actually raising the exception.
      Thread.abort_on_exception = true

      EventMachine.error_handler { |e| terminate!(e) }

      @agent_name = name
      @agent_uuid = uuid
    end

    def signal_handlers
      logger.debug { "Installing default signal handlers" }
      %w{TERM INT QUIT}.each do |sig|
        @agent.install_signal_handler(sig) do |sig|
          logger.error { "Received signal #{sig}: #{agent.name}, UUID: #{agent.uuid}, PID: #{agent.pid}." }

          terminate!
        end
      end
    end

    def load_agent
      path = agent_directories(@agent_name)
      logger.info { "Loading #{@agent_name}" }
      logger.debug { "Loading #{@agent_name} from: #{path}" }
      add_agent_load_path(path)
      load path

      begin
        @agent = class_from_name(@agent_name).new(@agent_uuid)
      rescue NameError => e
        # TODO: include the class name from the path.
        logger.fatal { "Cannot instantiate agent. File #{path} exists but doesn't contain the Class: #{@agent_name}." }
        terminate!
        false
      end
    end

    def start!
      write_pid_file
      @agent.run
    end

    # Exceptional shutdown of the agent. Note. Whenever this is
    # called it almost certain that the reactor is not going to
    # be running. So it must be restarted and then shutdown again
    # See the note at the in main.
    def terminate!(exception=nil)

      handle_excecption(exception)

      if Smith.running?
        send_dead_message
        shutdown
      else
        Smith.start do
          send_dead_message
          shutdown
        end
      end
    end

    # Cleanly shutdown of the agent.
    def shutdown
      unlink_pid_file
      Smith.stop if Smith.running?
    end

    private

    # FIXME This really should be using Smith::Daemon
    def write_pid_file
      @pid = Daemons::PidFile.new(Daemons::Pid.dir(:normal, Dir::tmpdir, nil), ".smith-#{@agent_uuid}", true)
      @pid.pid = Process.pid
    end

    def send_dead_message
      logger.debug { "Sending dead message to agency: #{@agent_name} (#{@agent_uuid})" }
      Messaging::Sender.new(QueueDefinitions::Agent_lifecycle) do |sender|
        sender.publish(ACL::AgentDead.new(:uuid => @agent_uuid))
      end
    end

    def unlink_pid_file
      if @pid && @pid.exist?
        logger.debug { "Cleaning up pid file: #{@pid.filename}" }
      end
    end

    # Format any excptions
    # @param e [Exception] the exeption to format
    # @return [String] formated exception
    def format_exception(e)
      "#{e.class.to_s}: #{e.inspect}\n\t".tap do |exception_string|
        exception_string << e.backtrace[0..-1].join("\n\t") if e.backtrace
      end
    end

    # Handle any exceptions. This will run the on_exception proc defined in the
    # agent and log the exception.
    #
    # @param e [Exception] the exeption to handle
    def handle_excecption(exception)
      if exception
        @agent.__send__(:__exception_handler, exception) if @agent
        logger.error { format_exception(exception) }
      end
      logger.error { "Terminating: #{@agent_name}, UUID: #{@agent_uuid}, PID: #{@pid.pid}." }
    end

    # Add the ../lib to the load path. This assumes the directory
    # structure is:
    #
    # $ROOT_PATH/agents
    #        .../lib
    #
    # where $ROOT_PATH can be anywhere.
    #
    # This needs to be better thought out.
    # TODO think this through some more.
    def add_agent_load_path(path)
      Smith.agent_directories.each do |path|
        lib_path = path.parent.join('lib')
        if lib_path.exist?
          logger.info { "Adding #{lib_path} to load path" }
          $LOAD_PATH << lib_path
        else
          logger.info { "No lib directory for: #{path.parent}." }
        end
      end
    end
  end
end

name = ARGV[0]
uuid = ARGV[1]

exit 1 if name.nil? || uuid.nil?

# Set the running instance name to the name of the agent.
$0 = "#{name}"

# Compile acls
Smith.compile_acls

bootstrapper = Smith::AgentBootstrap.new(name, uuid)

begin
  Smith.start do
    if bootstrapper.load_agent
      bootstrapper.signal_handlers
      bootstrapper.start!
    end
  end
rescue Exception => e
  bootstrapper.terminate!(e)
end
