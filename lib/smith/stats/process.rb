require 'sys/proctable'

module Smith
  module Stats
    # Get some basic process statistics. Not all of these will be filled in for
    # all platforms but the majority should be there.
    #
    class Process

      Stats = Struct.new(:host, :name, :exe, :ppid, :pid, :state, :vsize, :rss, :uid, :user, :gid, :group, :threads, :uptime) do |p|
        def to_acl
          Smith::ACL::ProcessStats.new do |a|
            a[:uptime] = self.uptime.round.to_i
            [:name, :exe, :ppid, :pid, :state, :vsize, :rss, :uid, :user, :gid, :group, :threads].each do |field|
              a[field] = send(field)
            end
          end
        end
      end

      # Create a new Process object. The uptime of each process doesn't seem to be
      # very reliable (certainly on Debian Sid) so you can pass the process start
      # time in which is used to calculate the uptime.
      #
      # @param [Fixnum, String] pid The pid of the process to get the stats for.
      #
      # @param [Fixnum] start_time The time the process was started.
      def initialize(pid=$$, start_time=Time.now)
        @pid = pid.to_i
        @start_time = start_time
        @pagesize = Etc.sysconf(Etc::SC_PAGESIZE)
      end

      # Return various process statistics for the given pid
      #
      # @retrun [Struct::Stats]
      #
      def stats
        Stats.new.tap do |s|
          stats = Sys::ProcTable.ps(@pid)

          s.host = Smith.hostname
          s.name = stats.cmdline
          s.exe = stats.exe
          s.pid = stats.pid
          s.ppid = stats.ppid
          s.state = stats.state
          s.vsize = stats.vsize * @pagesize
          s.rss = stats.rss * @pagesize
          s.uid = stats.uid
          s.user = Etc.getpwuid(stats.uid).name
          s.gid = stats.gid
          s.group = Etc.getgrgid(stats.gid).name
          s.threads = stats.nlwp
          s.uptime = Time.now - @start_time
        end
      end

      # Return the environment for the give process
      #
      # @return [Hash<String, String>]
      #
      def environment
        Sys::ProcTable.ps(@pid).environ
      end
    end
  end
end
