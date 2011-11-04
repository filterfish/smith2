module Smith
  module Commands
    module Common
      def agent_group(group)
        Smith.agent_paths.map do |path|
          group_dir = path.join(group)
          if group_dir.exist? && group_dir.directory?
            agents = Pathname.glob("#{path.join(group)}/*_agent.rb")
            return agents.map {|a| Extlib::Inflection.camelize(a.basename(".rb").to_s)}
          else
            raise RuntimeError, "Group does not exist: #{group}"
          end
        end
      end
    end
  end
end
