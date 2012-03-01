# -*- encoding: utf-8 -*-

require_relative 'common'

module Smith
  module Commands
    class Start < Command

      include Common

      def execute
        # Sort out any groups. If the group option is set it will override
        # any other specified agents.
        if options[:group]
          begin
            # I don't understand why I need to put self here. target= is a method
            # on Command so I would have thought that would be used but a local
            # variable is used instead of the method. TODO work out why and fix.
            self.target = agent_group(options[:group])
            if target.empty?
              responder.value("There are no agents in group: #{options[:group]}")
              return
            end
          rescue RuntimeError => e
            responder.value(e.message)
            return
          end
        end

        responder.value do
          if target.empty?
            "Start what? No agent specified."
          else
            target.map do |agent|
              agents[agent].name = agent
              if agents[agent].path
                if options[:kill]
                  agents[agent].kill
                end
                agents[agent].start
                nil
              else
                "Unknown agent: #{agents[agent].name}".tap do |m|
                  logger.error { m }
                end
              end
            end.compact.join("\n")
          end
        end
      end

      def options_parser
        command = self.class.to_s.split(/::/).last.downcase
        Trollop::Parser.new do
          banner  Command.banner(command)
          opt     :kill,     "Reset the state of the agent before starting", :short => :k
          opt     :group,     "Start everything in the specified group", :type => :string, :short => :g
        end
      end
    end
  end
end
