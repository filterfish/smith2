# -*- encoding: utf-8 -*-

require 'curses'

module Smith
  module Commands
    class Top < CommandBase
      def execute
        Curses.init_screen()
        win = Curses::Window.new(Curses.lines, Curses.cols, 0, 0)

        Messaging::Receiver.new('agent.stats', :durable => false, :auto_delete => false).ready do |receiver|
          receiver.subscribe do |r|
            payload = r.payload
            win.setpos(0,0)
            win.addstr("%s %12s %5s %5s" % ["Queue", "Pid", "RSS", "Time"])
            win.setpos(2,0)
            win.addstr(format(payload))
            win.refresh
          end
        end
      end

      def format(payload)
        s = ""
        s << "%s %.12s %5s %5s\n\n" % [payload.agent_name, payload.pid, payload.rss, payload.up_time]
        s << payload.queues.map do |queue|
          "    %-26s  %d" % [queue.name, queue.length]
        end.join("\n")
      end

      private

      def format_queues(queue_stats)
        queue_stats.inject([]) do |a,queue_stat|
          a.tap do |acc|
            acc << "#{queue_stat.name}:[#{queue_stat.length}]"
          end
        end.join(";")
      end

      def options_spec
        banner "Show information about running agents."
      end
    end
  end
end
