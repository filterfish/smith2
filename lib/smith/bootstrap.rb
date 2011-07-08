# This should never be run directly it should only be
# ever run by the agency.

$: << File.dirname(__FILE__) + '/..'

require 'extlib'
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
      begin
        @agent = Kernel.const_get(@agent_name).new
        @agent.run
      rescue => e
        logger.error("Failed to run agent: #{@agent_name}: #{e}")
        logger.error(e)
      end
    end

    def log
      logger
    end

    # Exceptional shutdown of the agent.
    def terminate
      logger.debug("Sending dead message for #{agent.name}")
      if Smith.running?
        Messaging.new(:dead).send_message(:name => agent.name)
        Smith.stop
      else
        Smith.start do
          Messaging.new(:dead).send_message(:name => agent.name)
          Smith.stop
        end
      end
      unlink_pid_file
    end

    # Clean shutdown of the agent.
    def shutdown
      logger.debug("Agent stopped: #{agent.name}")
      unlink_pid_file
      Smith.stop if Smith.running?
    end

    def write_pid_file
      @pid = Daemons::PidFile.new(Daemons::Pid.dir(:normal, Dir::tmpdir, nil), ".rubymas-#{@agent_name.snake_case}")
      if @pid.exist?
        if @pid.running?
          false
        else
          @pid.pid = Process.pid
        end
      else
        @pid.pid = Process.pid
      end
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
    if bootstrapper.write_pid_file
      bootstrapper.load_agent

      %w{TERM INT QUIT}.each do |sig|
        trap sig, proc {
          logger.error("Agent received: #{sig} signal: #{bootstrapper.agent.name}")
          bootstrapper.terminate
        }
      end

      bootstrapper.run
    else
      logger.error("Another instance of #{agent_name} is already running")
    end
  }

  bootstrapper.shutdown

rescue => e
  logger.error("Agent #{bootstrapper.agent.name} has died.")
  logger.error(e)
  bootstrapper.terminate
end
