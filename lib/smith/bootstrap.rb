# This should never be run directly it should only be
# ever run by the agency.

$: << File.dirname(__FILE__) + '/..'

require 'extlib'
require 'smith'

class AgentBootstrap

  def initialize(path, agent_name, logger)
    @logger = logger

    @agent_name = agent_name
    @agent_filename = File.expand_path(File.join(path, "#{agent_name.snake_case}.rb"))
  end

  def load_agent
    load @agent_filename
  end

  def run
    begin
      agent_instance = Kernel.const_get(@agent_name).new(:logger => @logger)
      agent_instance.run
    rescue => e
      @logger.error("Failed to run agent: #{@agent_name}: #{e}")
      @logger.error(e)
    end
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

path = ARGV[0]
agent_name = ARGV[1]
logging_config = ARGV[2]

exit 1 if agent_name.nil? || path.nil?

# Create a stdout logger if a logger is not supplied
if logging_config.nil? || logging_config.empty?
  logger = Logging.logger(STDOUT)
else
  Logging.configure(logging_config)
  logger = Logging::Logger['audit']
end

# Set the running instance name to the name of the agent.
$0 = "#{agent_name}"

agent = AgentBootstrap.new(path, agent_name, logger)

if agent.write_pid_file
  agent.load_agent

  # Make sure the pid file is removed
  at_exit { agent.unlink_pid_file }

  Smith.start {
    agent.run
  }
else
  logger.error("Another instance of #{agent_name} is already running")
end
