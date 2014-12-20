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
      @agent_name = name
      @agent_uuid = uuid
    end

    def signal_handlers
      logger.debug { "Installing default signal handlers" }
      %w{TERM INT QUIT}.each do |sig|
        @agent.install_signal_handler(sig) do |sig|
          logger.error { "Agent received: signal #{sig}: #{agent.name} (#{agent.uuid})" }
          terminate!
        end
      end
    end

    def load_agent
      path = agent_path(@agent_name)
      logger.debug { "Loading #{@agent_name} from: #{path.dirname}" }
      add_agent_load_path(path)
      load path

      begin
        @agent = class_from_name(@agent_name).new(@agent_uuid)
      rescue NameError => e
        # TODO: include the class name from the path.
        logger.fatal { "Cannot instantiate agent. The class name: #{@agent_name} probably didn't match the path" }
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
      Squash::Ruby.notify(exception) if exception && Smith.config.squash.enabled
      logger.error { format_exception(exception) } if exception
      logger.error { "Terminating: #{@agent_uuid}." }

      if Smith.running?
        send_dead_message
        unlink_pid_file
        Smith.stop
      else
        logger.debug { "Reconnecting to AMQP Broker." }
        Smith.start do
          send_dead_message
          unlink_pid_file
          Smith.stop
        end
      end
    end

    # Clean shutdown of the agent.
    def shutdown
      unlink_pid_file
      Smith.stop if Smith.running?
    end

    private

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

    def format_exception(exception)
      str = "#{exception.class.to_s}: #{exception.message}\n\t"
      if exception.backtrace
        str << exception.backtrace[0..-1].join("\n\t")
      end
      str
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
      path = path.dirname.dirname.join('lib')
      # The load path may be a pathname or a string. Change to strings.
      unless $:.detect { |p| p.to_s == path.to_s }
        logger.debug { "Adding #{path} to load path" }
        $: << path
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

# I've tried putting the exception handling in the main reactor log
# but it doesn't do anything. I know there's a reason for this but I
# don't what it is at the moment. Just beware that whenever there
# is an exception the reactor is not going going to be running.
begin
  Smith.start do
    if bootstrapper.load_agent
      bootstrapper.signal_handlers
      bootstrapper.start!
    end
  end
  bootstrapper.shutdown
rescue Exception => e
  bootstrapper.terminate!(e)
end
