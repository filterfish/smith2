# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class List < CommandBase
      def execute
        if target.size > 0
          selected_agents = agents.find_by_name(target)
        else
          selected_agents = (options[:all]) ? agents.to_a : agents.state(:running)
        end

        responder.succeed((selected_agents.empty?) ? '' : format(selected_agents, options[:long]))
      end

      private

      def format(a, long)
        if long
          tabulate(long_format(a), :header => "total #{a.count}")
        else
          tabulate(short_format(a))
        end
      end

      def long_format(a)
        a.map do |a|
          [a.state, a.uuid, a.pid, (a.started_at) ? format_time(a.started_at) : '', (!(a.stopped? || a.null?) && !a.alive?) ? '(agent dead)' : "", a.name]
        end
      end

      def short_format(a)
        a.map do |a|
          [a.name, a.uuid]
        end
      end

      def format_time(t)
        (t) ? t.strftime("%Y/%m/%d %H:%M:%S") : ''
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
