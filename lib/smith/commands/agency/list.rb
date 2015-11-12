# -*- encoding: utf-8 -*-

require_relative '../common'

module Smith
  module Commands
    class List < CommandBase

      include Common

      def execute
        case
        when target.size > 0
          selected_agents = agents.find_by_name(target)
        when options[:group] && options[:all]
          selected_agents = agent_group(options[:group]).map do |agent_name|
            a = agents.find_by_name(agent_name)
            (a.empty?) ? AgentProcess.new(nil, :name => agent_name, :uuid => nil_uuid) : a.first
          end
        when options[:group]
          begin
            selected_agents = agents.find_by_name(agent_group(options[:group]))
          rescue RuntimeError => e
            responder.fail(e.message)
            return
          end
        else
          selected_agents = (options[:all]) ? agents.to_a : agents.state(:running)
        end

        responder.succeed((selected_agents.empty?) ? '' : format(selected_agents, options[:long]))
      end

      private

      def format(a, long)
        a = (target.empty?) ? a : a.select {|z| target.detect {|y| z.name == y } }.flatten
        if options[:long_given]
          tabulate(long_format(a), :header => "total #{a.count}")
        elsif options[:name_only]
          name_only(a, "\n")
        else
          short_format(a)
        end
      end

      def long_format(a)
        a.sort { |a, b| a.name <=> b.name }.map do |a|
          [a.state, a.uuid, a.pid, (a.started_at) ? format_time(a.started_at) : '', (!(a.stopped? || a.null?) && !a.alive?) ? '(agent dead)' : "", a.name]
        end
      end

      def short_format(a, sep=' ')
        a.map { |a| [a.uuid] }.join(sep)
      end


      def name_only(a, sep=' ')
        a.map { |a| [a.name] }.join(sep)
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

      # Produces a null version 4 UUID.
      def nil_uuid
        '00000000-0000-4000-0000-000000000000'
      end

      def options_spec
        banner "List the running agents.", "<agent name[s]>"

        opt         :long,       "shows full details of running agents", :short => :l
        opt         :group,      "list only agents in this group", :type => :string, :short => :g
        opt         :name_only,  "list on the agents' name", :short => :n
        opt         :all,        "list all agents in all states", :short => :a

        conflicts   :name_only, :long
      end
    end
  end
end
