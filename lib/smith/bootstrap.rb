# -*- encoding: utf-8 -*-
#
# This should never be run directly it should only ever be run by
# the agency.

$: << File.dirname(__FILE__) + '/..'

require 'smith'

module Smith
  class AgentBootstrap

    attr_reader :agent

    include Logger

    def initialize(path, agent_name)
      # FIXME
      # This doesn't do what I think it should. If an exception is
      # thrown in setup_control_queue, for example, it just kills
      # the agent without it actually raising the exception.
      Thread.abort_on_exception = true
      @agent_name = agent_name
      @agent_filename = Pathname.new(path).join("#{agent_name.snake_case}.rb").expand_path
    end

    def signal_handlers
      logger.debug { "Installing default signal handlers" }
      %w{TERM INT QUIT}.each do |sig|
        @agent.install_signal_handler(sig) do |sig|
          logger.error { "Agent received: signal #{sig}: #{agent.name}" }
          terminate!
        end
      end
    end

    def load_agent
      logger.debug { "Loading #{@agent_name} from: #{@agent_filename.dirname}" }
      add_agent_load_path
      load @agent_filename
      @agent = Kernel.const_get(@agent_name).new
    end

    def start!
      write_pid_file
      @agent.run
      @agent.started
    end

    # Exceptional shutdown of the agent. Note. Whenever this is
    # called it almost certain that the reactor is not going to
    # be running. So it must be restarted and then shutdown again
    # See the note at the in main.
    def terminate!(exception=nil)
      logger.error { format_exception(exception) } if exception
      logger.error { "Terminating: #{@agent_name}." }

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
      @pid = Daemons::PidFile.new(Daemons::Pid.dir(:normal, Dir::tmpdir, nil), ".rubymas-#{@agent_name.snake_case}", true)
      @pid.pid = Process.pid
    end

    def send_dead_message
      logger.debug { "Sending dead message to agency: #{@agent_name}" }
      Messaging::Sender.new('agent.lifecycle', :auto_delete => true, :durable => false).ready do |sender|
        sender.publish(ACL::Payload.new(:agent_lifecycle).content(:state => 'dead', :name => @agent_name))
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
    def add_agent_load_path
      path = @agent_filename.dirname.dirname.join('lib')
      # The load path may be a pathname or a string. Change to strings.
      unless $:.detect { |p| p.to_s == path.to_s }
        logger.debug { "Adding #{path} to load path" }
        $: << path
      end
    end
  end
end

path = ARGV[0]
agent_name = ARGV[1]

exit 1 if agent_name.nil? || path.nil?

# Set the running instance name to the name of the agent.
$0 = "#{agent_name}"

# load the acls
Smith.load_acls

bootstrapper = Smith::AgentBootstrap.new(path, agent_name)

# I've tried putting the exception handling in the main reactor log
# but it doesn't do anything. I know there's a reason for this but I
# don't what it is at the moment. Just beware that whenever there
# is an exception the reactor is not going going to be running.
begin
  Smith.start do
    bootstrapper.load_agent
    bootstrapper.signal_handlers
    bootstrapper.start!
  end
  bootstrapper.shutdown
rescue Exception => e
  bootstrapper.terminate!(e)
end
