# This should never be run directly it should only be
# ever run by the agency.

$: << File.dirname(__FILE__) + '/..'

require 'extlib'
require 'smith'

module Smith
  class AgentBootstrap

    def initialize(path, agent_name)
      @agent_name = agent_name
      @agent_filename = File.expand_path(File.join(path, "#{agent_name.snake_case}.rb"))
    end

    def load_agent
      load @agent_filename
    end

    def run
      begin
        agent_instance = Kernel.const_get(@agent_name).new
        agent_instance.run
      rescue => e
        Logger.error("Failed to run agent: #{@agent_name}: #{e}")
        Logger.error(e)
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

  exit 1 if agent_name.nil? || path.nil?

  # Set the running instance name to the name of the agent.
  $0 = "#{agent_name}"

  agent = AgentBootstrap.new(path, agent_name)

  if agent.write_pid_file
    agent.load_agent

    %w{TERM INT QUIT}.each do |sig|
      trap sig, proc {
        Logger.debug("Running signal handler for #{agent_name}")
        Smith.stop
        agent.unlink_pid_file
      }
    end

    Smith.start {
      agent.run
    }
  else
    Logger.error("Another instance of #{agent_name} is already running")
  end
end
