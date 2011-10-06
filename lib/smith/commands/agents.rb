# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Agents < Command
      def execute
        agent_paths = Smith.agent_paths.inject([]) do |path_acc,path|
          path_acc.tap do |a|
            a << path.each_child.inject([]) do |agent_acc,p|
                   agent_acc.tap do |b|
                     b << Extlib::Inflection.camelize(p.basename('.rb')) if p.file? && p.basename('.rb').to_s.end_with?("agent")
                  end
                end
          end.flatten
        end

        responder.value((agent_paths.empty?) ? "No agents available." : "Agents available: #{agent_paths.sort.join(", ")}.")
      end
    end
  end
end
