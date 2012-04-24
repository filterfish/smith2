# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class List < CommandBase
      def execute
        responder.value do
          if options[:all]
            if agents.empty?
              "No agents running."
            else
              if options[:long]
                tabulate(long_format(agents), :header => "total #{agents.count}")
              else
                short_format(agents)
              end
            end
          else
            running_agents = agents.state(:running)
            if running_agents.empty?
              "No agents running."
            else
              if options[:long]
                tabulate(long_format(running_agents), :header => "total #{running_agents.count}")
              else
                short_format(running_agents)
              end
            end
          end
        end
      end

      private

      def long_format(agents)
        agents.map do |a|
          [a.state, a.pid, (a.started_at) ? format_time(a.started_at) : '', (!(a.stopped? || a.null?) && !a.alive?) ? '(agent dead)' : "", a.name]
        end
      end

      def short_format(agents)
        agents.map(&:name).sort.join(" ")
      end

      def format_time(t)
        (t) ? Time.at(t).strftime("%Y/%m/%d %H:%M:%S") : ''
      end

      def tabulate(a, opts={})
        col_widths = a.transpose.map{|col| col.map{|cell| cell.to_s.length}.max}
        header = (opts[:header]) ? "#{opts[:header]}\n" : ''
        a.inject(header) do |acc,e|
          acc << sprintf("#{col_widths.inject("") { |spec,w| spec << "%-#{w + 2}s"}}\n", *e)
        end
      end

      def options_spec
        banner "List the running agents."

        opt    :long, "the number of times to send the message", :short => :l
        opt    :all,  "show all agents in all states", :short => :a
      end
    end
  end
end
