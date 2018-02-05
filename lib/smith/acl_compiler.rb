# -*- encoding: utf-8 -*-
require "tempfile"
require 'ruby_parser'

require 'smith/messaging/acl_type_cache'

module Smith
  class ACLCompiler

    include Logger

    def initialize
      @acl_type_cache = AclTypeCache.instance
      @acl_parser = ACLParser.new
    end

    def compile
      $LOAD_PATH << Smith.acl_cache_directory

      Smith.acl_directories.each do |path|
        $LOAD_PATH << path

        acl_files = path_glob(path)
        out_of_date_acls = path_glob(path).select { |p| should_compile?(p) }
        if out_of_date_acls.size > 0
          compile_on_path(path, acl_files, out_of_date_acls)
        end

        acl_files.each do |acl_file|
          acl_class_path = acl_compiled_path(acl_file)
          load_acl(acl_class_path)
          add_to_type_cache(acl_class_path)
        end
      end
    end

    private

    def compile_on_path(path, acls, out_of_date_acls)
      out_of_date_acls.each { |acl| logger.debug("Compiling acl: #{path.join(acl)}") }

      unless acls.empty?
        Dir.chdir(path) do
          cmd = %Q{sh -c 'protoc --ruby_out=#{Smith.acl_cache_directory} -I #{path} #{out_of_date_acls.map(&:to_s).join(' ')} 2>&1'}
          protoc = IO.popen(cmd)
          output = protoc.read
          protoc.close

          if $?.exitstatus != 0
            error = parse_protoc_error(output)
            logger.fatal { "Cannot compile ACLs: #{error[:file]}" }
            raise RuntimeError, output
          end
        end
      end
    end

    def parse_protoc_error(s)
      e = s.split(/:/)
      {:file => e[0], :line => e[1], :pos => e[2], :error => e[3,-1]}
    end

    # Returns true if the .proto file is newer that the .pb.rb file
    def should_compile?(file)
      cached_file = Smith.acl_cache_directory.join(file.basename).sub_ext(".pb.rb")
      if cached_file.exist?
        file.mtime.to_i > cached_file.mtime.to_i
      else
        true
      end
    end

    def path_glob(path)
      Pathname.glob(path.join("*.proto")).map { |acl| acl.realpath }
    end

    # This is not idea but I really don't know how else to do it. I cannot use
    # $stderr = StringIO.new as this only seems to capture STDERR if you
    # explicitly write to STDERR. In my case it's an ffi library call that's
    # writing to STDERR.
    def capture_stderr
      org_stderr = STDERR.dup
      begin
        tmp = Tempfile.new('')
        tmp.sync = true
        STDERR.reopen(tmp)
        yield
        File.read(tmp.path)
      ensure
        STDERR.reopen(org_stderr)
      end
    end

    def load_acl(path)
      logger.debug { "Loading ACL: #{path}" }
      require path
    end

    def add_to_type_cache(path)
      acl_class = File.read(path)
      @acl_parser.go(acl_class)
      @acl_parser.fully_qualified_classes.each do |clazz|
        @acl_type_cache.add(to_class(clazz))
      end
    end

    def to_class(type_as_array)
      type_as_array.inject(Kernel) { |acc, t| acc.const_get(t) }
    end

    def acl_compiled_path(path)
      "#{Smith.acl_cache_directory.join(path.basename('.proto'))}.pb.rb"
    end
  end
end
