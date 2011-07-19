# This should never be run directly it should only be
# ever run by the agency.

$: << File.dirname(__FILE__) + '/..'

require 'smith'

module Smith
  class AgentBootstrap

    attr_reader :agent

    include Logger

    def initialize(path, agent_name)
      @agent_name = agent_name
      @agent_filename = File.expand_path(File.join(path, "#{agent_name.snake_case}.rb"))
    end

    def load_agent
      load @agent_filename
    end

    def run
      write_pid_file
      begin
        @agent = Kernel.const_get(@agent_name).new
        @agent.run
      rescue => e
        logger.error("Failed to run agent: #{@agent_name}: #{e}")
        logger.error(e)
      end
    end

    # Exceptional shutdown of the agent.
    def terminate
      logger.debug("Sending dead message for #{agent.name}")
      if Smith.running?
        send_dead_message
      else
        Smith.start do
          send_dead_message
        end
      end
      Smith.stop
      unlink_pid_file
    end

    # Clean shutdown of the agent.
    def shutdown
      logger.debug("Agent stopped: #{agent.name}")
      unlink_pid_file
      Smith.stop if Smith.running?
    end

    private

    def write_pid_file
      @pid = Daemons::PidFile.new(Daemons::Pid.dir(:normal, Dir::tmpdir, nil), ".rubymas-#{@agent_name.snake_case}", true)
      @pid.pid = Process.pid
    end

    def send_dead_message
      Messaging.new(:dead).send_message(:name => agent.name)
    end

    def unlink_pid_file
      @pid.cleanup
    end
  end
end

path = ARGV[0]
agent_name = ARGV[1]

exit 1 if agent_name.nil? || path.nil?

# Set the running instance name to the name of the agent.
$0 = "#{agent_name}"

bootstrapper = Smith::AgentBootstrap.new(path, agent_name)

include Smith::Logger

begin
  Smith.start {
    bootstrapper.load_agent

    %w{TERM INT QUIT}.each do |sig|
      trap sig, proc {
        logger.error("Agent received: #{sig} signal: #{bootstrapper.agent.name}")
        bootstrapper.terminate
      }
    end

    bootstrapper.run
  }

  bootstrapper.shutdown

rescue => e
  logger.error("Agent #{bootstrapper.agent.name} has died.")
  logger.error(e)
  bootstrapper.terminate
end
