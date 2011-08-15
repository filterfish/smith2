# This should never be run directly it should only be
# ever run by the agency.

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
      @agent_filename = File.expand_path(File.join(path, "#{agent_name.snake_case}.rb"))
    end

    def load_agent
      load @agent_filename
      @agent = Kernel.const_get(@agent_name).new
    end

    def start!
      write_pid_file
      @agent.run
    end

    # Exceptional shutdown of the agent.
    def terminate!(exception=nil)
      logger.error("Agent #{@agent_name} is dead.")
      logger.error(exception) if exception
      logger.debug("Sending dead message for #{@agent_name}")

      if Smith.running?
        send_dead_message
      else
        Smith.start do
          send_dead_message
        end
      end
      unlink_pid_file
      Smith.stop
    end

    # Clean shutdown of the agent.
    def shutdown
      logger.debug("Agent stopped: #{@agent_name}")
      unlink_pid_file
      Smith.stop if Smith.running?
    end

    private

    def write_pid_file
      @pid = Daemons::PidFile.new(Daemons::Pid.dir(:normal, Dir::tmpdir, nil), ".rubymas-#{@agent_name.snake_case}", true)
      @pid.pid = Process.pid
    end

    def send_dead_message
      Messaging.new(:dead).send_message(:name => @agent_name)
    end

    def unlink_pid_file
      @pid.cleanup if @pid
    end
  end
end

path = ARGV[0]
agent_name = ARGV[1]

exit 1 if agent_name.nil? || path.nil?

# Set the running instance name to the name of the agent.
$0 = "#{agent_name}"

bootstrapper = Smith::AgentBootstrap.new(path, agent_name)

begin
  Smith.start do
    bootstrapper.load_agent

    %w{TERM INT QUIT}.each do |sig|
      trap sig, proc {
        logger.error("Agent received: #{sig} signal: #{bootstrapper.agent.name}")
        bootstrapper.terminate!
      }
    end

    bootstrapper.start!
  end

  bootstrapper.shutdown

rescue Exception => e
  bootstrapper.terminate!(e)
end
