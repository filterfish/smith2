# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Agents < CommandBase
      def execute
        responder.succeed(_agents)
      end

      def _agents
        # FIXME make sure that if the path doesn't exist don't blow up.
        Smith.agent_paths.inject([]) do |path_acc,path|
          path_acc.tap do |a|
            if path.exist?
              a << path.each_child.inject([]) do |agent_acc,p|
                agent_acc.tap do |b|
                  b << Extlib::Inflection.camelize(p.basename('.rb')) if p.file? && p.basename('.rb').to_s.end_with?("agent")
                end
              end.flatten
            else
              return "Agent path doesn't exist: #{path}"
            end
          end
        end.flatten.sort.join(" ")
      end

      private

      def options_spec
        banner "List all available agents."
      end
    end
  end
end
