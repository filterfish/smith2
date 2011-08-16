#encoding: utf-8

module Smith
  module AgencyCommands
    class Agents < AgencyCommand
      def execute(target)
        agent_paths = Smith.agent_default_path.each_child.inject([]) do |acc,p|
          acc.tap do |a|
            a << Extlib::Inflection.camelize(p.basename('.rb')) unless p.directory?
          end
        end

        if agent_paths.empty?
          logger.info("No agents available.")
        else
          logger.info("Agents available: #{agent_paths.sort.join(", ")}.")
        end
      end
    end
  end
end
