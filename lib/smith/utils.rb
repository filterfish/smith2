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
    module_function :path_from_class

    # Returns a Constant based on the pathname.
    def class_name_from_path(path, root=Pathname.new('.'), segment_to_remove=nil)
      relative_path = path.relative_path_from(root)
      parts = split_path(relative_path.sub_ext('')).reject { |p| p == segment_to_remove }

      parts.map { |p| p.to_s.camel_case }.join('::')
    end
    module_function :class_name_from_path

    # Performs a Kernel.const_get on each element of the class.
    #
    # @param name [String]
    # @return [Class] the agent class
    def class_from_name(name)
      name.to_s.split(/::/).inject(Kernel) { |acc, t| acc.const_get(t) }
    end
    module_function :class_from_name


    # Slipts a path into it's component parts.
    #
    # @param pathname [Pathname] the path to split.
    def split_path(pathname)
      pathname.each_filename.inject([]) { |acc, p| acc << p }
    end
    module_function :split_path

    # Check for the existance of a directory and create if it doesn't exist.
    # @param dir [Pathname]
    def check_and_create_directory(dir)
      dir.tap do
        dir.exist? || dir.mkpath
      end
    end
    module_function :check_and_create_directory
  end
end
