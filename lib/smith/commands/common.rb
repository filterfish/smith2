# -*- encoding: utf-8 -*-
module Smith
  module Commands
    module Common

      # Returns the fully qualified class of all agents in a group. The group
      # //must// be a sub-directory in the agents directory. Only sym-links are
      # considered. The group directory is recursively searched and addeed to
      # the ilst of agents for that group if it passed all checks.
      #
      # @param group [String] the group name
      #
      # @return [Array<Class>] the class of each agent in the group
      def agent_group(group)
        agents = Smith.agent_directories.map do |agent_directory|
          group_directory = agent_directory.join(group)

          if group_directory.exist? && group_directory.directory?
            agents = Pathname.glob(group_directory.join("*.rb")).map(&:expand_path)

            agents.inject([]) do |acc, agent|
              if agent.symlink?
                expanded_agent_path = resolve_agent_path(group_directory, agent)
                acc << Utils.class_name_from_path(expanded_agent_path, agent_directory)
              end
            end
          else
            nil
          end
        end.uniq

        raise RuntimeError, "Group does not exist: #{group}" if agents == [nil]
        agents.compact.flatten
      end

      private

      def resolve_agent_path(group_directory, agent)
        agent.readlink.expand_path(group_directory)
      end
    end
  end
end
