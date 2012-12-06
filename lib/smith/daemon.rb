# -*- encoding: utf-8 -*-

require 'daemons/daemonize'
require 'daemons/pidfile'

module Smith
  class Daemon

    include Logger

    def initialize(name, daemonise, dir=nil)
      @name = name
      @daemonise = daemonise
      @pid = Daemons::PidFile.new(pid_dir(dir), @name)
    end

    # Daemonise the process if the daemonise option is true, otherwise do nothing.
    def daemonise
      unlink_pid_file

      if @daemonise
        Daemonize::daemonize('/dev/null', @name)
      else
        $0 = @name
      end

      @pid.pid = Process.pid
      logger.debug { "Pid file: #{@pid.filename}" }
    end

    # Check to see if the program is running. This checks for the existance
    # of a pid file and if there is checks to see if the pid exists.
    def running?
      pid_files = Daemons::PidFile.find_files(@pid.dir, @name)

      if pid_files.empty?
        false
      else
        pid = File.read(pid_files.first).to_i
        pid > 0 && Daemons::Pid.running?(pid)
      end
    end

    def unlink_pid_file
      p = Pathname.new(@pid.filename)
      if p.exist?
        logger.verbose { "Removing pid file." }
        p.unlink
      end
    end

    private

    # Get the pid directory. This checks for the command line option,
    # then the config and finally use the tmp directory.
    def pid_dir(dir)
      if dir
        dir
      else
        if Smith.config.agency.to_hash.has_key?(:pid_dir)
          Smith.config.agency.pid_dir
        else
          Dir.tmpdir
        end
      end
    end
  end
end
