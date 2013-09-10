# -*- encoding: utf-8 -*-
module Smith
  module Commands
    module Common
      def agent_group(group)
        agents = Smith.agent_paths.map do |path|
          group_dir = path.join(group)
          if group_dir.exist? && group_dir.directory?
            agents = Pathname.glob(group_dir.join("*_agent.rb"))
            agents.map {|a| Extlib::Inflection.camelize(a.basename(".rb").to_s)}
          else
            nil
          end
        end.uniq

        raise RuntimeError, "Group does not exist: #{group}" if agents == [nil]
        agents.compact.flatten
      end
    end
  end
end
