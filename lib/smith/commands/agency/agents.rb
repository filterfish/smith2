# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Agents < CommandBase
      def execute
        responder.succeed(_agents)
      end

      # Return the fully qualified class of all avaiable agents
      def _agents
        separator = (options[:one_column]) ? "\n" : " "

        Smith.agent_directories.inject([]) do |acc, agent_root_path|
          Pathname.glob(agent_root_path.join("**/*")).each do |agent_path|
            if !agent_path.symlink? && !agent_path.directory?
              acc << Utils.class_name_from_path(agent_path, agent_root_path)
            end
          end
        end.sort.join(separator)
      end

      private

      def options_spec
        banner "List all available agents."

        opt    :one_column, "the number of times to send the message", :short => :s
      end
    end
  end
end
