module Smith
  module Utils

    # Searches the agent load path for agents. If there are multiple agents
    # with the same name in different directories the first wins.
    #
    # @param name [String] the name of the agent.
    # @return [Pathname] the path of the agent.
    def agent_directories(name)
      Smith.agent_directories.each do |path|
        p = path_from_class(path, name)
        return p if p.exist?
      end
      return nil
    end

    # Constructs a path from a root and a fully qualified class.
    #
    # @param root [Pathname] the root path.
    # @param clazz [String] the fully qualified class.
    # @@return [Pathname] the path
    def path_from_class(root, clazz)
      parts = clazz.split(/::/).map(&:snake_case)
      parts[-1] = "#{parts[-1]}.rb"
      Pathname.new(root).join(*parts)
    end

    def class_name_from_path(root, path)
      relative_path = path.relative_path_from(root)
      parts = relative_path.split
      parts.map { |p| p.to_s.camel_case }.join('::')
    end

    # Performs a Kernel.const_get on each element of the class.
    #
    # @param name [String]
    # @return [Class] the agent class
    def class_from_name(name)
      name.to_s.split(/::/).inject(Kernel) { |acc, t| acc.const_get(t) }
    end
  end
end
