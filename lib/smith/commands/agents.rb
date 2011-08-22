#encoding: utf-8

module Smith
  module Commands
    class Agents < Command
      def execute(target)
        agent_paths = Smith.agent_default_path.each_child.inject([]) do |acc,p|
          acc.tap do |a|
            a << Extlib::Inflection.camelize(p.basename('.rb')) unless p.directory?
          end
        end

        if agent_paths.empty?
          "No agents available."
        else
          "Agents available: #{agent_paths.sort.join(", ")}."
        end
      end
    end
  end
end
