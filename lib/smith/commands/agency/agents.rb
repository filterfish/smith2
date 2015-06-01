# -*- encoding: utf-8 -*-
require_relative '../common'

module Smith
  module Commands
    class Agents < CommandBase
      include Common

      def execute
        responder.succeed(_agents)
      end

      # Return the fully qualified class of all avaiable agents
      def _agents
        separator = (options[:one_column]) ? "\n" : " "

        if options[:group]
          agent_group(options[:group]).sort.join(separator)
        else
          Smith.agent_directories.each_with_object([]) do |agent_root_path, acc|
            Pathname.glob(agent_root_path.join("**/*")).each do |agent_path|
              if !agent_path.symlink? && !agent_path.directory?
                acc << Utils.class_name_from_path(agent_path, agent_root_path)
              end
            end
          end.sort.join(separator)
        end
      end

      private

      def options_spec
        banner "List all available agents."

        opt    :one_column, "List one agent per line", :short => :s
        opt    :group,      "list only agents in this group", :type => :string, :short => :g
      end
    end
  end
end
