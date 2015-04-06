# -*- encoding: utf-8 -*-

require 'daemons/daemonize'
require 'daemons/pidfile'

require 'smith/utils'

module Smith
  class Daemon

    include Logger

    def initialize(name, daemonise, dir=nil)
      @name = name
      @daemonise = daemonise
      @pid = Daemons::PidFile.new(pid_directory(dir), @name)
    end

    # Daemonise the process if the daemonise option is true, otherwise do nothing.
    def daemonise
      unlink_pid_file

      if @daemonise
        fork && exit

        unless Process.setsid
          raise RuntimeException, 'cannot detach from controlling terminal'
        end

        $0 = @name

        # Be nice to unmount.
        Dir.chdir "/"

        STDIN.reopen("/dev/null")
        STDOUT.reopen("/dev/null")
        STDERR.reopen(STDOUT)
      end

      $0 = @name

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
        logger.verbose { "Removing pid file: #{p.to_s}" }
        p.unlink
      end
    end

    private

    # Get the pid directory. This checks for the command line option,
    # then the config and finally use the tmp directory.
    def pid_directory(dir)
      dir || Utils.check_and_create_directory(Smith.config.agency.pid_directory)
    end
  end
end
