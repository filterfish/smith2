# -*- encoding: utf-8 -*-
module Smith
  module Commands
    module Common

      # Returns the fully qualified class of all agents in a group. The group
      # //must// be a sub-directory in the agents directory. Only sym-links are
      # considered. The group directory is recursively searched and added to
      # the ilst of agents for that group if it passed all checks.
      #
      # @param group [String] the group name
      #
      # @return [Array<Class>] the class of each agent in the group
      def agent_group(group)
        agents = Smith.agent_directories.map do |agent_directory|
          group_directory(agent_directory, group) do |group_directory, groups_prefix|

            if group_directory.exist? && group_directory.directory?
              agents = Pathname.glob(group_directory.join("*.rb")).map(&:expand_path)

              agents.inject([]) do |acc, agent|
                if agent.symlink?
                  expanded_agent_path = resolve_agent_path(group_directory, agent)
                  acc << Utils.class_name_from_path(expanded_agent_path, agent_directory, groups_prefix)
                end
              end
            else
              nil
            end
          end
        end.uniq

        raise RuntimeError, "Group does not exist: #{group}" if agents == [nil]
        agents.compact.flatten
      end

      private

      def resolve_agent_path(group_directory, agent)
        agent.readlink.expand_path(group_directory)
      end

      # Return the group directory. This checks to see if the directory "groups"
      # exists and if it does it appends the group name to that otherwise it appends
      # it to the agent directory.
      #
      # @param path [Pathname] the agent directory
      # @param group [String] the group name
      #
      # @return [Pathname] the group directory
      def group_directory(path, group, &blk)
        dir = path.join(Smith.config.agency.group_directory)
        if dir.exist?
          blk.call(dir.join(group), Smith.config.agency.group_directory)
        else
          blk.call(path.join(group), nil)
        end
      end
    end
  end
end
