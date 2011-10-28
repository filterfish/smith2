# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Agents < Command
      def execute
        responder.value do
          # FIXME make sure that if the path doesn't exist don't blow up.
          agent_paths = Smith.agent_paths.inject([]) do |path_acc,path|
            path_acc.tap do |a|
              if path.exist?
                a << path.each_child.inject([]) do |agent_acc,p|
                  agent_acc.tap do |b|
                    b << Extlib::Inflection.camelize(p.basename('.rb')) if p.file? && p.basename('.rb').to_s.end_with?("agent")
                  end
                end
              else
                error_message = "Agent path doesn't exist: #{path}"
                responder.value(error_message)
              end.flatten
            end
          end
          (agent_paths.empty?) ? "No agents available." : "Agents available: #{agent_paths.sort.join(", ")}."
        end
      end
    end
  end
end
